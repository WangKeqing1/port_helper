import 'dart:io';

import 'package:flutter/services.dart';

/// 测试环境的字体装配。
///
/// flutter_test 的引擎不会自动加载系统字体，中文和 Material 图标默认全是方块。
/// 而且图标字体的路径依赖 Flutter 安装位置，本地和 CI 完全不同，
/// 所以这里从 flutter_tester 自己的位置往上推 SDK 根目录，不写死路径。
class TestFonts {
  TestFonts._();

  /// 是否运行在 CI 上。
  ///
  /// CI 上的字体版本、抗锯齿和本地未必完全一致，golden 逐像素比对容易误报，
  /// 所以金标测试在 CI 环境里跳过，只在本地校验。
  static bool get isCi => Platform.environment['CI'] == 'true';

  /// 从 flutter_tester 的可执行文件位置往上找 SDK 根目录。
  static String? _sdkRoot() {
    var dir = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 10; i++) {
      if (File('${dir.path}/bin/flutter.bat').existsSync() ||
          File('${dir.path}/bin/flutter').existsSync() ||
          File('${dir.path}/bin/flutter.ps1').existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  /// Material 图标字体的绝对路径。
  static String? materialIconsPath() {
    final root = _sdkRoot();
    if (root == null) return null;
    for (final name in const ['materialicons-regular.otf', 'MaterialIcons-Regular.otf']) {
      final path = '$root/bin/cache/artifacts/material_fonts/$name';
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  static Future<bool> _register(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return false;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    return true;
  }

  /// 注册界面用到的全部字体。返回 false 表示有缺失，此时 golden 不可信。
  static Future<bool> registerAll() async {
    var ok = true;

    final icon = materialIconsPath();
    if (icon == null || !await _register('MaterialIcons', icon)) ok = false;

    if (Platform.isWindows) {
      // 界面首选族名是 Noto Sans SC；Windows 上没有这款字体，
      // 所以把微软雅黑注册成同名，让 golden 的字形接近真实运行环境。
      const msyh = r'C:\Windows\Fonts\msyh.ttc';
      const msyhBold = r'C:\Windows\Fonts\msyhbd.ttc';
      const consolas = r'C:\Windows\Fonts\consola.ttf';
      if (!await _register('Noto Sans SC', msyh)) ok = false;
      await _register('Noto Sans SC', msyhBold);
      if (!await _register('Consolas', consolas)) ok = false;
    } else {
      ok = false;
    }

    return ok;
  }
}
