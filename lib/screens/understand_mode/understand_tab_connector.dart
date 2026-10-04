import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/understand_ai/understand_ai_context.dart';
import '../../providers/player_provider.dart';
import '../../providers/text_provider.dart';
import 'models/understand_line.dart';
import 'understand_mode_screen.dart';
import 'understand_provider.dart';

class UnderstandTabConnector extends StatelessWidget {
  const UnderstandTabConnector({
    super.key,
    this.initialMode = UnderstandLearningMode.sync,
    this.onModeChanged,
    this.showInternalModeTabs = true,
  });

  final UnderstandLearningMode initialMode;
  final ValueChanged<UnderstandLearningMode>? onModeChanged;
  final bool showInternalModeTabs;

  @override
  Widget build(BuildContext context) {
    return Consumer3<PlayerProvider, TextProvider, UnderstandProvider>(
      builder: (context, player, text, understand, _) {
        if (text.hasLyrics && understand.understandLines.isEmpty) {
          final understandLines = text.lines
              .map((line) => UnderstandLine.fromTextItem(line))
              .toList();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            understand.setUnderstandLines(understandLines);
            player.setUnderstandProvider(understand);
          });
        }

        return UnderstandModeScreen(
          initialMode: initialMode,
          onModeChanged: onModeChanged,
          showModeTabs: showInternalModeTabs,
        );
      },
    );
  }
}
