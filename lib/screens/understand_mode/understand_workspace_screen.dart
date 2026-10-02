// lib/screens/understand_mode/understand_workspace_screen.dart

import 'package:flutter/material.dart';

import '../../widgets/auto_hide_banner.dart';
import 'services/understand_ai_coach_launcher.dart';
import 'understand_tab_connector.dart';
import 'widgets/understand_workspace_header.dart';

class UnderstandWorkspaceScreen extends StatelessWidget {
  final VoidCallback onOpenSpeakMode;
  final VoidCallback onOpenYouGlish;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenQuickActions;

  /// Optional để không phá caller hiện tại (main_shell không cần đổi):
  /// mặc định mở sheet "Trợ lý hiểu bài" từ state của tab Hiểu.
  final VoidCallback? onOpenAiCoach;

  const UnderstandWorkspaceScreen({
    super.key,
    required this.onOpenSpeakMode,
    required this.onOpenYouGlish,
    required this.onOpenReview,
    required this.onOpenQuickActions,
    this.onOpenAiCoach,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
        const Expanded(
          child: UnderstandTabConnector(),
        ),
      ],
    );
  }
}
