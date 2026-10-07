import 'package:flutter_test/flutter_test.dart';
import 'package:in4up/core/reader/semantic_anchor_resolver.dart';
import 'package:in4up/models/i4u_shell_contracts.dart';

void main() {
  const resolver = I4uSemanticAnchorResolver();

  test('resolves matching block with full confidence', () {
    final result = resolver.resolve(
      anchor: const I4uSemanticReadingAnchor(
        sourceId: 'book',
        sourceRevision: 'r1',
        blockId: 'para_014',
        characterOffset: 128,
      ),
      currentSourceId: 'book',
      currentRevision: 'r1',
      currentBlockId: 'para_014',
      text: 'A' * 200,
    );
    expect(result?.offset, 128);
    expect(result?.isReliable, isTrue);
  });

  test('falls back to selected term after revision changes', () {
    final result = resolver.resolve(
      anchor: const I4uSemanticReadingAnchor(
        sourceId: 'book',
        sourceRevision: 'old',
        blockId: 'old-block',
        characterOffset: 2,
        selectedTerm: 'Tri giác',
      ),
      currentSourceId: 'book',
      currentRevision: 'new',
      currentBlockId: 'new-block',
      text: 'Một đoạn nói về tri giác trong văn bản.',
    );
    expect(result?.strategy, 'selected-term');
    expect(result?.isReliable, isTrue);
  });

  test('does not restore across another source or unknown text', () {
    const anchor = I4uSemanticReadingAnchor(
      sourceId: 'book',
      blockId: 'para',
      characterOffset: 1,
    );
    expect(resolver.resolve(anchor: anchor, currentSourceId: 'other', text: 'text'), isNull);
    expect(resolver.resolve(anchor: anchor, currentSourceId: 'book', text: 'text'), isNull);
  });
}
