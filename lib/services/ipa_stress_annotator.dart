// lib/services/ipa_stress_annotator.dart
//
// Đánh dấu "từ/cụm được nhấn trong câu" — P3 (READ-IPA-006, mục 4).
//
// Nguồn sự thật phonetic hiện có: dấu nhấn TỪ `ˈ` trong phoneme CMU —
// KHÔNG phải nhịp ngắt câu (không hứa karaoke cấp câu). Vì dữ liệu gốc là
// phiên âm nghĩa (dictionary form), KHÔNG phải transcrip phát âm ngữ cảnh
// (weak/strong form, linking, sentence stress), mọi suy diễn ở đây đều là
// XẤP XỈ thân thiện, KHÔNG hứa chính xác ngữ âm.
//
// Thiết kế "thông minh không bị lẫn lộn":
//   1. Trọng âm chính (`ˈ`) ngay trên đúng âm tiết được nhấn → không dây dưa
//      với trọng âm phụ (`ˌ`) hay màu loại âm khác.
//   2. Chỉ đánh dấu từ có nội dung (noun/verb/adjective/adverb) — bỏ qua
//      function word (and/the/in/to, auxiliary, pronoun) vốn hiếm khi mang
//      sentence stress → tránh "lẫn lộn" giữa nhấn ngữ pháp và nhấn ngữ nghĩa.
//   3. Danh sách dừng loại trừ các trường hợp dễ gây hiểu nhầm
//      (can/to/that/for… có bản nhấn trong từ điển nhưng trong câu thường nhược âm).
//
// KHÔNG đổi phân loại màu hiện có (IpaStyling) — lớp này CHỈ trả index.

import 'line_ipa_service.dart';

/// Âm tiết được nhấn chính trong 1 segment (offset là vị trí trong ipa nối).
class IpaStressSyllable {
  final int start;
  final int end;

  const IpaStressSyllable({required this.start, required this.end});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IpaStressSyllable &&
          other.start == start &&
          other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Kết quả đánh dấu nhấn cho 1 dòng (P3).
class IpaLineStress {
  /// index segment (word) → vị trí âm tiết nhấn chính (trong ipa của segment).
  final Map<int, IpaStressSyllable> primaryPerWord;

  IpaLineStress({Map<int, IpaStressSyllable>? primaryPerWord})
      : primaryPerWord = primaryPerWord ?? const {};

  bool get isEmpty => primaryPerWord.isEmpty;
}

class IpaStressAnnotator {
  IpaStressAnnotator._();

  /// Word bị loại trừ khi xét "nhấn ngữ nghĩa" — weak-form / function word
  /// mang trọng âm trong từ điển nhưng thường không nhấn trong câu.
  static const Set<String> stressExclusions = {
    'can', 'to', 'that', 'for', 'as', 'than', 'will', 'would',
    'shall', 'should', 'must', 'been', 'are', 'was', 'were', 'is',
    'am', 'do', 'does', 'did', 'has', 'have', 'had', 'not', 'of',
    'a', 'an', 'the', 'his', 'her', 'them', 'him', 'us', 'we', 'you',
    'they', 'it', 'i', 'me', 'my', 'our', 'your', 'their', 'and',
    'but', 'or', 'so', 'if', 'when', 'while', 'because', 'into',
  };

  /// Đánh dấu trọng âm cho segments của 1 dòng.
  static IpaLineStress annotate(List<IpaSegment> segments) {
    final result = <int, IpaStressSyllable>{};
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      if (!seg.isWord || !seg.hasIpa) continue;

      final core = seg.wordCore;
      if (stressExclusions.contains(core.toLowerCase())) continue;

      final stressed = _findPrimary(seg);
      if (stressed == null) continue;
      result[i] = stressed;
    }
    return IpaLineStress(primaryPerWord: result);
  }

  /// Tìm âm tiết mang trọng âm chính `ˈ` trong ipa của 1 segment.
  ///
  /// Nếu phoneme của segment là 1 blob (override seam / dữ liệu cũ), scan ipa
  /// thô: gặp `ˈ` → chạy đến khi gặp `ˌ`, space, hoặc hết ký tự IPA.
  static IpaStressSyllable? _findPrimary(IpaSegment seg) {
    final ipa = seg.ipa!;
    final phonemes = seg.phonemes;

    // Case A: phoneme thật từ CMU (P4 đã strip stress khi tô màu).
    if (phonemes.isNotEmpty && phonemes.length > 1) {
      for (var k = 0; k < phonemes.length; k++) {
        final body = phonemes[k];
        if (body.startsWith('ˌ')) continue; // trọng âm phụ → bỏ qua
        if (!body.startsWith('ˈ')) continue;

        // Đánh dấu CẢ âm tiết nhấn (gồm ký tự ˈ + thân nguyên âm) —
        // offset start = vị trí đầu phoneme (chính là ký tự ˈ).
        final start = _offsetSum(phonemes, k);
        final end = start + body.length;
        return IpaStressSyllable(start: start, end: end);
      }
      return null;
    }

    // Case B: blob (override seam / dữ liệu cũ).
    final primary = ipa.indexOf('ˈ');
    if (primary < 0) return null;
    var end = primary + 1;
    while (end < ipa.length && ipa[end] != ' ' && ipa[end] != 'ˌ' &&
        _isIpaBodyChar(ipa[end])) {
      end++;
    }
    // Ngay sau ˈ là ˌ/space/hết → không xác định được âm.
    if (end == primary + 1) return null;
    return IpaStressSyllable(start: primary, end: end);
  }

  static String _stripStress(String phoneme) =>
      phoneme.replaceAll(RegExp('[ˈˌ]'), '');

  static bool _isIpaBodyChar(String ch) {
    final c = ch.codeUnitAt(0);
    if (c >= 0x0250 && c <= 0x02AF) return true; // IPA Extensions block
    // Mở rộng cho IPA gốc nằm ngoài block trên (æ ɑ ɔ ɛ ɪ ʊ …).
    const extra = 'æɑɒɔəɛɪʊʌɝɜœɐɨʉθðʃʒŋː';
    return extra.contains(ch);
  }

  static int _offsetSum(List<String> phonemes, int index) {
    var start = 0;
    for (var i = 0; i < index; i++) {
      start += phonemes[i].length;
    }
    return start;
  }
}
