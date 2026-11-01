import 'package:flutter/foundation.dart';

import '../data/update_service.dart';
import '../model/update_info.dart';

enum UpdateStatus {
  /// 还没查 / 没有新版本。
  idle,

  /// 正在请求 GitHub。
  checking,

  /// 有新版本可下。
  available,

  downloading,

  /// 下载解压完毕，等重启。
  ready,

  failed,
}

/// 更新流程的状态机。
class UpdateController extends ChangeNotifier {
  UpdateController({UpdateService? service, bool? enabled})
      : _service = service ?? UpdateService(),
        // 开发构建（没有 --dart-define）默认不检查，免得一直提示；
        // 测试里显式传 enabled: true 才能覆盖这条分支。
        _enabled = enabled ?? AppVersion.isReleaseBuild;

  final UpdateService _service;
  final bool _enabled;

  UpdateStatus _status = UpdateStatus.idle;
  UpdateInfo? _info;
  double _progress = 0;
  String? _error;
  bool _dismissed = false;

  UpdateStatus get status => _status;
  UpdateInfo? get info => _info;
  double get progress => _progress;
  String? get error => _error;

  /// 用户手动关掉了提示，这次运行不再显示。
  bool get dismissed => _dismissed;

  /// 状态栏是否要显示更新入口。
  bool get hasUpdate =>
      !_dismissed && _info != null && _status != UpdateStatus.idle && _status != UpdateStatus.failed;

  String get currentVersion => AppVersion.current;

  void dismissBanner() {
    _dismissed = true;
    notifyListeners();
  }

  /// 启动后静默查一次。失败不打扰用户 —— 没网、被墙都很常见。
  Future<void> checkSilently() async {
    if (_status == UpdateStatus.checking || _status == UpdateStatus.downloading) return;
    if (!_enabled) return;

    _status = UpdateStatus.checking;
    notifyListeners();
    try {
      final found = await _service.check();
      if (found == null) {
        _status = UpdateStatus.idle;
      } else {
        _info = found;
        _status = UpdateStatus.available;
      }
    } catch (_) {
      // 静默失败，界面上什么都不显示。
      _status = UpdateStatus.idle;
    }
    notifyListeners();
  }

  /// 用户手动点「检查更新」时调用，失败要给出反馈。
  Future<void> checkManually() async {
    _dismissed = false;
    if (!_enabled) {
      _error = '开发构建不检查更新';
      _status = UpdateStatus.failed;
      notifyListeners();
      return;
    }

    _status = UpdateStatus.checking;
    _error = null;
    notifyListeners();
    try {
      final found = await _service.check();
      if (found == null) {
        _info = null;
        _status = UpdateStatus.idle;
        _error = '已是最新版本';
      } else {
        _info = found;
        _status = UpdateStatus.available;
      }
    } catch (e) {
      _error = e is UpdateException ? e.message : '$e';
      _status = UpdateStatus.failed;
    }
    notifyListeners();
  }

  /// 下载并落盘。完成后进入 ready，等用户点重启。
  Future<void> startDownload() async {
    final target = _info;
    if (target == null) return;
    if (_status == UpdateStatus.downloading) return;

    _status = UpdateStatus.downloading;
    _progress = 0;
    _error = null;
    notifyListeners();

    try {
      final file = await _service.download(
        target,
        onProgress: (received, total) {
          if (total <= 0) return;
          final value = (received / total).clamp(0.0, 1.0);
          // 进度变化太频繁会把 UI 打满，按 1% 节流。
          if ((value - _progress).abs() >= 0.01 || value >= 1) {
            _progress = value;
            notifyListeners();
          }
        },
      );
      await _service.apply(file, target);
      _progress = 1;
      _status = UpdateStatus.ready;
    } catch (e) {
      _error = e is UpdateException ? e.message : '$e';
      _status = UpdateStatus.failed;
    }
    notifyListeners();
  }

  /// 重启到新版本。返回 false 表示拿不到启动器路径（比如开发者直接跑的 exe）。
  Future<bool> restart() => _service.restart();
}
