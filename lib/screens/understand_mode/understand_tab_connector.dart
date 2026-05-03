import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/player_provider.dart';
import '../../providers/text_provider.dart';
import 'models/understand_line.dart';
import 'understand_mode_screen.dart';
import 'understand_provider.dart';

class UnderstandTabConnector extends StatelessWidget {
  const UnderstandTabConnector({super.key});

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

        return const UnderstandModeScreen();
      },
    );
  }
}
