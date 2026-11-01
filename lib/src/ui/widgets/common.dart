import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// 统一的图标包装：设计稿用的是 lucide 线性图标，
/// 这里全部走 Material Outlined，尺寸与颜色由调用处指定。
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 18,
    this.color = Tokens.onSurface,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: size, color: color, opticalSize: size);
  }
}

/// 悬浮态构建器。设计稿所有可点区域都有轻微背景变化。
class HoverRegion extends StatefulWidget {
  const HoverRegion({
    super.key,
    required this.builder,
    this.onTap,
    this.cursor = SystemMouseCursors.click,
  });

  final Widget Function(BuildContext context, bool hovering) builder;
  final VoidCallback? onTap;
  final MouseCursor cursor;

  @override
  State<HoverRegion> createState() => _HoverRegionState();
}

class _HoverRegionState extends State<HoverRegion> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : widget.cursor,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(context, _hovering),
      ),
    );
  }
}

/// 胶囊按钮（查询 / 取消 / 强制结束 / 界面风格入口）。
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.background = Tokens.primary,
    this.foreground = Tokens.onPrimary,
    this.borderColor,
    this.height = 40,
    this.padding = const EdgeInsets.symmetric(horizontal: 18),
    this.iconSize = 18,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w500,
    this.gap = 8,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final double height;
  final EdgeInsets padding;
  final double iconSize;
  final double fontSize;
  final FontWeight fontWeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return HoverRegion(
      onTap: onPressed,
      builder: (context, hovering) {
        var bg = background;
        if (hovering && enabled) {
          bg = background == Tokens.primary
              ? const Color(0xFF58458D)
              : Color.alphaBlend(Tokens.onSurface.withValues(alpha: 0.05), background);
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
            border: borderColor == null ? null : Border.all(color: borderColor!, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                AppIcon(icon!, size: iconSize, color: foreground),
                SizedBox(width: gap),
              ],
              Text(
                label,
                style: Tokens.sans(
                  size: fontSize,
                  weight: fontWeight,
                  color: foreground,
                  height: height * 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 设计稿里重复出现的小圆角灰块（PID 徽标、F5 快捷键）。
class SoftChip extends StatelessWidget {
  const SoftChip({
    super.key,
    required this.child,
    this.background = Tokens.surfaceContainer,
    this.radius = Tokens.radiusChip,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  final Widget child;
  final Color background;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// 11px 弱化说明文字。
class HintText extends StatelessWidget {
  const HintText(this.text, {super.key, this.color = Tokens.onSurfaceVariant, this.size = 11});

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Tokens.sans(size: size, color: color, height: size * 1.5),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 统一的无边框滚动条。
class AppScroll extends StatelessWidget {
  const AppScroll({super.key, required this.child, this.controller});

  final Widget child;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _NoGlowBehavior(),
      child: SingleChildScrollView(controller: controller, child: child),
    );
  }
}

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
