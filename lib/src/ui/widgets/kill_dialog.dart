import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../theme/tokens.dart';
import 'common.dart';

/// 强制结束确认弹窗 480×366。遮罩只盖住标题栏以下的区域。
class KillConfirmDialog extends StatelessWidget {
  const KillConfirmDialog({
    super.key,
    required this.detail,
    required this.port,
    required this.bindings,
    required this.onCancel,
    required this.onConfirm,
  });

  final ProcessDetail detail;
  final int port;

  /// 该进程命中的全部监听记录。
  final List<PortBinding> bindings;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final protos = <String>{for (final b in bindings) b.protocol}.toList()..sort();
    final protoLabel = protos.join(' / ');

    return Container(
      width: 480,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Tokens.surfaceContainer,
        borderRadius: BorderRadius.circular(Tokens.radiusDialog),
        boxShadow: Tokens.popoverShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Tokens.dangerContainer,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const AppIcon(Icons.warning_amber_rounded, size: 22, color: Tokens.danger),
                ),
                const SizedBox(width: Tokens.gapLoose),
                Text(
                  '强制结束此进程？',
                  style: Tokens.sans(size: 22, weight: FontWeight.w500, height: 33),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.gapSection),
          Text(
            '此操作将立即结束进程，未保存的数据可能丢失。请先保存相关工作，再继续操作。',
            style: Tokens.sans(size: 12, color: Tokens.onSurfaceVariant, height: 20),
          ),
          const SizedBox(height: Tokens.gapSection),
          Container(
            padding: const EdgeInsets.all(Tokens.gapSection),
            decoration: BoxDecoration(
              color: Tokens.surface,
              borderRadius: BorderRadius.circular(Tokens.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const AppIcon(Icons.terminal_rounded, size: 18, color: Tokens.onSurfaceVariant),
                          const SizedBox(width: Tokens.gapBase),
                          Text(
                            detail.name,
                            style: Tokens.sans(size: 13, weight: FontWeight.w500, height: 24),
                          ),
                        ],
                      ),
                      Text(
                        'PID ${detail.pid}',
                        style: Tokens.mono(size: 11, color: Tokens.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Tokens.gapLoose),
                _KeyValueRow(
                  left: '端口 $port',
                  right: '$protoLabel · ${bindings.length} 条监听',
                ),
                const SizedBox(height: Tokens.gapLoose),
                _KeyValueRow(
                  left: '启动来源',
                  right: detail.parentName != null && detail.parentPid != null
                      ? '${detail.parentName} (PID ${detail.parentPid})'
                      : '未知',
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.gapSection),
          Row(
            children: [
              const AppIcon(Icons.info_outline_rounded, size: 17, color: Tokens.onSurfaceVariant),
              const SizedBox(width: Tokens.gapBase),
              Expanded(
                child: Text(
                  '该进程的 IPv4 和 IPv6 监听将一并关闭。此操作无法撤销。',
                  style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.gapSection),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              PillButton(
                label: '取消',
                onPressed: onCancel,
                background: Tokens.primaryContainer,
                foreground: Tokens.onPrimaryContainer,
                height: 40,
              ),
              const SizedBox(width: Tokens.gapBase),
              PillButton(
                label: '强制结束',
                onPressed: onConfirm,
                background: Tokens.danger,
                foreground: Colors.white,
                height: 40,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.left, required this.right});

  final String left;
  final String right;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: Tokens.sans(size: 12, color: Tokens.onSurfaceVariant, height: 18)),
          Text(right, style: Tokens.sans(size: 12, height: 18)),
        ],
      ),
    );
  }
}
