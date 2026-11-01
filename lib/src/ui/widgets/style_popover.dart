import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'common.dart';

/// 界面风格浮层 372×353，挂在「界面风格」按钮右下。
/// 位置取自设计稿：距窗口右侧 54、距窗口顶部 112。
class StylePopover extends StatelessWidget {
  const StylePopover({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 372,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusDialog),
        border: Border.all(color: Tokens.outlineVariant, width: 1),
        boxShadow: Tokens.popoverShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 27,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '界面风格',
                  style: Tokens.sans(size: 18, weight: FontWeight.w500, height: 27),
                ),
                HoverRegion(
                  onTap: onClose,
                  builder: (context, hovering) => AppIcon(
                    Icons.close,
                    size: 18,
                    color: hovering ? Tokens.onSurface : Tokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.gapSection),
          Text(
            '选择适合你的界面外观。切换风格不会影响查询结果。',
            style: Tokens.sans(size: 12, color: Tokens.onSurfaceVariant, height: 18),
          ),
          const SizedBox(height: Tokens.gapSection),
          _CurrentStyleCard(),
          const SizedBox(height: Tokens.gapSection),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: AppIcon(Icons.info_outline_rounded, size: 16, color: Tokens.onSurfaceVariant),
              ),
              const SizedBox(width: Tokens.gapBase),
              Expanded(
                child: Text(
                  '当前仅提供 Material Design 3。\n更多风格将在后续版本中加入。',
                  style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrentStyleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Tokens.gapSection),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        border: Border.all(color: Tokens.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 41,
            child: Row(
              children: [
                const AppIcon(Icons.check_circle_outline_rounded, size: 22, color: Tokens.primary),
                const SizedBox(width: Tokens.gapLoose),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Material Design 3',
                        style: Tokens.sans(size: 14, weight: FontWeight.w500, height: 21),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '当前使用',
                        style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.gapSection),
          _Preview(),
          const SizedBox(height: Tokens.gapSection),
          SizedBox(
            height: 17,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '柔和色调 · 圆角容器',
                  style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17),
                ),
                Row(
                  children: const [
                    _Dot(color: Tokens.primary),
                    SizedBox(width: 5),
                    _Dot(color: Tokens.primaryContainer),
                    SizedBox(width: 5),
                    _Dot(color: Tokens.surfaceContainerHigh),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Tokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Tokens.radiusPreview),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 100,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Tokens.outline.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 64,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Tokens.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 68,
            height: 30,
            decoration: BoxDecoration(
              color: Tokens.primary,
              borderRadius: BorderRadius.circular(Tokens.radiusPill),
            ),
            alignment: Alignment.center,
            child: const AppIcon(Icons.check, size: 16, color: Tokens.onPrimary),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
