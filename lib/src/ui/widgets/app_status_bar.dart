import 'package:flutter/material.dart';

import '../../state/port_controller.dart';
import '../../state/update_controller.dart';
import '../../theme/tokens.dart';
import 'common.dart';

/// 状态栏 920×40：左侧查询状态，右侧更新提示、上次刷新时间与 F5 提示。
class AppStatusBar extends StatelessWidget {
  const AppStatusBar({
    super.key,
    required this.controller,
    this.update,
    this.onOpenUpdate,
  });

  final PortController controller;

  /// 有更新时才传入，没传就完全不显示这一块。
  final UpdateController? update;
  final VoidCallback? onOpenUpdate;

  @override
  Widget build(BuildContext context) {
    final kind = controller.statusKind;
    return Container(
      height: Tokens.statusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: Tokens.pagePadding),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Tokens.outlineVariant, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusIcon(kind: kind),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    controller.statusText,
                    style: Tokens.sans(size: 11, color: _statusColor(kind), height: 17),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (update != null && update!.hasUpdate && onOpenUpdate != null) ...[
                _UpdateChip(update: update!, onTap: onOpenUpdate!),
                const SizedBox(width: Tokens.gapSection),
              ],
              Text(
                '上次刷新 ${_clock(controller.result?.queriedAt)}',
                style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17),
              ),
              const SizedBox(width: Tokens.gapSection),
              SoftChip(
                background: Tokens.surfaceContainerHigh,
                radius: Tokens.radiusField,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'F5 刷新',
                  style: Tokens.sans(size: 10, color: Tokens.onSurfaceVariant, height: 15),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _statusColor(StatusKind kind) => switch (kind) {
        StatusKind.success => Tokens.success,
        StatusKind.error => Tokens.danger,
        StatusKind.busy => Tokens.primary,
        StatusKind.warning => Tokens.onSurfaceVariant,
        StatusKind.idle => Tokens.onSurfaceVariant,
      };

  static String _clock(DateTime? t) {
    if (t == null) return '--:--:--';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

/// 状态栏里的更新入口，三态：可更新 / 下载中 / 待重启。
class _UpdateChip extends StatelessWidget {
  const _UpdateChip({required this.update, required this.onTap});

  final UpdateController update;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (update.status) {
      UpdateStatus.downloading => (
          '更新中 ${(update.progress * 100).toStringAsFixed(0)}%',
          Icons.downloading_rounded,
        ),
      UpdateStatus.ready => ('重启以更新', Icons.restart_alt_rounded),
      _ => ('新版本 v${update.info?.version ?? ''}', Icons.system_update_alt_rounded),
    };

    return HoverRegion(
      onTap: onTap,
      builder: (context, hovering) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 22,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: hovering
                ? Color.alphaBlend(Tokens.primary.withValues(alpha: 0.12), Tokens.primaryContainer)
                : Tokens.primaryContainer,
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: 13, color: Tokens.onPrimaryContainer),
              const SizedBox(width: 5),
              Text(
                label,
                style: Tokens.sans(
                  size: 10,
                  weight: FontWeight.w500,
                  color: Tokens.onPrimaryContainer,
                  height: 15,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.kind});

  final StatusKind kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case StatusKind.busy:
        return const SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(strokeWidth: 1.6, color: Tokens.primary),
        );
      case StatusKind.error:
        return const AppIcon(Icons.error_outline_rounded, size: 15, color: Tokens.danger);
      case StatusKind.success:
        return const AppIcon(Icons.check_circle_outline_rounded, size: 15, color: Tokens.success);
      case StatusKind.warning:
        return const AppIcon(Icons.info_outline_rounded, size: 15, color: Tokens.onSurfaceVariant);
      case StatusKind.idle:
        return const AppIcon(Icons.circle_outlined, size: 13, color: Tokens.outline);
    }
  }
}
