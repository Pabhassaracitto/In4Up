import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/reader/reader_note_contract.dart';
import 'package:in4up/core/reader/reader_remember_handoff.dart';
import 'package:in4up/core/reader/semantic_bookmark_resolver.dart';
import 'package:in4up/models/reader_contextual_panel_state.dart';

void main() {
  const selection = I4uReaderSelectionContext(
    text: 'tri giác', sourceId: 'book', blockId: 'para-14', characterOffset: 9,
  );

  test('Remember handoff preserves semantic source context', () {
    final handoff = I4uRememberHandoff.fromSelection(selection);
    expect(handoff.text, 'tri giác');
    expect(handoff.sourceId, 'book');
    expect(handoff.blockId, 'para-14');
  });

  test('bookmark resolves character offset to the correct line', () {
    final target = const I4uSemanticBookmarkResolver().resolve(
      selection: selection,
      lines: ['Một dòng', 'tri giác trong đoạn'],
    );
    expect(target?.lineIndex, 1);
  });

  test('note draft keeps source and selected text', () {
    const draft = I4uReaderNoteDraft(
      sourceId: 'book', text: 'tri giác', blockId: 'para-14', characterOffset: 9,
    );
    expect(draft.sourceId, 'book');
    expect(draft.text, 'tri giác');
  });
}
