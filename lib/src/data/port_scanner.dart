import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../model/models.dart';
import 'win32_process.dart';

/// 结束进程的结果。
class KillOutcome {
  const KillOutcome({required this.ok, required this.message});
  final bool ok;
  final String message;
}

/// 端口查询的统一入口。
///
/// - 查监听：`netstat -ano`（36ms）
/// - 查进程：Win32 API 直调（见 [Win32Process]），不走 WMI
/// - 结束：`taskkill /PID /T /F`
///
/// 早期版本用 PowerShell + `Get-CimInstance` 查进程，实测单次调用 730ms
/// （其中 PowerShell 冷启动 154ms），叠上多次 WMI 往返后一次查询要 1-2 秒。
/// 换成 FFI 后同样的信息在 10ms 内就能拿全。
class PortScanner {
  PortScanner({this.timeout = const Duration(seconds: 20)});

  final Duration timeout;

  /// 查询指定端口在当前协议筛选下的占用情况。
  Future<PortQueryResult> query(int port, ProtocolFilter filter) async {
    final now = DateTime.now();
    try {
      final bindings = await _listBindings(port, filter);
      if (bindings.isEmpty) {
        return PortQueryResult(
          port: port,
          bindings: const [],
          processes: const {},
          queriedAt: now,
        );
      }
      final processes = await _loadProcesses(bindings.map((b) => b.pid).toSet().toList());
      return PortQueryResult(
        port: port,
        bindings: bindings,
        processes: processes,
        queriedAt: now,
      );
    } on _ScanFailure catch (e) {
      return PortQueryResult(
        port: port,
        bindings: const [],
        processes: const {},
        queriedAt: now,
        error: e.message,
      );
    }
  }

  /// 调 netstat 解析出命中端口的监听行。
  Future<List<PortBinding>> _listBindings(int port, ProtocolFilter filter) async {
    final result = await _run(
      'netstat',
      const ['-ano'],
      // netstat 的输出在中文系统上是 GBK；用 latin1 逐字节映射，
      // 表头中文会变乱码，但数据行全是 ASCII，不影响解析，也不会抛异常。
      decoder: latin1.decode,
    );
    return parseNetstat(result, port, filter);
  }

  /// 解析 `netstat -ano` 的文本输出。抽成静态方法便于单元测试。
  static List<PortBinding> parseNetstat(String output, int port, ProtocolFilter filter) {
    final bindings = <PortBinding>[];
    for (final raw in const LineSplitter().convert(output)) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final cols = line.split(RegExp(r'\s+'));
      final proto = cols.first.toUpperCase();
      if (proto != 'TCP' && proto != 'UDP') continue;

      // TCP: 协议 本地地址 外部地址 状态 PID    → 5 段
      // UDP: 协议 本地地址 外部地址 PID         → 4 段
      if (cols.length < 4) continue;

      final local = cols[1];
      final parsedPort = _portOf(local);
      if (parsedPort == null || parsedPort != port) continue;

      final String state;
      final int? pid;
      if (proto == 'TCP') {
        if (cols.length < 5) continue;
        state = cols[3];
        pid = int.tryParse(cols[4]);
        // 只保留真正处于监听的行。ESTABLISHED / TIME_WAIT 是连接而不是占用，
        // 全都列出来会把「2 条监听」撑成十几条，反而看不见是谁占着端口。
        if (state.toUpperCase() != 'LISTENING') continue;
      } else {
        state = '';
        pid = int.tryParse(cols[3]);
      }
      if (pid == null || pid <= 0) continue;

      if (filter == ProtocolFilter.tcp && proto != 'TCP') continue;
      if (filter == ProtocolFilter.udp && proto != 'UDP') continue;

      bindings.add(PortBinding(
        protocol: proto,
        localAddress: local,
        port: parsedPort,
        state: state,
        pid: pid,
      ));
    }

    // TCP 在前、IPv4 在前，和设计稿的顺序一致。
    bindings.sort((a, b) {
      final p = a.protocol.compareTo(b.protocol);
      if (p != 0) return p;
      if (a.isIpv6 != b.isIpv6) return a.isIpv6 ? 1 : -1;
      return a.localAddress.compareTo(b.localAddress);
    });
    return bindings;
  }

  /// 解析 `0.0.0.0:8080` / `[::]:8080` 里的端口。
  static int? _portOf(String address) {
    final idx = address.lastIndexOf(':');
    if (idx < 0 || idx == address.length - 1) return null;
    return int.tryParse(address.substring(idx + 1));
  }

  /// 把用到的进程信息查全：名称、路径、文件描述、启动时间、属主、父进程。
  ///
  /// 一次快照就能拿到全表的「PID → (父 PID, 进程名)」，
  /// 再对目标 PID 逐个补路径和时间，父进程名直接查快照即可。
  Future<Map<int, ProcessDetail>> _loadProcesses(List<int> pids) async {
    if (pids.isEmpty) return const {};

    final snapshot = Win32Process.snapshot();
    final byPid = <int, ProcessDetail>{};
    for (final pid in pids) {
      final entry = snapshot[pid];
      final path = Win32Process.imagePath(pid);
      byPid[pid] = ProcessDetail(
        pid: pid,
        name: entry?.name ?? 'PID $pid',
        executablePath: path,
        description: path == null ? null : Win32Process.fileDescription(path),
        startTime: Win32Process.startTime(pid),
        userName: Win32Process.userName(pid),
        parentPid: entry?.parentPid,
        parentName: entry == null ? null : snapshot[entry.parentPid]?.name,
      );
    }
    return byPid;
  }

  /// 强制结束进程树。
  Future<KillOutcome> kill(int pid) async {
    try {
      final r = await Process.run(
        'taskkill',
        ['/PID', '$pid', '/T', '/F'],
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      ).timeout(timeout);
      if (r.exitCode == 0) {
        return const KillOutcome(ok: true, message: '进程已结束');
      }
      final msg = '${r.stdout}${r.stderr}'.trim();
      return KillOutcome(
        ok: false,
        message: msg.isEmpty ? '结束失败（退出码 ${r.exitCode}）' : _firstLine(msg),
      );
    } on TimeoutException {
      return const KillOutcome(ok: false, message: '结束超时，请重试');
    } catch (e) {
      return KillOutcome(ok: false, message: '结束失败：$e');
    }
  }

  Future<String> _run(
    String executable,
    List<String> args, {
    String Function(List<int>)? decoder,
  }) async {
    try {
      final r = await Process.run(
        executable,
        args,
        stdoutEncoding: null,
        stderrEncoding: null,
      ).timeout(timeout);
      final bytes = (r.stdout as List<int>?) ?? const <int>[];
      final text = decoder?.call(bytes) ?? utf8.decode(bytes, allowMalformed: true);
      if (r.exitCode != 0 && text.trim().isEmpty) {
        final errBytes = (r.stderr as List<int>?) ?? const <int>[];
        final err = utf8.decode(errBytes, allowMalformed: true).trim();
        throw _ScanFailure(err.isEmpty ? '$executable 退出码 ${r.exitCode}' : _firstLine(err));
      }
      return text;
    } on TimeoutException {
      throw _ScanFailure('$executable 响应超时');
    } on ProcessException catch (e) {
      throw _ScanFailure('无法执行 $executable：${e.message}');
    }
  }

  static String _firstLine(String s) {
    final line = s.split(RegExp(r'[\r\n]+')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => s);
    return line.trim();
  }
}

class _ScanFailure implements Exception {
  _ScanFailure(this.message);
  final String message;
}
