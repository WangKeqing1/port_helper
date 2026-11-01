import 'package:flutter/material.dart';

import '../../state/port_controller.dart';
import '../../theme/tokens.dart';
import 'common.dart';

/// 进程操作条 872×52：左侧影响提示，右侧「强制结束进程」。
class ActionPanel extends StatelessWidget {
  const ActionPanel({super.key, required this.controller, required this.onKill});

  final PortController controller;
  final VoidCallback onKill;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final detail = controller.selectedProcess;
    final port = result?.port;
    final enabled = detail != null && !controller.busy;

    final primaryLine = port == null
        ? '结束进程将释放该端口的全部监听'
        : '结束进程将释放端口 $port 的全部监听';

    return SizedBox(
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const AppIcon(Icons.info_outline_rounded, size: 17, color: Tokens.onSurfaceVariant),
                const SizedBox(width: 9),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryLine,
                      style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '强制结束前，请先保存相关工作。',
                      style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PillButton(
            label: '强制结束进程',
            icon: Icons.block_rounded,
            onPressed: enabled ? onKill : null,
            background: Tokens.surface,
            foreground: enabled ? Tokens.danger : Tokens.outline,
            borderColor: enabled ? Tokens.danger.withValues(alpha: 0.55) : Tokens.outlineVariant,
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
        ],
      ),
    );
  }
}
