import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/grammar/models/grammar_highlight_settings.dart';

void main() {
  final readScreen =
      File('lib/screens/read_mode/read_mode_screen.dart').readAsStringSync();
  final grammarSheet = File(
    'lib/screens/read_mode/sheets/read_selection_sheets.dart',
  ).readAsStringSync();
  final actionRunner = File(
    'lib/screens/read_mode/services/read_text_action_runner.dart',
  ).readAsStringSync();

  group('Read tab smart chrome', () {
    test('starts compact, can be recalled, and follows scroll direction', () {
      expect(readScreen, contains('bool _readerChromeVisible = false;'));
      expect(readScreen, contains("context.uiText('Công cụ đọc')"));
      expect(readScreen, contains('setState(() => _readerChromeVisible ='));
      expect(readScreen, contains('visible: _readerChromeVisible'));
      expect(readScreen, contains('diff > 12 && _readerChromeVisible'));
      expect(readScreen, contains('diff < -12 && !_readerChromeVisible'));
      expect(readScreen, contains('if (!isFocusMode && _readerChromeVisible)'));
    });

    test('Content Words legend defaults collapsed but remains expandable', () {
      expect(GrammarHighlightSettings.defaults().activePresetId, 'content-words');
      expect(GrammarHighlightSettings.defaults().legendCollapsed, isTrue);
      expect(readScreen, contains('Icons.expand_more_rounded'));
      expect(readScreen, contains('textProvider.setGrammarLegendCollapsed'));
    });

    test('selection grammar counts use the active category palette', () {
      expect(grammarSheet, contains('palette.styleFor(entry.key).color'));
      expect(actionRunner, contains('palette: tp.activeGrammarPalette'));
    });
  });
}
