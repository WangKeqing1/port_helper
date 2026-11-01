import 'package:flutter/material.dart';

/// 设计令牌 —— 全部取自 Figma 文件 MVMDYZRqpjbNrRZwBaYHqd
/// 三个状态帧（14:1587 查询结果 / 14:1707 结束确认 / 14:1852 界面风格）共用同一套。
abstract final class Tokens {
  // ── 颜色 ────────────────────────────────────────────────
  /// 主色，取自 M3 baseline purple。
  static const primary = Color(0xFF6750A4);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFEADDFF);
  static const onPrimaryContainer = Color(0xFF4F378B);

  /// 窗口底色。
  static const surface = Color(0xFFFDF8FF);
  static const surfaceContainerLowest = Color(0xFFFDF8FF);
  static const surfaceContainerLow = Color(0xFFF7F2FA);
  static const surfaceContainer = Color(0xFFF3EDF7);
  static const surfaceContainerHigh = Color(0xFFECE6F0);

  static const onSurface = Color(0xFF211D29);
  static const onSurfaceVariant = Color(0xFF635C6D);
  static const outline = Color(0xFF81778C);
  static const outlineVariant = Color(0xFFE4DDEB);

  /// 监听中状态色（绿）。
  static const success = Color(0xFF386A49);

  /// 危险操作（红）。
  static const danger = Color(0xFFB3261E);
  static const dangerContainer = Color(0xFFFCEAE8);

  /// 模态遮罩。
  static const scrim = Color(0xFF211B2D);

  // ── 圆角 ────────────────────────────────────────────────
  static const radiusWindow = 12.0;
  static const radiusDialog = 28.0;
  static const radiusCard = 16.0;
  static const radiusPreview = 12.0;
  static const radiusField = 4.0;
  static const radiusChip = 8.0;
  static const radiusPill = 100.0;

  // ── 间距 ────────────────────────────────────────────────
  static const gapHair = 2.0;
  static const gapTight = 4.0;
  static const gapSnug = 6.0;
  static const gapBase = 8.0;
  static const gapLoose = 12.0;
  static const gapSection = 16.0;
  static const gapWide = 32.0;

  // ── 尺寸 ────────────────────────────────────────────────
  static const windowWidth = 920.0;
  static const windowHeight = 736.0;
  static const titleBarHeight = 40.0;
  static const headerHeight = 84.0;
  static const statusBarHeight = 40.0;
  static const windowButtonWidth = 46.0;

  /// 工作区左右留白（920 - 872 = 48）。
  static const pagePadding = 24.0;

  // ── 阴影 ────────────────────────────────────────────────
  /// 浮层阴影：(0,8) blur28 #231B36 @16%。
  static const popoverShadow = [
    BoxShadow(
      color: Color(0x29231B36),
      offset: Offset(0, 8),
      blurRadius: 28,
    ),
  ];

  /// 窗口阴影：(0,12) blur36 #231B36 @11%。
  static const windowShadow = [
    BoxShadow(
      color: Color(0x1C231B36),
      offset: Offset(0, 12),
      blurRadius: 36,
    ),
  ];

  // ── 字体 ────────────────────────────────────────────────
  /// 设计稿用 Noto Sans SC；Windows 上回退到微软雅黑，字形接近。
  static const fontFamily = 'Noto Sans SC';
  static const fontFallback = <String>[
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
  ];

  /// 数字 / PID / 地址用等宽体，设计稿是 Cousine，Windows 用 Consolas。
  static const monoFamily = 'Consolas';
  static const monoFallback = <String>['Cascadia Mono', 'Courier New'];

  static TextStyle sans({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = onSurface,
    double? height,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height == null ? null : height / size,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = onSurface,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFamilyFallback: monoFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.13,
      letterSpacing: 0,
    );
  }
}
