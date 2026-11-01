import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/port_controller.dart';
import '../theme/tokens.dart';
import 'widgets/action_panel.dart';
import 'widgets/app_status_bar.dart';
import 'widgets/detail_panel.dart';
import 'widgets/kill_dialog.dart';
import 'widgets/page_header.dart';
import 'widgets/query_panel.dart';
import 'widgets/result_panel.dart';
import 'widgets/style_popover.dart';
import 'widgets/title_bar.dart';

/// 主页面：严格按 920×736 的四段式布局拼装。
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.controller});

  /// 测试可注入；为空时页面自己建一个。
  final PortController? controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PortController _controller = widget.controller ?? PortController();
  late final bool _ownsController = widget.controller == null;
  bool _styleMenuOpen = false;
  bool _confirmingKill = false;

  @override
  void initState() {
    super.initState();
    // 打开即查一次，和设计稿的「查询完成」状态对齐。
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.query());
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _openKillDialog() {
    if (_controller.selectedProcess == null || _controller.busy) return;
    setState(() {
      _confirmingKill = true;
      _styleMenuOpen = false;
    });
  }

  Future<void> _confirmKill() async {
    final messenger = _controller.statusText;
    setState(() => _confirmingKill = false);
    await _controller.killSelected();
    if (!mounted) return;
    // 结束失败时状态栏已经写明原因，这里不再额外弹提示。
    if (messenger.isEmpty) return;
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): () => _controller.refresh(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_confirmingKill) {
            setState(() => _confirmingKill = false);
          } else if (_styleMenuOpen) {
            setState(() => _styleMenuOpen = false);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Container(
              decoration: BoxDecoration(
                color: Tokens.surface,
                borderRadius: BorderRadius.circular(Tokens.radiusWindow),
                // 窗口描边不占内边距：设计稿的 1px 边框会挤掉内容高度，
                // 这里用一圈极淡的阴影代替，视觉等效且不影响 920×736 的布局。
                boxShadow: const [
                  BoxShadow(color: Tokens.outlineVariant, spreadRadius: 0.6),
                  ...Tokens.windowShadow,
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Column(
                    children: [
                      const TitleBar(),
                      PageHeader(
                        styleMenuOpen: _styleMenuOpen,
                        onToggleStyleMenu: () {
                          setState(() => _styleMenuOpen = !_styleMenuOpen);
                        },
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: Tokens.pagePadding,
                            right: Tokens.pagePadding,
                            bottom: 20,
                          ),
                          child: Column(
                            spacing: Tokens.gapSection,
                            children: [
                              QueryPanel(controller: _controller),
                              ResultPanel(controller: _controller),
                              DetailPanel(controller: _controller),
                              ActionPanel(controller: _controller, onKill: _openKillDialog),
                            ],
                          ),
                        ),
                      ),
                      AppStatusBar(controller: _controller),
                    ],
                  ),

                  // 点击浮层外部收起。
                  if (_styleMenuOpen)
                    Positioned(
                      top: Tokens.titleBarHeight,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => setState(() => _styleMenuOpen = false),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  if (_styleMenuOpen)
                    Positioned(
                      top: 112,
                      right: 54,
                      child: StylePopover(
                        onClose: () => setState(() => _styleMenuOpen = false),
                      ),
                    ),

                  if (_confirmingKill && _controller.selectedProcess != null)
                    _KillLayer(
                      controller: _controller,
                      onCancel: () => setState(() => _confirmingKill = false),
                      onConfirm: _confirmKill,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 遮罩 + 居中弹窗。遮罩只覆盖标题栏以下，保持窗口拖动区域可用。
class _KillLayer extends StatelessWidget {
  const _KillLayer({
    required this.controller,
    required this.onCancel,
    required this.onConfirm,
  });

  final PortController controller;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final detail = controller.selectedProcess!;
    final result = controller.result!;
    final bindings = result.bindings.where((b) => b.pid == detail.pid).toList();

    return Positioned(
      top: Tokens.titleBarHeight,
      left: 0,
      right: 0,
      bottom: 0,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onCancel,
              child: Container(color: Tokens.scrim.withValues(alpha: 0.32)),
            ),
          ),
          Center(
            child: KillConfirmDialog(
              detail: detail,
              port: result.port,
              bindings: bindings,
              onCancel: onCancel,
              onConfirm: onConfirm,
            ),
          ),
        ],
      ),
    );
  }
}
