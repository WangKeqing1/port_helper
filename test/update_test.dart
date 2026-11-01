import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:port_helper/src/data/update_service.dart';
import 'package:port_helper/src/model/update_info.dart';
import 'package:port_helper/src/state/update_controller.dart';

/// 版本码换算、更新状态机。
///
/// 真正的网络请求不在这里覆盖（要真连 GitHub），只验证逻辑分支和状态流转。

const _sample = UpdateInfo(
  version: '1.2.0',
  code: 10200,
  downloadUrl: 'https://example.com/port_helper-1.2.0.zip',
  sizeBytes: 11 * 1024 * 1024,
  isZip: true,
  releaseUrl: 'https://example.com/releases/v1.2.0',
  notes: '- 修复若干问题',
);

class _FakeService extends UpdateService {
  _FakeService({this.found, this.failWith});

  final UpdateInfo? found;
  final String? failWith;

  int downloadCalls = 0;
  int applyCalls = 0;

  @override
  Future<UpdateInfo?> check() async {
    if (failWith != null) throw UpdateException(failWith!);
    return found;
  }

  @override
  Future<File> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    downloadCalls++;
    onProgress?.call(50, 100);
    onProgress?.call(100, 100);
    final file = File('${Directory.systemTemp.path}\\fake_update_${info.code}.zip');
    file.writeAsBytesSync(const [1, 2, 3]);
    return file;
  }

  @override
  Future<void> apply(File downloaded, UpdateInfo info) async {
    applyCalls++;
    if (downloaded.existsSync()) downloaded.deleteSync();
  }

  @override
  Future<bool> restart() async => true;
}

class _DownloadFailService extends _FakeService {
  _DownloadFailService() : super(found: _sample);

  @override
  Future<File> download(
    UpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    throw UpdateException('下载超时，请检查网络后重试');
  }
}

void main() {
  group('版本码', () {
    test('三段版本号转整数', () {
      expect(AppVersion.codeOf('1.2.0'), 10200);
      expect(AppVersion.codeOf('1.0.0'), 10000);
      expect(AppVersion.codeOf('0.9.12'), 912);
      expect(AppVersion.codeOf('2.10.3'), 21003);
    });

    test('异常输入不炸', () {
      expect(AppVersion.codeOf('dev'), 0);
      expect(AppVersion.codeOf(''), 0);
      expect(AppVersion.codeOf('1'), 10000);
      expect(AppVersion.codeOf('1.2.3-beta'), 10203);
    });

    test('大小码可比', () {
      expect(AppVersion.codeOf('1.2.1') > AppVersion.codeOf('1.2.0'), isTrue);
      expect(AppVersion.codeOf('1.10.0') > AppVersion.codeOf('1.9.0'), isTrue);
    });
  });

  group('更新状态机', () {
    test('静默检查发现新版本后进入 available', () async {
      final c = UpdateController(service: _FakeService(found: _sample), enabled: true);
      await c.checkSilently();
      expect(c.status, UpdateStatus.available);
      expect(c.info?.version, '1.2.0');
      expect(c.hasUpdate, isTrue);
      c.dispose();
    });

    test('静默检查没新版本就保持 idle，不打扰用户', () async {
      final c = UpdateController(service: _FakeService(found: null), enabled: true);
      await c.checkSilently();
      expect(c.status, UpdateStatus.idle);
      expect(c.hasUpdate, isFalse);
      c.dispose();
    });

    test('静默检查失败不显示错误', () async {
      final c = UpdateController(service: _FakeService(failWith: '网络不可用'), enabled: true);
      await c.checkSilently();
      expect(c.status, UpdateStatus.idle);
      expect(c.error, isNull);
      c.dispose();
    });

    test('关闭更新检查的控制器什么都不做', () async {
      final c = UpdateController(service: _FakeService(found: _sample), enabled: false);
      await c.checkSilently();
      expect(c.status, UpdateStatus.idle);
      c.dispose();
    });

    test('手动检查失败要给出原因', () async {
      final c = UpdateController(service: _FakeService(failWith: '检查更新超时'), enabled: true);
      await c.checkManually();
      expect(c.status, UpdateStatus.failed);
      expect(c.error, contains('超时'));
      c.dispose();
    });

    test('手动检查无新版本时提示已是最新', () async {
      final c = UpdateController(service: _FakeService(found: null), enabled: true);
      await c.checkManually();
      expect(c.status, UpdateStatus.idle);
      expect(c.error, '已是最新版本');
      c.dispose();
    });

    test('下载完成后进入 ready，进度收敛到 1', () async {
      final service = _FakeService(found: _sample);
      final c = UpdateController(service: service, enabled: true);
      await c.checkSilently();
      await c.startDownload();
      expect(service.downloadCalls, 1);
      expect(service.applyCalls, 1);
      expect(c.status, UpdateStatus.ready);
      expect(c.progress, 1);
      c.dispose();
    });

    test('下载失败进入 failed 并带上原因', () async {
      final c = UpdateController(service: _DownloadFailService(), enabled: true);
      await c.checkSilently();
      expect(c.status, UpdateStatus.available);

      await c.startDownload();
      expect(c.status, UpdateStatus.failed);
      expect(c.error, contains('下载超时'));
      c.dispose();
    });

    test('用户关掉提示后状态栏不再显示', () async {
      final c = UpdateController(service: _FakeService(found: _sample), enabled: true);
      await c.checkSilently();
      expect(c.hasUpdate, isTrue);
      c.dismissBanner();
      expect(c.hasUpdate, isFalse);
      c.dispose();
    });
  });
}
