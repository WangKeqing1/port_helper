import 'package:flutter/material.dart';

import '../../model/update_info.dart';
import '../../state/update_controller.dart';
import '../../theme/tokens.dart';
import 'common.dart';

/// 更新对话框。三个形态共用一套骨架：可更新 / 下载中 / 已就绪，失败时换成提示。
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({
    super.key,
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
    final status = controller.status;
    final info = controller.info;

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
          _Header(status: status),
          const SizedBox(height: Tokens.gapSection),
          if (status == UpdateStatus.failed)
            _FailureBody(message: controller.error ?? '更新失败')
          else if (info != null)
            _UpdateBody(info: info, status: status, progress: controller.progress),
          const SizedBox(height: Tokens.gapSection),
          _Actions(
            status: status,
            onClose: onClose,
            onDownload: onDownload,
            onRestart: onRestart,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status});

  final UpdateStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, title, tint, background) = switch (status) {
      UpdateStatus.ready => (
          Icons.check_circle_outline_rounded,
          '更新已就绪',
          Tokens.success,
          const Color(0xFFE6F2EA),
        ),
      UpdateStatus.failed => (
          Icons.error_outline_rounded,
          '更新失败',
          Tokens.danger,
          Tokens.dangerContainer,
        ),
      _ => (
          Icons.system_update_alt_rounded,
          '发现新版本',
          Tokens.primary,
          Tokens.primaryContainer,
        ),
    };

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: AppIcon(icon, size: 22, color: tint),
          ),
          const SizedBox(width: Tokens.gapLoose),
          Text(
            title,
            style: Tokens.sans(size: 22, weight: FontWeight.w500, height: 33),
          ),
        ],
      ),
    );
  }
}

class _UpdateBody extends StatelessWidget {
  const _UpdateBody({required this.info, required this.status, required this.progress});

  final UpdateInfo info;
  final UpdateStatus status;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(Tokens.gapSection),
          decoration: BoxDecoration(
            color: Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.radiusCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'v${info.version}',
                    style: Tokens.mono(size: 18, color: Tokens.primary),
                  ),
                  const SizedBox(width: Tokens.gapBase),
                  Text(
                    '· ${info.sizeLabel}',
                    style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17),
                  ),
                ],
              ),
              if (info.notes != null && info.notes!.isNotEmpty) ...[
                const SizedBox(height: Tokens.gapBase),
                Text(
                  info.notes!,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: Tokens.sans(size: 12, color: Tokens.onSurfaceVariant, height: 20),
                ),
              ],
            ],
          ),
        ),
        if (status == UpdateStatus.downloading) ...[
          const SizedBox(height: Tokens.gapSection),
          ClipRRect(
            borderRadius: BorderRadius.circular(Tokens.radiusField),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Tokens.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation(Tokens.primary),
            ),
          ),
          const SizedBox(height: Tokens.gapBase),
          Text(
            '正在下载 ${(progress * 100).toStringAsFixed(0)}%',
            style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 17),
          ),
        ],
        if (status == UpdateStatus.ready) ...[
          const SizedBox(height: Tokens.gapSection),
          Row(
            children: [
              const AppIcon(Icons.info_outline_rounded, size: 17, color: Tokens.onSurfaceVariant),
              const SizedBox(width: Tokens.gapBase),
              Expanded(
                child: Text(
                  '新版本已下载并解压。重启后生效，当前窗口会关闭。',
                  style: Tokens.sans(size: 11, color: Tokens.onSurfaceVariant, height: 18),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Tokens.gapSection),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusCard),
      ),
      child: Text(
        message,
        style: Tokens.sans(size: 12, color: Tokens.onSurface, height: 20),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.status,
    required this.onClose,
    required this.onDownload,
    required this.onRestart,
  });

  final UpdateStatus status;
  final VoidCallback onClose;
  final VoidCallback onDownload;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final busy = status == UpdateStatus.downloading;

    final primaryLabel = switch (status) {
      UpdateStatus.ready => '立即重启',
      UpdateStatus.failed => '重试',
      _ => '立即更新',
    };
    final onPrimary = switch (status) {
      UpdateStatus.ready => onRestart,
      UpdateStatus.failed => onDownload,
      _ => onDownload,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        PillButton(
          label: busy ? '请稍候' : '稍后',
          onPressed: busy ? null : onClose,
          background: Tokens.primaryContainer,
          foreground: busy ? Tokens.outline : Tokens.onPrimaryContainer,
          height: 40,
        ),
        const SizedBox(width: Tokens.gapBase),
        PillButton(
          label: primaryLabel,
          onPressed: busy ? null : onPrimary,
          background: Tokens.primary,
          foreground: Tokens.onPrimary,
          height: 40,
        ),
      ],
    );
  }
}
