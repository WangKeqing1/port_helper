import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'common.dart';

/// 功能标题 920×84：左侧标题 + 副标题，右侧「界面风格」入口。
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.styleMenuOpen,
    required this.onToggleStyleMenu,
  });

  final bool styleMenuOpen;
  final VoidCallback onToggleStyleMenu;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Tokens.headerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.pagePadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '端口占用查询',
                  style: Tokens.sans(size: 24, weight: FontWeight.w500, height: 36),
                ),
                const SizedBox(height: 3),
                Text(
                  '定位占用进程，快速释放本地端口。',
                  style: Tokens.sans(size: 12, color: Tokens.onSurfaceVariant, height: 18),
                ),
              ],
            ),
            _StyleEntry(open: styleMenuOpen, onTap: onToggleStyleMenu),
          ],
        ),
      ),
    );
  }
}

class _StyleEntry extends StatelessWidget {
  const _StyleEntry({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      onTap: onTap,
      builder: (context, hovering) {
        final bg = open
            ? Tokens.primaryContainer
            : (hovering ? Tokens.surfaceContainer : Tokens.surfaceContainerLow);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
            border: Border.all(
              color: open ? Tokens.primary : Tokens.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppIcon(Icons.palette_outlined, size: 18, color: Tokens.primary),
              const SizedBox(width: Tokens.gapBase),
              Text(
                '界面风格',
                style: Tokens.sans(size: 12, weight: FontWeight.w500, color: Tokens.primary, height: 18),
              ),
              const SizedBox(width: Tokens.gapBase),
              AnimatedRotation(
                turns: open ? 0.5 : 0,
                duration: const Duration(milliseconds: 160),
                child: const AppIcon(Icons.keyboard_arrow_down_rounded, size: 16, color: Tokens.primary),
              ),
            ],
          ),
        );
      },
    );
  }
}
