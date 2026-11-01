import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../theme/tokens.dart';
import 'common.dart';

/// 窗口标题栏 920×40：左侧应用标识，右侧自绘的最小化 / 最大化 / 关闭。
class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Tokens.titleBarHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => windowManager.startDragging(),
        onDoubleTap: () => windowManager.minimize(),
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              const _AppIdentity(),
              const Spacer(),
              _WindowControls(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppIdentity extends StatelessWidget {
  const _AppIdentity();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppIcon(Icons.power_off_outlined, size: 18, color: Tokens.primary),
        const SizedBox(width: Tokens.gapBase),
        Text(
          '端口助手',
          style: Tokens.sans(size: 12, weight: FontWeight.w500, height: 18),
        ),
      ],
    );
  }
}

class _WindowControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          icon: Icons.remove,
          size: 14,
          tooltip: '最小化',
          onTap: () => windowManager.minimize(),
        ),
        _WindowButton(
          icon: Icons.crop_square,
          size: 12,
          tooltip: '窗口尺寸固定为 920×736',
          enabled: false,
          onTap: () {},
        ),
        _WindowButton(
          icon: Icons.close,
          size: 14,
          tooltip: '关闭',
          danger: true,
          onTap: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.size,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
    this.enabled = true,
  });

  final IconData icon;
  final double size;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: HoverRegion(
        onTap: enabled ? onTap : null,
        builder: (context, hovering) {
          final active = hovering && enabled;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: Tokens.windowButtonWidth,
            height: Tokens.titleBarHeight,
            color: active
                ? (danger ? Tokens.danger.withValues(alpha: 0.9) : Tokens.onSurface.withValues(alpha: 0.07))
                : Colors.transparent,
            alignment: Alignment.center,
            child: AppIcon(
              icon,
              size: size + 2,
              color: !enabled
                  ? Tokens.outline.withValues(alpha: 0.4)
                  : (active && danger ? Colors.white : Tokens.onSurfaceVariant),
            ),
          );
        },
      ),
    );
  }
}
