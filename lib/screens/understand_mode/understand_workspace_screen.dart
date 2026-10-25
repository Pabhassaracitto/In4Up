// lib/screens/understand_mode/understand_workspace_screen.dart

import 'package:flutter/material.dart';

import '../../features/understand_ai/understand_ai_context.dart';
import '../../core/navigation/workspace_handoff_inbox.dart';
import '../../models/i4u_shell_contracts.dart';

import '../../widgets/auto_hide_banner.dart';
import 'services/understand_ai_coach_launcher.dart';
import 'understand_tab_connector.dart';
import 'widgets/understand_workspace_header.dart';

class UnderstandWorkspaceScreen extends StatelessWidget {
  final VoidCallback onOpenSpeakMode;
  final VoidCallback onOpenYouGlish;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenQuickActions;
  final UnderstandLearningMode initialMode;
  final ValueChanged<UnderstandLearningMode>? onModeChanged;
  final bool showInternalModeTabs;

  /// Optional để không phá caller hiện tại (main_shell không cần đổi):
  /// mặc định mở sheet "Trợ lý hiểu bài" từ state của tab Hiểu.
  final VoidCallback? onOpenAiCoach;

  const UnderstandWorkspaceScreen({
    super.key,
    required this.onOpenSpeakMode,
    required this.onOpenYouGlish,
    required this.onOpenReview,
    required this.onOpenQuickActions,
    this.initialMode = UnderstandLearningMode.sync,
    this.onModeChanged,
    this.showInternalModeTabs = true,
    this.onOpenAiCoach,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: I4uWorkspaceHandoffInbox.instance,
      builder: (context, _) {
        final source = I4uWorkspaceHandoffInbox.instance.current;
        return Column(
          children: [
            if (source != null) _buildIncomingSourceCard(context, source),
            AutoHideInfoBanner(
          storageKey: 'understand_workspace_header',
          autoHideAfter: const Duration(seconds: 6),
          child: UnderstandWorkspaceHeader(
            onOpenSpeakMode: onOpenSpeakMode,
            onOpenYouGlish: onOpenYouGlish,
            onOpenReview: onOpenReview,
            onOpenQuickActions: onOpenQuickActions,
            onOpenAiCoach:
                onOpenAiCoach ?? () => openUnderstandAiCoach(context),
          ),
        ),
        Expanded(
          child: UnderstandTabConnector(
            initialMode: initialMode,
            onModeChanged: onModeChanged,
            showInternalModeTabs: showInternalModeTabs,
          ),
          ),
        ],
      );
    },
  );
  }

  Widget _buildIncomingSourceCard(
    BuildContext context,
    I4uSourceFingerprint source,
  ) {
    final isVideo = source.sourceType == I4uSourceType.video;
    final timestamp = source.timestampMs == null
        ? null
        : Duration(milliseconds: source.timestampMs!);
    return Material(
      color: const Color(0xFF121B32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        child: Row(
          children: [
            Icon(
              isVideo ? Icons.ondemand_video_outlined : Icons.headphones_outlined,
              color: const Color(0xFF8B83FF),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.uiText('Nguồn đang học'),
                    style: const TextStyle(
                      color: Color(0xFFB8B2FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${isVideo ? context.uiText('Video') : context.uiText('Audio')}${timestamp == null ? '' : ' · ${timestamp.toString().split('.').first}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  if ((source.selectedText ?? '').trim().isNotEmpty)
                    Text(
                      source.selectedText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.uiText('Đóng ngữ cảnh'),
              onPressed: I4uWorkspaceHandoffInbox.instance.clear,
              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
