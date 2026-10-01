import 'package:in4up/features/learn_by_heart/controllers/learn_by_heart_provider.dart';
import 'package:in4up/features/learn_by_heart/models/learn_by_heart_item.dart';
import 'package:in4up/features/learn_by_heart/models/recitation_category.dart';
import 'package:in4up/features/learn_by_heart/models/recitation_language.dart';
import 'package:in4up/features/tipitaka/models/book.dart';
import 'package:in4up/features/tipitaka/models/segment.dart';
import 'package:in4up/features/tipitaka/services/tipitaka_worklist_service.dart';

/// Creates a normal LearnByHeartItem from a Tipiṭaka paragraph. This keeps
/// FSRS, audio controls and chunking in the existing Learn by Heart module;
/// Tipiṭaka only supplies content and provenance.
class TipitakaLearnByHeartService {
  const TipitakaLearnByHeartService();

  Future<LearnByHeartItem> savePassage({
    required LearnByHeartProvider provider,
    required TipitakaBook book,
    required TipitakaSegment segment,
    required String bookName,
    String contextBefore = '',
    String contextAfter = '',
  }) async {
    final fallbackTranslation = segment.firstTranslation;
    final translationLanguage = segment.translationVi?.trim().isNotEmpty == true
        ? 'vi'
        : fallbackTranslation?.key ?? 'en';
    final selectedText = segment.paliText.trim().isNotEmpty
        ? segment.paliText
        : fallbackTranslation?.value ?? '';
    final capture = await const TipitakaWorklistService().capture(
      book: book,
      segment: segment,
      selectedText: selectedText,
      startOffset: 0,
      endOffset: selectedText.length,
      translationLanguage: translationLanguage,
      contextBefore: contextBefore,
      contextAfter: contextAfter,
    );

    final existing = provider.allItems.cast<LearnByHeartItem?>().firstWhere(
          (item) => item?.sourceAnchor?.stableKey == capture.anchor.stableKey,
          orElse: () => null,
        );
    final item = existing == null
        ? _newItem(book, segment, bookName, capture)
        : existing.copyWith(
            title: _title(book, segment, translationLanguage),
            subtitle: 'Tipiṭaka · $bookName',
            paliText: segment.paliText,
            vietnameseText: segment.translationVi ??
                segment.translationEn ??
                fallbackTranslation?.value ??
                '',
            targetLang: translationLanguage,
            sourceAnchor: capture.anchor,
            contextSnapshot: capture.snapshot,
          );

    await provider.saveItem(item);
    return item;
  }

  LearnByHeartItem _newItem(
    TipitakaBook book,
    TipitakaSegment segment,
    String bookName,
    TipitakaStudyCapture capture,
  ) {
    final now = DateTime.now();
    final hasPali = segment.paliText.trim().isNotEmpty;
    final translation = segment.firstTranslation?.value ?? '';
    return LearnByHeartItem(
      id: 'tipitaka-${capture.anchor.bookId}-${capture.anchor.segmentId}',
      title: _title(
        book,
        segment,
        capture.snapshot.translationLanguage,
      ),
      subtitle: 'Tipiṭaka · $bookName',
      category: RecitationCategory.sutta,
      paliText: segment.paliText,
      vietnameseText: segment.translationVi ??
          segment.translationEn ??
          translation,
      sourceLang: 'pi',
      targetLang: capture.snapshot.translationLanguage,
      // Keep the established Pāli memorization flow when Pāli exists. A
      // translation-only pack remains usable instead of creating an empty
      // source-side exercise.
      memorizeSide: hasPali ? MemorizeSide.source : MemorizeSide.target,
      ttsLanguage: hasPali ? 'pi' : capture.snapshot.translationLanguage,
      sourceAnchor: capture.anchor,
      contextSnapshot: capture.snapshot,
      createdAt: now,
    );
  }

  String _title(
    TipitakaBook book,
    TipitakaSegment segment,
    String languageCode,
  ) {
    final paragraph = segment.paragraphNo;
    return paragraph == null
        ? book.displayTitle(languageCode)
        : '${book.displayTitle(languageCode)} · § $paragraph';
  }
}
