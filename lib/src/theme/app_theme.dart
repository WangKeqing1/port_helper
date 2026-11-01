import 'package:flutter/material.dart';

import 'tokens.dart';

/// 全局主题。颜色不在 ThemeData 里派生 —— 设计稿给的是一套固定令牌，
/// 由 [Tokens] 直接引用，避免 M3 从种子色推导出偏差。
ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: Tokens.primary,
    onPrimary: Tokens.onPrimary,
    primaryContainer: Tokens.primaryContainer,
    onPrimaryContainer: Tokens.onPrimaryContainer,
    secondary: Tokens.primary,
    onSecondary: Tokens.onPrimary,
    surface: Tokens.surface,
    onSurface: Tokens.onSurface,
    surfaceContainerLowest: Tokens.surfaceContainerLowest,
    surfaceContainerLow: Tokens.surfaceContainerLow,
    surfaceContainer: Tokens.surfaceContainer,
    surfaceContainerHigh: Tokens.surfaceContainerHigh,
    onSurfaceVariant: Tokens.onSurfaceVariant,
    outline: Tokens.outline,
    outlineVariant: Tokens.outlineVariant,
    error: Tokens.danger,
    onError: Tokens.onPrimary,
    scrim: Tokens.scrim,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: Tokens.fontFamily,
    fontFamilyFallback: Tokens.fontFallback,
    visualDensity: VisualDensity.standard,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 420),
      textStyle: Tokens.sans(size: 11, color: Tokens.surface),
      decoration: BoxDecoration(
        color: Tokens.onSurface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: WidgetStateProperty.all(4),
      radius: const Radius.circular(2),
      thumbColor: WidgetStateProperty.all(Tokens.outline.withValues(alpha: 0.35)),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Tokens.primary,
      selectionColor: Tokens.primaryContainer,
      selectionHandleColor: Tokens.primary,
    ),
  );
}
