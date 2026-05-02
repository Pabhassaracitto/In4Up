// lib/screens/understand_mode/understand_tab_connector.dart

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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UnderstandProvider()),
      ],
      child: Consumer3<PlayerProvider, TextProvider, UnderstandProvider>(
        builder: (context, player, text, understand, _) {
          // Sync understand lines when text changes
          if (text.hasLyrics && understand.understandLines.isEmpty) {
            final understandLines = text.lines
                .map((line) => UnderstandLine.fromTextItem(line))
                .toList();
            understand.setUnderstandLines(understandLines);

            // NEW: Pass UnderstandProvider to PlayerProvider
            // This needs to be done after the UnderstandProvider is created and ready.
            player.setUnderstandProvider(understand);
          }

          return const UnderstandModeScreen();
        },
      ),
    );
  }
}
