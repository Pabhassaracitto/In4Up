import '../models/reader_appearance.dart';
import '../models/segment.dart';
import 'tipitaka_markup.dart';

/// A single language-homogeneous utterance sent to the shared TTS router.
class TipitakaSpeechChunk {
  final String text;
  final String languageCode;

  const TipitakaSpeechChunk({required this.text, required this.languageCode});
}

/// Prepares Pāli transliteration for Hindi voices, which generally handle the
/// syllabic rhythm better than an English voice. This is deliberately a
/// pronunciation-only transformation; stored canonical text is never changed.
String preparePaliForTts(String text) => text
    .replaceAll('Ā', 'Aa').replaceAll('ā', 'aa')
    .replaceAll('Ī', 'Ii').replaceAll('ī', 'ii')
    .replaceAll('Ū', 'Uu').replaceAll('ū', 'uu')
    .replaceAll('Ṭ', 'T').replaceAll('ṭ', 't')
    .replaceAll('Ḍ', 'D').replaceAll('ḍ', 'd')
    .replaceAll('Ṇ', 'N').replaceAll('ṇ', 'n')
    .replaceAll('Ñ', 'Ny').replaceAll('ñ', 'ny')
    .replaceAll('Ṅ', 'Ng').replaceAll('ṅ', 'ng')
    .replaceAll('Ḷ', 'L').replaceAll('ḷ', 'l')
    .replaceAll('Ṃ', 'M').replaceAll('ṃ', 'm')
    .replaceAll('Ṁ', 'M').replaceAll('ṁ', 'm')
    .replaceAll('Ḥ', 'H').replaceAll('ḥ', 'h');

/// Returns language-pinned chunks so bilingual playback never asks one voice
/// to read text in another language. Pāli is routed through Hindi (`hi`), and
/// each translation uses its own imported language code.
List<TipitakaSpeechChunk> tipitakaSpeechChunks({
  required TipitakaSegment segment,
  required TipitakaDisplayMode mode,
  required String translationLanguage,
  bool includeEnglish = false,
}) {
  final chunks = <TipitakaSpeechChunk>[];
  final pali = cleanTipitakaText(segment.canonicalPaliText).trim();
  if (mode != TipitakaDisplayMode.translationOnly && pali.isNotEmpty) {
    final prepared = preparePaliForTts(pali).trim();
    if (prepared.isNotEmpty) {
      chunks.add(TipitakaSpeechChunk(text: prepared, languageCode: 'hi'));
    }
  }

  if (mode != TipitakaDisplayMode.paliOnly) {
    var language = translationLanguage.trim().toLowerCase().replaceAll('_', '-');
    var translation = cleanTipitakaText(segment.translationFor(language)).trim();
    if (translation.isEmpty) {
      final fallback = segment.firstTranslation;
      if (fallback != null) {
        language = fallback.key.toLowerCase().replaceAll('_', '-');
        translation = cleanTipitakaText(fallback.value).trim();
      }
    }
    if (translation.isNotEmpty) {
      chunks.add(TipitakaSpeechChunk(text: translation, languageCode: language));
    }
    if (includeEnglish && language != 'en') {
      final english = cleanTipitakaText(segment.translationFor('en')).trim();
      if (english.isNotEmpty) {
        chunks.add(TipitakaSpeechChunk(text: english, languageCode: 'en'));
      }
    }
  }
  return List.unmodifiable(chunks);
}
