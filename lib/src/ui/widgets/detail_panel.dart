import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/models.dart';
import '../../state/port_controller.dart';
import '../../theme/tokens.dart';
import 'common.dart';

/// 进程详情卡片 872×174：摘要 + 属性行 + 启动来源 + 可复制路径。
class DetailPanel extends StatelessWidget {
  const DetailPanel({super.key, required this.controller});

  final PortController controller;

  @override
  Widget build(BuildContext context) {
    final detail = controller.selectedProcess;
    final binding = controller.selectedBinding;
    final result = controller.result;

    return Container(
      height: 174,
      padding: const EdgeInsets.all(Tokens.gapSection),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
        border: Border.all(color: Tokens.outlineVariant, width: 1),
      ),
      child: detail == null
          ? const Center(
              child: Text(
                '选择一条监听记录查看进程详情',
                style: TextStyle(fontSize: 12, color: Tokens.onSurfaceVariant),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Summary(detail: detail),
                const SizedBox(height: 10),
                _Attributes(
                  detail: detail,
                  port: result?.port ?? 0,
                  binding: binding,
                  result: result,
                ),
                const SizedBox(height: 10),
                _LaunchChain(detail: detail),
                const SizedBox(height: 10),
                _PathRow(
                  path: detail.executablePath,
                  onCopied: () => controller.reportStatus('进程路径已复制', StatusKind.success),
                ),
              ],
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.detail});

  final ProcessDetail detail;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 41,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Tokens.surfaceContainer,
              borderRadius: BorderRadius.circular(Tokens.radiusPreview),
            ),
            alignment: Alignment.center,
            child: const AppIcon(Icons.terminal_rounded, size: 20, color: Tokens.onSurfaceVariant),
          ),
          const SizedBox(width: Tokens.gapLoose),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.name,
                  style: Tokens.sans(size: 15, weight: FontWeight.w500, height: 23),
                ),
                const SizedBox(height: 1),
                Text(
                  detail.subtitle,
                  style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Tokens.gapLoose),
          SoftChip(
            child: Text(
              'PID ${detail.pid}',
              style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _Attributes extends StatelessWidget {
  const _Attributes({
    required this.detail,
    required this.port,
    required this.binding,
    required this.result,
  });

  final ProcessDetail detail;
  final int port;
  final PortBinding? binding;
  final PortQueryResult? result;

  @override
  Widget build(BuildContext context) {
    final stacks = result?.hasBothStacksFor(detail.pid) ?? false;
    final scope = stacks ? 'IPv4 / IPv6' : (binding?.isIpv6 == true ? 'IPv6' : 'IPv4');
    return SizedBox(
      height: 17,
      child: Row(
        children: [
          _Pair(label: '运行用户', value: detail.userName ?? '本地用户'),
          const SizedBox(width: Tokens.gapWide),
          _Pair(label: '启动时间', value: detail.formatStartTime()),
          const SizedBox(width: Tokens.gapWide),
          _Pair(label: '监听端口', value: '$port（$scope）'),
        ],
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17)),
        const SizedBox(width: 10),
        Text(value, style: Tokens.sans(size: 11, height: 17)),
      ],
    );
  }
}

class _LaunchChain extends StatelessWidget {
  const _LaunchChain({required this.detail});

  final ProcessDetail detail;

  @override
  Widget build(BuildContext context) {
    final parent = detail.parentName;
    final parentPid = detail.parentPid;
    return SizedBox(
      height: 17,
      child: Row(
        children: [
          Text('启动来源', style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17)),
          const SizedBox(width: 10),
          if (parent != null && parentPid != null) ...[
            Text('$parent (PID $parentPid)', style: Tokens.sans(size: 11, height: 17)),
            const SizedBox(width: Tokens.gapSnug),
            Text('→', style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17)),
            const SizedBox(width: Tokens.gapSnug),
            Text('${detail.name} (PID ${detail.pid})', style: Tokens.sans(size: 11, height: 17)),
          ] else
            Text('未获取到父进程', style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17)),
        ],
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({required this.path, required this.onCopied});

  final String? path;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final text = path ?? '读取不到可执行文件路径（可能需要管理员权限）';
    final canCopy = path != null && path!.isNotEmpty;
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: Tokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Tokens.radiusChip),
      ),
      child: Row(
        children: [
          Text('进程路径', style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17)),
          const SizedBox(width: Tokens.gapLoose),
          Expanded(
            child: Text(
              text,
              style: Tokens.mono(
                size: 11,
                color: canCopy ? Tokens.onSurface : Tokens.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Tokens.gapLoose),
          HoverRegion(
            onTap: canCopy
                ? () async {
                    await Clipboard.setData(ClipboardData(text: path!));
                    onCopied();
                  }
                : null,
            builder: (context, hovering) => Tooltip(
              message: canCopy ? '复制路径' : '无可复制内容',
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AppIcon(
                  Icons.content_copy_rounded,
                  size: 14,
                  color: !canCopy
                      ? Tokens.outline
                      : (hovering ? Tokens.primary : Tokens.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
