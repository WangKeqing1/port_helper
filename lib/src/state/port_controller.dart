import 'package:flutter/foundation.dart';

import '../data/port_scanner.dart';
import '../model/models.dart';

/// 状态栏的语义等级，决定图标与配色。
enum StatusKind { idle, busy, success, warning, error }

/// 页面状态机：输入 → 查询 → 选中 → 结束 → 回填。
class PortController extends ChangeNotifier {
  PortController({PortScanner? scanner}) : _scanner = scanner ?? PortScanner();

  final PortScanner _scanner;

  String _portText = '8080';
  ProtocolFilter _filter = ProtocolFilter.all;
  PortQueryResult? _result;
  int? _selectedPid;
  int _selectedIndex = 0;
  bool _busy = false;
  String _statusText = '输入端口号后按 Enter 查询';
  StatusKind _statusKind = StatusKind.idle;

  String get portText => _portText;
  ProtocolFilter get filter => _filter;
  PortQueryResult? get result => _result;
  bool get busy => _busy;
  String get statusText => _statusText;
  StatusKind get statusKind => _statusKind;

  /// 当前展开的 PID。默认展开第一条记录。
  int? get selectedPid => _selectedPid;

  /// 当前展开行的下标。同一个 PID 会有多条监听记录（IPv4 / IPv6 / TCP / UDP），
  /// 只按 PID 判断高亮会让整片行一起变色，所以再记一个行号。
  int get selectedIndex => _selectedIndex;

  ProcessDetail? get selectedProcess {
    final r = _result;
    final pid = _selectedPid;
    if (r == null || pid == null) return null;
    return r.detailFor(pid);
  }

  /// 当前选中 PID 对应的第一条绑定，用于展示地址等信息。
  PortBinding? get selectedBinding {
    final r = _result;
    final pid = _selectedPid;
    if (r == null || pid == null) return null;
    for (final b in r.bindings) {
      if (b.pid == pid) return b;
    }
    return null;
  }

  void setPortText(String value) {
    // 只留数字，端口最多 5 位。
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final clipped = digits.length > 5 ? digits.substring(0, 5) : digits;
    if (clipped == _portText) return;
    _portText = clipped;
    notifyListeners();
  }

  void clearPort() {
    if (_portText.isEmpty) return;
    _portText = '';
    notifyListeners();
  }

  void setFilter(ProtocolFilter value) {
    if (value == _filter) return;
    _filter = value;
    notifyListeners();
    // 已有查询结果时，切协议立即重查，符合工具栏的分段控件直觉。
    if (_result != null) {
      query();
    }
  }

  void selectPid(int pid) {
    if (_selectedPid == pid) return;
    _selectedPid = pid;
    notifyListeners();
  }

  /// 点某一行：同时记录行号与 PID。
  void selectRow(int index, int pid) {
    if (_selectedIndex == index && _selectedPid == pid) return;
    _selectedIndex = index;
    _selectedPid = pid;
    notifyListeners();
  }

  /// 执行查询。
  Future<void> query() async {
    final port = int.tryParse(_portText);
    if (port == null || port < 1 || port > 65535) {
      _statusText = '请输入 1–65535 之间的端口号';
      _statusKind = StatusKind.warning;
      notifyListeners();
      return;
    }

    _busy = true;
    _statusText = '正在查询端口 $port …';
    _statusKind = StatusKind.busy;
    notifyListeners();

    final res = await _scanner.query(port, _filter);

    _result = res;
    _busy = false;

    if (res.error != null) {
      _selectedPid = null;
      _selectedIndex = 0;
      _statusText = '查询失败：${res.error}';
      _statusKind = StatusKind.error;
    } else if (res.bindings.isEmpty) {
      _selectedPid = null;
      _selectedIndex = 0;
      _statusText = '端口 $port 当前没有监听';
      _statusKind = StatusKind.idle;
    } else {
      _selectedPid = res.pids.first;
      _selectedIndex = 0;
      _statusText = '查询完成 · 找到 ${res.processCount} 个进程';
      _statusKind = StatusKind.success;
    }
    notifyListeners();
  }

  /// 刷新：沿用上一次端口，不闪 loading 文案以外的东西。
  Future<void> refresh() async {
    if (_busy) return;
    await query();
  }

  /// 强制结束当前选中的进程，成功后自动重查。
  Future<KillOutcome> killSelected() async {
    final pid = _selectedPid;
    if (pid == null) {
      return const KillOutcome(ok: false, message: '没有选中的进程');
    }
    _busy = true;
    _statusText = '正在结束 PID $pid …';
    _statusKind = StatusKind.busy;
    notifyListeners();

    final outcome = await _scanner.kill(pid);

    if (outcome.ok) {
      _statusText = '已结束 PID $pid · 端口已释放';
      _statusKind = StatusKind.success;
      _busy = false;
      notifyListeners();
      await query();
      // 查询会覆写状态文案，这里补回「已结束」的语义。
      if (_statusKind == StatusKind.success) {
        _statusText = '已结束 PID $pid · 端口已释放';
        notifyListeners();
      }
    } else {
      _busy = false;
      _statusText = outcome.message;
      _statusKind = StatusKind.error;
      notifyListeners();
    }
    return outcome;
  }

  void reportStatus(String text, [StatusKind kind = StatusKind.warning]) {
    _statusText = text;
    _statusKind = kind;
    notifyListeners();
  }
}
