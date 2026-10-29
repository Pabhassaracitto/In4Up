import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/services/db_service.dart';
import 'package:in4up/models/tipitaka_source_anchor.dart';
import 'package:in4up/models/vocab_context.dart';
import 'package:in4up/models/vocabulary_type.dart';
import 'package:in4up/providers/vocabulary_provider.dart';

class TipitakaWorklistSaveResult {
  final String selectedText;
  final String wordId;
  final bool wasExisting;

  const TipitakaWorklistSaveResult({
    required this.selectedText,
    required this.wordId,
    required this.wasExisting,
  });
}

class TipitakaStudyCapture {
  final TipitakaSourceAnchor anchor;
  final TipitakaContextSnapshot snapshot;
  final String sourceLabel;

  const TipitakaStudyCapture({
    required this.anchor,
    required this.snapshot,
    required this.sourceLabel,
  });
}

/// Adapter between the Tipiṭaka reader and the existing vocabulary store.
///
/// It intentionally calls [VocabularyProvider.addWithAutoClassify] so a word
/// already saved from Read/PDF/Web is enriched with another context instead
/// of duplicated.
class TipitakaWorklistService {
  const TipitakaWorklistService();

  Future<TipitakaStudyCapture> capture({
    required TipitakaBook book,
    required TipitakaSegment segment,
    required String selectedText,
    required int startOffset,
    required int endOffset,
    String translationLanguage = 'vi',
    String translationVersion = '',
    String contextBefore = '',
    String contextAfter = '',
  }) async {
    final selected = selectedText.trim();
    if (selected.isEmpty) {
      throw ArgumentError.value(selectedText, 'selectedText', 'cannot be empty');
    }

    final sourceIdentity = await TipitakaDb.sourceIdentity();
    final index = book.catalogIndex;
    final anchor = TipitakaSourceAnchor(
      sourceDatabaseId: sourceIdentity,
      bookId: book.id,
      bookCode: index.normalizedCode,
      segmentId: segment.id,
      reference: segment.reference,
      paragraphNo: segment.paragraphNo,
      startOffset: startOffset,
      endOffset: endOffset,
      selectedText: selected,
      sourceTable: segment.sourceTable.trim().isEmpty
          ? index.sourceTable
          : segment.sourceTable,
      sourceRowKey: _sourceRowKey(segment),
    );
    final translatedText = segment.translationFor(translationLanguage).trim();
    final snapshot = TipitakaContextSnapshot(
      paliText: segment.paliText,
      translationText: translatedText.isNotEmpty
          ? translatedText
          : segment.firstTranslation?.value ?? '',
      translationLanguage: translationLanguage,
      contextBefore: contextBefore,
      contextAfter: contextAfter,
      translationVersion: translationVersion,
      paragraphNo: segment.paragraphNo,
      capturedAt: DateTime.now(),
    );
    return TipitakaStudyCapture(
      anchor: anchor,
      snapshot: snapshot,
      sourceLabel: '${book.displayTitle(translationLanguage)} · '
          '${segment.reference}',
    );
  }

  Future<TipitakaWorklistSaveResult> saveSelection({
    required VocabularyProvider vocabulary,
    required TipitakaBook book,
    required TipitakaSegment segment,
    required String selectedText,
    required int startOffset,
    required int endOffset,
    String translationLanguage = 'vi',
    String translationVersion = '',
    String contextBefore = '',
    String contextAfter = '',
    VocabularyType? forceType,
  }) async {
    final selected = selectedText.trim();
    if (selected.isEmpty) {
      throw ArgumentError.value(selectedText, 'selectedText', 'cannot be empty');
    }

    final studyCapture = await this.capture(
      book: book,
      segment: segment,
      selectedText: selected,
      startOffset: startOffset,
      endOffset: endOffset,
      translationLanguage: translationLanguage,
      translationVersion: translationVersion,
      contextBefore: contextBefore,
      contextAfter: contextAfter,
    );
    final anchor = studyCapture.anchor;
    final snapshot = studyCapture.snapshot;
    final hasPali = segment.paliText.trim().isNotEmpty;
    final context = VocabContext(
      id: 'tipitaka:${anchor.stableKey}',
      sourceType: 'tipitaka',
      sourceName: studyCapture.sourceLabel,
      pageOrPosition: segment.paragraphNo == null
          ? segment.reference
          : 'paragraph ${segment.paragraphNo}',
      sourceRef: anchor.stableKey,
      sourceRefType: 'tipitaka',
      surroundingText:
          hasPali ? segment.paliText : snapshot.translationText,
      encounteredAt: snapshot.capturedAt,
      anchorText: selected,
      textStartOffset: startOffset,
      textEndOffset: endOffset,
    );

    await VocabularyProvider.ensureBoxOpen();
    final existing = vocabulary.findByWord(selected);
    final entry = vocabulary.addWithAutoClassify(
      text: selected,
      context: context,
      forceType: forceType ?? _typeFor(selected),
      language: hasPali ? 'pi' : translationLanguage,
    );
    vocabulary.addTipitakaContextToWord(entry.id, anchor, snapshot);
    return TipitakaWorklistSaveResult(
      selectedText: selected,
      wordId: entry.id,
      wasExisting: existing != null,
    );
  }

  VocabularyType _typeFor(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.length == 1) return VocabularyType.word;
    if (RegExp(r'[.!?。！？]').hasMatch(value)) {
      return VocabularyType.sentence;
    }
    return VocabularyType.phrase;
  }

  String _sourceRowKey(TipitakaSegment segment) {
    // The normalized DB currently stores source_row_key separately from the
    // UI model. Reference is still a useful fallback for legacy rows.
    return segment.sourceRowKey.trim().isEmpty
        ? segment.reference.trim()
        : segment.sourceRowKey.trim();
  }
}
