/// 查询协议筛选。
enum ProtocolFilter { all, tcp, udp }

extension ProtocolFilterLabel on ProtocolFilter {
  String get label => switch (this) {
        ProtocolFilter.all => '全部',
        ProtocolFilter.tcp => 'TCP',
        ProtocolFilter.udp => 'UDP',
      };
}

/// 一条监听记录：netstat 里的一行。
class PortBinding {
  const PortBinding({
    required this.protocol,
    required this.localAddress,
    required this.port,
    required this.state,
    required this.pid,
  });

  /// TCP / UDP，大写。
  final String protocol;

  /// 原始本地地址，例如 `0.0.0.0:8080`、`[::]:8080`。
  final String localAddress;

  /// 从地址尾部解析出的端口。
  final int port;

  /// LISTENING / 空（UDP 无状态）。
  final String state;

  final int pid;

  bool get isIpv6 => localAddress.startsWith('[');

  /// 状态栏与详情里显示的「监听中」。
  bool get isListening => state.isEmpty || state.toUpperCase() == 'LISTENING';

  String get stateLabel => isListening ? '监听中' : _humanState(state);

  static String _humanState(String raw) => switch (raw.toUpperCase()) {
        'ESTABLISHED' => '已连接',
        'TIME_WAIT' => '等待关闭',
        'CLOSE_WAIT' => '等待关闭',
        'SYN_SENT' => '连接中',
        'SYN_RECEIVED' => '连接中',
        'FIN_WAIT_1' || 'FIN_WAIT_2' => '关闭中',
        'CLOSED' => '已关闭',
        _ => raw,
      };
}

/// 进程详情，来自 Win32_Process。
class ProcessDetail {
  const ProcessDetail({
    required this.pid,
    required this.name,
    this.executablePath,
    this.description,
    this.startTime,
    this.userName,
    this.parentPid,
    this.parentName,
  });

  final int pid;
  final String name;

  /// exe 完整路径。
  final String? executablePath;

  /// exe 的文件描述，例如 `Node.js JavaScript Runtime`。
  final String? description;

  final DateTime? startTime;

  /// 运行用户。拿不到时为 null（界面显示「本地用户」）。
  final String? userName;

  final int? parentPid;
  final String? parentName;

  String get displayName => name;

  /// 详情区副标题：优先文件描述，其次 exe 名。
  String get subtitle => (description?.trim().isNotEmpty ?? false) ? description!.trim() : name;

  /// 启动时间的人性化写法：今天 / 昨天 / 具体日期。
  String formatStartTime() {
    final t = startTime;
    if (t == null) return '未知';
    final local = t.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final hms = '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天 $hms';
    if (diff == 1) return '昨天 $hms';
    return '${local.year}-${_two(local.month)}-${_two(local.day)} $hms';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

/// 一次端口查询的完整结果。
class PortQueryResult {
  const PortQueryResult({
    required this.port,
    required this.bindings,
    required this.processes,
    required this.queriedAt,
    this.error,
  });

  final int port;
  final List<PortBinding> bindings;

  /// pid -> 详情。
  final Map<int, ProcessDetail> processes;
  final DateTime queriedAt;

  /// 查询失败时的提示（例如端口没人监听时为空，不是错误）。
  final String? error;

  /// 去重后的 PID，按首次出现顺序。
  List<int> get pids {
    final seen = <int>{};
    final out = <int>[];
    for (final b in bindings) {
      if (seen.add(b.pid)) out.add(b.pid);
    }
    return out;
  }

  int get listeningCount => bindings.length;
  int get processCount => pids.length;

  String get summaryLabel => '$listeningCount 条监听 · $processCount 个进程';

  ProcessDetail? detailFor(int pid) => processes[pid];

  /// 该 PID 命中的全部协议，去重后按 TCP、UDP 排序。
  List<String> protocolsFor(int pid) {
    final set = <String>{};
    for (final b in bindings) {
      if (b.pid == pid) set.add(b.protocol);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// 该 PID 是否同时占用了 IPv4 与 IPv6。
  bool hasBothStacksFor(int pid) {
    var v4 = false;
    var v6 = false;
    for (final b in bindings) {
      if (b.pid != pid) continue;
      if (b.isIpv6) {
        v6 = true;
      } else {
        v4 = true;
      }
    }
    return v4 && v6;
  }
}
