import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../model/models.dart';
import '../../state/port_controller.dart';
import '../../theme/tokens.dart';
import 'common.dart';

/// 端口查询卡片 872×106：输入框 + 协议分段 + 查询按钮 + 底部帮助行。
class QueryPanel extends StatefulWidget {
  const QueryPanel({super.key, required this.controller});

  final PortController controller;

  @override
  State<QueryPanel> createState() => _QueryPanelState();
}

class _QueryPanelState extends State<QueryPanel> {
  late final TextEditingController _text = TextEditingController(text: widget.controller.portText);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncText);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// 外部（清空按钮等）改了内容时回填输入框。
  void _syncText() {
    final want = widget.controller.portText;
    if (_text.text != want) {
      _text.value = TextEditingValue(
        text: want,
        selection: TextSelection.collapsed(offset: want.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Container(
      height: 106,
      padding: const EdgeInsets.all(Tokens.gapSection),
      decoration: BoxDecoration(
        color: Tokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(child: _PortField(text: _text, focus: _focus, controller: c)),
                const SizedBox(width: Tokens.gapSection),
                _ProtocolSegments(
                  value: c.filter,
                  onChanged: c.setFilter,
                ),
                const SizedBox(width: Tokens.gapSection),
                PillButton(
                  label: '查询',
                  icon: Icons.search,
                  onPressed: c.busy ? null : () => c.query(),
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.gapBase),
          SizedBox(
            height: 17,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                HintText('输入端口号，范围 1–65535'),
                HintText('Enter 查询'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 带浮动标签的端口输入框。
class _PortField extends StatelessWidget {
  const _PortField({required this.text, required this.focus, required this.controller});

  final TextEditingController text;
  final FocusNode focus;
  final PortController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.only(left: 16, right: 12),
          decoration: BoxDecoration(
            color: Tokens.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Tokens.radiusField),
            border: Border.all(
              color: focus.hasFocus ? Tokens.primary : Tokens.outline,
              width: focus.hasFocus ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: text,
                  focusNode: focus,
                  onChanged: controller.setPortText,
                  onSubmitted: (_) => controller.query(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                  cursorHeight: 22,
                  cursorWidth: 1.6,
                  style: Tokens.mono(size: 20, color: Tokens.onSurface),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: '8080',
                    hintStyle: TextStyle(color: Tokens.outline),
                  ),
                ),
              ),
              if (controller.portText.isNotEmpty)
                HoverRegion(
                  onTap: () {
                    controller.clearPort();
                    focus.requestFocus();
                  },
                  builder: (context, hovering) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: AppIcon(
                      Icons.cancel_outlined,
                      size: 18,
                      color: hovering ? Tokens.onSurface : Tokens.outline,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // 浮动标签压在边框上，背景与输入框同色以「切断」边框线。
        Positioned(
          left: 12,
          top: -9,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            color: Tokens.surfaceContainerLow,
            child: Text(
              '端口号',
              style: Tokens.sans(size: 11, color: Tokens.primary, height: 17),
            ),
          ),
        ),
      ],
    );
  }
}

/// 全部 / TCP / UDP 分段控件。
class _ProtocolSegments extends StatelessWidget {
  const _ProtocolSegments({required this.value, required this.onChanged});

  final ProtocolFilter value;
  final ValueChanged<ProtocolFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        border: Border.all(color: Tokens.outline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final f in ProtocolFilter.values)
            _Segment(
              filter: f,
              selected: f == value,
              onTap: () => onChanged(f),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.filter, required this.selected, required this.onTap});

  final ProtocolFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      onTap: onTap,
      builder: (context, hovering) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 70,
          height: 40,
          decoration: BoxDecoration(
            color: selected
                ? Tokens.primaryContainer
                : (hovering ? Tokens.surfaceContainer : Colors.transparent),
            borderRadius: BorderRadius.circular(Tokens.radiusPill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                const AppIcon(Icons.check, size: 15, color: Tokens.onPrimaryContainer),
                const SizedBox(width: 4),
              ],
              Text(
                filter.label,
                style: Tokens.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  color: selected ? Tokens.onPrimaryContainer : Tokens.onSurfaceVariant,
                  height: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
