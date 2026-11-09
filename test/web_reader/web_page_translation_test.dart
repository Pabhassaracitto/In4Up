import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/web_reader/js/web_reader_js.dart';
import 'package:in4up/features/web_reader/services/web_page_translation.dart';

void main() {
  group('splitWebTextIntoUnits', () {
    test('normalizes whitespace and keeps paragraph boundaries', () {
      expect(
        splitWebTextIntoUnits('  First paragraph.  \n\n  Second   paragraph. '),
        <String>['First paragraph.', 'Second paragraph.'],
      );
    });

    test('splits long paragraphs at sentence and word boundaries', () {
      final units = splitWebTextIntoUnits(
        'One two. Three four. Five six.',
        maxUnitLength: 15,
      );

      expect(units, <String>['One two.', 'Three four.', 'Five six.']);
      expect(units.every((unit) => unit.length <= 15), isTrue);
    });

    test('splits a long sentence on whitespace without losing words', () {
      final units = splitWebTextIntoUnits(
        'alpha beta gamma delta epsilon',
        maxUnitLength: 11,
      );

      expect(units.join(' '), 'alpha beta gamma delta epsilon');
      expect(units.every((unit) => unit.length <= 11), isTrue);
    });

    test('returns no units for blank input and rejects an invalid limit', () {
      expect(splitWebTextIntoUnits(' \n  '), isEmpty);
      expect(
        () => splitWebTextIntoUnits('text', maxUnitLength: 0),
        throwsArgumentError,
      );
    });
  });

  group('Web Reader translation wiring', () {
    test('DOM extraction includes all rendered main-page text', () {
      final script = WebReaderJS.extractPageTextScript;

      expect(script, contains('getBoundingClientRect'));
      expect(script, contains('rect.width <= 0'));
      expect(script, isNot(contains('viewportHeight')));
      expect(script, isNot(contains('viewportWidth')));
      expect(script, contains(r'replace(/\s+/g'));
      expect(script, contains(r"visible.join('\n\n')"));
    });

    test('page, selection, and word actions reach translation sheets', () {
      final screen =
          File('lib/features/web_reader/web_reader_screen.dart').readAsStringSync();
      final toolbar = File(
        'lib/features/web_reader/widgets/web_reader_toolbar.dart',
      ).readAsStringSync();
      final wordSheet = File(
        'lib/features/web_reader/widgets/web_word_tap_sheet.dart',
      ).readAsStringSync();
      final translateSheet = File(
        'lib/features/web_reader/widgets/web_page_translate_sheet.dart',
      ).readAsStringSync();

      expect(screen, contains('WebPageTranslateSheet.show('));
      expect(screen, contains('ReadSelectionTranslateSheet.show('));
      expect(screen, contains('onTap: _translateSelection'));
      expect(toolbar, contains('onTap: widget.onTranslatePage'));
      expect(wordSheet, contains('ReadSelectionTranslateSheet.show('));
      expect(wordSheet, contains("titleText: 'Dịch từ'"));
      expect(wordSheet, contains("context.uiText('Dịch từ')"));
      expect(translateSheet, contains("'Dừng dịch'"));
      expect(translateSheet, contains('shouldStop:'));
    });
  });

  group('translateWebPageUnits', () {
    test('translates sequentially and reports partial failures', () async {
      final requested = <String>[];
      final updates = <WebTranslationUnit>[];
      final report = await translateWebPageUnits(
        units: <String>['first', 'second', 'third'],
        delayBetween: Duration.zero,
        translate: (text) async {
          requested.add(text);
          if (text == 'second') throw StateError('temporary failure');
          return 'translated $text';
        },
        onUnit: (_, unit) => updates.add(unit),
      );

      expect(requested, <String>['first', 'second', 'third']);
      expect(updates, hasLength(3));
      expect(updates[0].translation, 'translated first');
      expect(updates[1].translation, isNull);
      expect(updates[2].translation, 'translated third');
      expect(report.translatedCount, 2);
      expect(report.failedCount, 1);
      expect(report.stoppedEarly, isFalse);
    });

    test('stops between translation requests when requested', () async {
      var stop = false;
      final requested = <String>[];
      final report = await translateWebPageUnits(
        units: <String>['first', 'second', 'third'],
        delayBetween: Duration.zero,
        shouldStop: () => stop,
        translate: (text) async {
          requested.add(text);
          stop = true;
          return 'translated $text';
        },
      );

      expect(requested, <String>['first']);
      expect(report.translatedCount, 1);
      expect(report.stoppedEarly, isTrue);
    });

    test('stops after repeated engine failures', () async {
      final requested = <String>[];
      final report = await translateWebPageUnits(
        units: <String>['a', 'b', 'c', 'd', 'e'],
        delayBetween: Duration.zero,
        maxConsecutiveFailures: 2,
        translate: (text) async {
          requested.add(text);
          return null;
        },
      );

      expect(requested, <String>['a', 'b']);
      expect(report.failedCount, 2);
      expect(report.translatedCount, 0);
      expect(report.stoppedEarly, isTrue);
    });
  });
}
