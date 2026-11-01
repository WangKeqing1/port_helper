import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/port_controller.dart';
import '../state/update_controller.dart';
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
import 'widgets/update_dialog.dart';

/// 主页面：严格按 920×736 的四段式布局拼装。
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.controller, this.updateController});

  /// 测试可注入；为空时页面自己建一个。
  final PortController? controller;

  /// 同上，更新流程的状态机。
  final UpdateController? updateController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final PortController _controller = widget.controller ?? PortController();
  late final UpdateController _update = widget.updateController ?? UpdateController();
  late final bool _ownsController = widget.controller == null;
  late final bool _ownsUpdate = widget.updateController == null;
  bool _styleMenuOpen = false;
  bool _confirmingKill = false;
  bool _showUpdate = false;

  @override
  void initState() {
    super.initState();
    // 打开即查一次，和设计稿的「查询完成」状态对齐。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.query();
      // 更新检查是静默的：没网、没新版本都不打扰用户。
      _update.checkSilently();
    });
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    if (_ownsUpdate) _update.dispose();
    super.dispose();
  }

  void _openUpdateDialog() {
    setState(() {
      _showUpdate = true;
      _styleMenuOpen = false;
      _confirmingKill = false;
    });
  }

  Future<void> _restartToUpdate() async {
    final ok = await _update.restart();
    if (!mounted) return;
    if (ok) {
      exit(0);
    } else {
      // 开发者直接跑 build 里的 exe 时没有启动器路径，只能手动重开。
      _controller.reportStatus('已更新，请手动关闭后重新打开', StatusKind.success);
      setState(() => _showUpdate = false);
    }
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
          if (_showUpdate && _update.status != UpdateStatus.downloading) {
            setState(() => _showUpdate = false);
          } else if (_confirmingKill) {
            setState(() => _confirmingKill = false);
          } else if (_styleMenuOpen) {
            setState(() => _styleMenuOpen = false);
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _update]),
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
                      AppStatusBar(
                        controller: _controller,
                        update: _update,
                        onOpenUpdate: _openUpdateDialog,
                      ),
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

                  if (_showUpdate)
                    _UpdateLayer(
                      controller: _update,
                      onClose: () => setState(() => _showUpdate = false),
                      onDownload: _update.startDownload,
                      onRestart: _restartToUpdate,
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

/// 更新弹窗的遮罩层，交互与强制结束确认保持一致。
class _UpdateLayer extends StatelessWidget {
  const _UpdateLayer({
    required this.controller,
    required this.onClose,
    required this.onDownload,
    required this.onRestart,
  });

  final UpdateController controller;
  final VoidCallback onClose;
  final VoidCallback onDownload;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    // 下载中不允许点遮罩关闭，避免用户以为能中断。
    final dismissible = controller.status != UpdateStatus.downloading;
    return Positioned(
      top: Tokens.titleBarHeight,
      left: 0,
      right: 0,
      bottom: 0,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: dismissible ? onClose : null,
              child: Container(color: Tokens.scrim.withValues(alpha: 0.32)),
            ),
          ),
          Center(
            child: UpdateDialog(
              controller: controller,
              onClose: onClose,
              onDownload: onDownload,
              onRestart: onRestart,
            ),
          ),
        ],
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
