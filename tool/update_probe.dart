// 更新链路探针：不开界面，直接跑「检查 → 下载 → 解压落盘」。
// 用法：dart run --define=APP_VERSION=1.1.0 tool/update_probe.dart
import 'dart:io';

import 'package:port_helper/src/data/update_service.dart';
import 'package:port_helper/src/model/update_info.dart';

Future<void> main() async {
  stdout.writeln('当前版本: ${AppVersion.current}  (码 ${AppVersion.codeOf(AppVersion.current)})');
  stdout.writeln('是否发布构建: ${AppVersion.isReleaseBuild}');
  if (!AppVersion.isReleaseBuild) {
    stdout.writeln('⚠ 没有 --define=APP_VERSION，检查会被跳过');
  }

  final service = UpdateService();
  stdout.writeln('\n— 检查 GitHub 最新 Release —');
  final info = await service.check();
  if (info == null) {
    stdout.writeln('没有新版本');
    return;
  }
  stdout.writeln('发现 ${info.version}  (码 ${info.code})');
  stdout.writeln('包类型: ${info.isZip ? 'zip' : 'exe'}  ${info.sizeLabel}');
  stdout.writeln('地址: ${info.downloadUrl}');

  stdout.writeln('\n— 下载 —');
  final sw = Stopwatch()..start();
  var lastShown = -10;
  final file = await service.download(info, onProgress: (received, total) {
    if (total <= 0) return;
    final pct = (received * 100 ~/ total);
    if (pct >= lastShown + 25) {
      lastShown = pct;
      stdout.writeln('  $pct%');
    }
  });
  sw.stop();
  stdout.writeln('完成 ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s → ${file.path}');

  stdout.writeln('\n— 解压落盘 —');
  await service.apply(file, info);
  final dir = UpdateLayout.versionDir(info.code);
  stdout.writeln('目录: ${dir.path}');
  stdout.writeln('主程序存在: ${File('${dir.path}\\port_helper.exe').existsSync()}');
  stdout.writeln('current.txt: ${UpdateLayout.pointer.readAsStringSync().trim()}');
  final count = dir.listSync(recursive: true).whereType<File>().length;
  stdout.writeln('文件数: $count');
  stdout.writeln('\n启动器下次启动会拉起这个目录。');
}
