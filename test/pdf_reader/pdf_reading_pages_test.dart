import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/features/pdf_reader/services/pdf_reading_pages.dart';
void main() {
  test('five pages with a blank page are read to the last sentence', () async {
    final spoken = <String>[];
    var page = 0;
    var blanks = 0;
    while (page < 5) {
      final next = await nextPdfReadingPage<String>(
        from: page, pageCount: 5,
        load: (i) async => i == 1 ? [] : ['page $i sentence 1', 'page $i sentence 2'],
        isCurrent: () => true, skipEmpty: true, onEmpty: () => blanks++,
      );
      if (next == null) break;
      spoken.addAll(next.cues);
      page = next.page + 1;
    }
    expect(blanks, 1);
    expect(spoken.length, 8);
    expect(spoken.last, 'page 4 sentence 2');
  });
  test('start on page three; cancellation during extraction prevents playback', () async {
    var current = true;
    final loaded = <int>[];
    final next = await nextPdfReadingPage<String>(
      from: 2, pageCount: 5,
      load: (i) async { loaded.add(i); current = false; return ['text']; },
      isCurrent: () => current, skipEmpty: true, onEmpty: () {},
    );
    expect(loaded, [2]);
    expect(next, isNull);
  });
  test('Text Mode global offset maps repeated text on page three, not page one', () async {
    const pages = ['Same text.', '', 'Same text.'];
    final result = await pdfTextModePosition(
      offset: pages.first.length + 2 + 5,
      pageCount: pages.length, load: (i) async => pages[i],
    );
    expect(result, (page: 2, offset: 5));
  });
  test('auto advance off stops on an empty current page', () async {
    var loads = 0;
    expect(await nextPdfReadingPage<String>(
      from: 0, pageCount: 5, load: (_) async { loads++; return []; },
      isCurrent: () => true, skipEmpty: false, onEmpty: () {},
    ), isNull);
    expect(loads, 1);
  });
}
