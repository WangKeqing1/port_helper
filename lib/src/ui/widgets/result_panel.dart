import 'package:flutter/material.dart';

import '../../model/models.dart';
import '../../state/port_controller.dart';
import '../../theme/tokens.dart';
import 'common.dart';

/// 列宽，直接取自设计稿坐标（相对内容区起点）。
const _colName = 210.0;
const _colPid = 110.0;
const _colProto = 90.0;
const _colAddress = 260.0;

/// 占用结果卡片 872×172：工具栏 + 表头 + 监听记录。
class ResultPanel extends StatelessWidget {
  const ResultPanel({super.key, required this.controller});

  final PortController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final bindings = result?.bindings ?? const <PortBinding>[];

    return Container(
      height: 172,
      decoration: BoxDecoration(
        color: Tokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _Toolbar(controller: controller),
          const _TableHeader(),
          Expanded(
            child: bindings.isEmpty
                ? _EmptyState(controller: controller)
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: bindings.length,
                    itemBuilder: (context, i) {
                      final b = bindings[i];
                      final isCurrent = i == controller.selectedIndex;
                      return _Row(
                        binding: b,
                        processName: result?.detailFor(b.pid)?.name,
                        selected: isCurrent && b.pid == controller.selectedPid,
                        expanded: isCurrent && b.pid == controller.selectedPid,
                        onTap: () => controller.selectRow(i, b.pid),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller});

  final PortController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.gapSection),
        child: Row(
          children: [
            Text(
              '占用结果',
              style: Tokens.sans(size: 14, weight: FontWeight.w500, height: 21),
            ),
            const SizedBox(width: Tokens.gapLoose),
            if (result != null)
              Text(
                result.summaryLabel,
                style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17),
              ),
            const Spacer(),
            HoverRegion(
              onTap: controller.busy ? null : controller.refresh,
              builder: (context, hovering) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: hovering ? Tokens.onPrimaryContainer : Tokens.primary,
                    ),
                    const SizedBox(width: Tokens.gapSnug),
                    Text(
                      '刷新',
                      style: Tokens.sans(
                        size: 12,
                        weight: FontWeight.w500,
                        color: hovering ? Tokens.onPrimaryContainer : Tokens.primary,
                        height: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: Tokens.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: Tokens.gapSection),
      child: Row(
        children: const [
          SizedBox(width: _colName, child: HintText('进程名称')),
          SizedBox(width: _colPid, child: HintText('PID')),
          SizedBox(width: _colProto, child: HintText('协议')),
          SizedBox(width: _colAddress, child: HintText('本地地址')),
          Expanded(child: HintText('状态')),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.binding,
    required this.processName,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final PortBinding binding;
  final String? processName;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      onTap: onTap,
      builder: (context, hovering) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: Tokens.gapSection),
          decoration: BoxDecoration(
            color: selected
                ? Tokens.primaryContainer
                : (hovering ? Tokens.surfaceContainer : Tokens.surfaceContainerLow),
            border: Border.all(
              color: selected ? Tokens.primary : Tokens.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: _colName,
                child: Row(
                  children: [
                    const AppIcon(Icons.terminal_rounded, size: 18, color: Tokens.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        processName ?? 'PID ${binding.pid}',
                        style: Tokens.sans(size: 13, weight: FontWeight.w500, height: 20),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: _colPid,
                child: Text('${binding.pid}', style: Tokens.mono(size: 13, color: Tokens.onSurface)),
              ),
              SizedBox(
                width: _colProto,
                child: Text(binding.protocol, style: Tokens.sans(size: 13, height: 18)),
              ),
              SizedBox(
                width: _colAddress,
                child: Text(binding.localAddress, style: Tokens.mono(size: 13, color: Tokens.onSurface)),
              ),
              Expanded(
                child: Row(
                  children: [
                    AppIcon(
                      Icons.radio_button_checked,
                      size: 13,
                      color: binding.isListening ? Tokens.success : Tokens.onSurfaceVariant,
                    ),
                    const SizedBox(width: Tokens.gapSnug),
                    Text(
                      binding.stateLabel,
                      style: Tokens.sans(
                        size: 12,
                        color: binding.isListening ? Tokens.success : Tokens.onSurfaceVariant,
                        height: 18,
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(
                expanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                size: 16,
                color: Tokens.onSurfaceVariant,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.controller});

  final PortController controller;

  @override
  Widget build(BuildContext context) {
    final hasQuery = controller.result != null;
    final text = !hasQuery
        ? '尚未查询'
        : (controller.result!.error != null ? '查询失败' : '该端口当前没有监听');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          style: Tokens.sans(size: 12, color: Tokens.onSurfaceVariant, height: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
