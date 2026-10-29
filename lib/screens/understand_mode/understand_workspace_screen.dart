// lib/screens/understand_mode/understand_workspace_screen.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/understand_ai/understand_ai_context.dart';

import 'services/understand_ai_coach_launcher.dart';
import 'understand_tab_connector.dart';
import 'widgets/understand_workspace_header.dart';

class UnderstandWorkspaceScreen extends StatefulWidget {
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
  State<UnderstandWorkspaceScreen> createState() =>
      _UnderstandWorkspaceScreenState();
}

class _UnderstandWorkspaceScreenState extends State<UnderstandWorkspaceScreen> {
  static const _toolsExpandedKey = 'understand_tools_expanded_v1';
  bool _toolsExpanded = true;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => _toolsExpanded = prefs.getBool(_toolsExpandedKey) ?? true);
    });
  }

  Future<void> _toggleTools() async {
    final next = !_toolsExpanded;
    setState(() => _toolsExpanded = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_toolsExpandedKey, next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        UnderstandWorkspaceHeader(
          expanded: _toolsExpanded,
          onToggleExpanded: _toggleTools,
          onOpenSpeakMode: widget.onOpenSpeakMode,
          onOpenYouGlish: widget.onOpenYouGlish,
          onOpenReview: widget.onOpenReview,
          onOpenQuickActions: widget.onOpenQuickActions,
          onOpenAiCoach: widget.onOpenAiCoach ?? () => openUnderstandAiCoach(context),
        ),
        Expanded(
          child: UnderstandTabConnector(
            initialMode: widget.initialMode,
            onModeChanged: widget.onModeChanged,
            showInternalModeTabs: widget.showInternalModeTabs,
          ),
        ),
      ],
    );
  }
}
