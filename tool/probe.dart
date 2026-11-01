// 真实系统调用探针：不启动界面，直接跑一遍查询 → 详情 → 结束的只读部分。
// 用法：dart run tool/probe.dart [端口]
import 'dart:io';

import 'package:port_helper/src/data/port_scanner.dart';
import 'package:port_helper/src/model/models.dart';

Future<void> main(List<String> args) async {
  final port = int.tryParse(args.isNotEmpty ? args.first : '') ?? 8080;
  final scanner = PortScanner();

  stdout.writeln('— 查询端口 $port —');
  final result = await scanner.query(port, ProtocolFilter.all);
  if (result.error != null) {
    stdout.writeln('查询失败：${result.error}');
    exit(1);
  }
  stdout.writeln('${result.summaryLabel}  (${result.queriedAt})');

  if (result.bindings.isEmpty) {
    stdout.writeln('该端口当前没有监听。');
    return;
  }

  for (final b in result.bindings) {
    stdout.writeln('  ${b.protocol.padRight(4)} ${b.localAddress.padRight(24)} '
        '${b.stateLabel.padRight(6)} PID ${b.pid}');
  }

  for (final pid in result.pids) {
    final d = result.detailFor(pid);
    stdout.writeln('\n— 进程 $pid —');
    if (d == null) {
      stdout.writeln('  没拿到进程详情');
      continue;
    }
    stdout.writeln('  名称      ${d.name}');
    stdout.writeln('  描述      ${d.subtitle}');
    stdout.writeln('  路径      ${d.executablePath ?? '(不可读)'}');
    stdout.writeln('  运行用户  ${d.userName ?? '未知'}');
    stdout.writeln('  启动时间  ${d.formatStartTime()}');
    stdout.writeln('  启动来源  ${d.parentName ?? '?'} (PID ${d.parentPid ?? '?'})');
    stdout.writeln('  双栈      ${result.hasBothStacksFor(pid) ? '是' : '否'}');
  }
}
