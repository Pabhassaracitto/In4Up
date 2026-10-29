// lib/features/translation/mixed_language_segmenter.dart
//
// XLAT-MIX-001 — tách một đoạn/dòng hỗn hợp ngôn ngữ thành từng mẩu câu rồi
// nhận diện ngôn ngữ CHO TỪNG MẨU.
//
// Vì sao cần (audit 0.10.3 mục 1.h — "văn bản Việt + Anh lẫn lộn không được
// dịch sang tiếng Việt"):
//   • `detectedSourceLanguage` gộp 24 dòng đầu thành MỘT mẫu ⇒ tài liệu lẫn
//     lộn luôn ra VI (tiếng Việt có dấu thắng điểm).
//   • Nguồn = đích ⇒ `translateAll` dừng ngay với "… đã là ngôn ngữ đích",
//     `translateLine` báo "Ngôn ngữ nguồn và ngôn ngữ đích đang giống nhau",
//     và `TranslationService` trả nguyên văn (engine `same-language`).
//   ⇒ Người dùng thấy "bấm Dịch mà không có gì xảy ra".
//
// Thiết kế an toàn: chỉ coi một mẩu là NGOẠI NGỮ khi cả hai cách nhận diện
// (fallback = ngôn ngữ đích, và fallback = tiếng Anh) đều không ra ngôn ngữ
// đích. Mẩu tiếng Việt viết không dấu (hay thuật ngữ trần) sẽ được giữ
// nguyên thay vì bị dịch bậy — thà bỏ sót còn hơn làm hỏng chữ của người
// dùng.
//
// File thuần Dart, không phụ thuộc Flutter ⇒ unit-test chạy nhanh.

import '../../core/language/app_language.dart';
import '../tts/language_detector.dart';

/// Một mẩu văn bản liền mạch cùng ngôn ngữ.
class LanguageSegment {
  const LanguageSegment({
    required this.text,
    required this.core,
    required this.language,
    required this.isForeign,
  });

  /// Nguyên văn, giữ nguyên khoảng trắng/dấu câu ở hai đầu để ghép lại
  /// không sai một ký tự nào.
  final String text;

  /// Phần chữ đã trim (dùng để gọi engine dịch).
  final String core;

  /// Ngôn ngữ nhận diện được cho mẩu này.
  final AppLanguage language;

  /// true = khác ngôn ngữ đích và đủ dài để đáng dịch.
  final bool isForeign;

  @override
  String toString() =>
      'LanguageSegment(${language.translationCode}, foreign: $isForeign, '
      '"$core")';
}

/// Cắt theo câu: giữ lại dấu kết câu và khoảng trắng đi kèm.
final RegExp _sentenceChunk = RegExp(r'[^.!?…\n]*[.!?…\n]+|[^.!?…\n]+');

final RegExp _letterRun = RegExp(r'[\p{L}]+', unicode: true);

/// Mẩu quá ngắn thì không đủ tín hiệu để nhận diện — gộp vào mẩu trước.
bool _tooShortToJudge(String core) {
  final words = _letterRun.allMatches(core).length;
  if (words == 0) return true;
  if (words >= 3) return false;
  final letters = core.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
  return letters.length < 8;
}

/// Chia [text] thành các mẩu cùng ngôn ngữ so với [target].
List<LanguageSegment> segmentByLanguage(
  String text, {
  required AppLanguage target,
  AppLanguage? fallback,
}) {
  if (text.trim().isEmpty) {
    return const <LanguageSegment>[];
  }

  final neutral = AppLanguageCatalog.english;
  final chunks = _sentenceChunk
      .allMatches(text)
      .map((match) => match.group(0) ?? '')
      .where((chunk) => chunk.isNotEmpty)
      .toList(growable: false);

  final segments = <LanguageSegment>[];
  for (final chunk in chunks) {
    final core = chunk.trim();

    // Mẩu không có chữ (chỉ dấu câu/khoảng trắng) hoặc quá ngắn → dính vào
    // mẩu liền trước để không cắt vụn câu.
    if (core.isEmpty || _tooShortToJudge(core)) {
      if (segments.isNotEmpty) {
        final previous = segments.removeLast();
        final mergedText = previous.text + chunk;
        segments.add(
          LanguageSegment(
            text: mergedText,
            core: mergedText.trim(),
            language: previous.language,
            isForeign: previous.isForeign,
          ),
        );
      } else {
        segments.add(
          LanguageSegment(
            text: chunk,
            core: core,
            language: fallback ?? target,
            isForeign: false,
          ),
        );
      }
      continue;
    }

    final withTargetFallback =
        LanguageDetector.detectLanguage(core, fallback: target);
    final withNeutralFallback =
        LanguageDetector.detectLanguage(core, fallback: neutral);
    final isForeign =
        withTargetFallback.translationCode != target.translationCode &&
            withNeutralFallback.translationCode != target.translationCode;
    final language = isForeign ? withNeutralFallback : target;

    // Gộp với mẩu trước nếu cùng "phe" — ít lần gọi engine hơn, câu dịch
    // cũng có ngữ cảnh dài hơn.
    if (segments.isNotEmpty &&
        segments.last.isForeign == isForeign &&
        segments.last.language.translationCode == language.translationCode) {
      final previous = segments.removeLast();
      final mergedText = previous.text + chunk;
      segments.add(
        LanguageSegment(
          text: mergedText,
          core: mergedText.trim(),
          language: language,
          isForeign: isForeign,
        ),
      );
      continue;
    }

    segments.add(
      LanguageSegment(
        text: chunk,
        core: core,
        language: language,
        isForeign: isForeign,
      ),
    );
  }

  return segments;
}

/// Có ít nhất một mẩu thuộc ngôn ngữ KHÁC đích hay không.
///
/// Đây là điều kiện để vẫn chạy dịch dù ngôn ngữ nguồn của cả tài liệu
/// trùng ngôn ngữ đích.
bool containsForeignSegment(
  String text, {
  required AppLanguage target,
  AppLanguage? fallback,
}) {
  final segments = segmentByLanguage(text, target: target, fallback: fallback);
  for (final segment in segments) {
    if (segment.isForeign) return true;
  }
  return false;
}
