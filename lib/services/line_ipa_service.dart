// lib/services/line_ipa_service.dart
//
// Tạo dòng phiên âm IPA xếp chồng dưới dòng văn bản trong Read Mode.
//
// Pipeline tái dùng có sẵn: CMU Dict (EN, chính xác) → G2P rules (fallback).
// Service KHÔNG tự init — [TextProvider] ensure engine khi user bật chế độ,
// rồi clear cache để các dòng đã cache chất lượng thấp được dựng lại.
//
// READ-IPA-003 (P3): kết quả tính theo [IpaSegment] — mỗi token thô 1 segment
// (surface giữ nguyên để dựng interlinear word-chip; wordCore = lõi ASCII để
// tra IPA; phonemes để P4 tô màu). [buildLineIpa] là view phẳng join các
// segment — GIỮ NGUYÊN hợp đồng P1 (test/line_ipa_service_test.dart).
//
// Quy tắc eligibility của một dòng (chặn rác trên chữ Việt/Pali):
//   1. Tách dòng theo whitespace.
//   2. Mỗi token: bỏ ký tự không-phải-chữ ở 2 đầu (dấu câu, số bám ngoài).
//   3. Token rỗng sau khi bỏ (toàn dấu câu / số) → segment render-only,
//      không tính là từ, không tra IPA.
//   4. Token không khớp `^[A-Za-z][A-Za-z']*$` (chữ lạ, hyphen nội tại…)
//      → CẢ DÒNG trả null — không render dòng IPA.
//   5. Nếu dòng không có từ nào → null.
//
// Từ hợp lệ → list phoneme của resolver → join `''`
// (stress nằm trong phoneme, vd `wˈɝld` — KHÔNG dùng `ipaString`
// vì nó join bằng dấu chấm cho UI shadowing).
//
// Cache theo đúng content dòng (kể cả null), cap [_maxCache] entry —
// tràn thì clear-all (dòng cũ sẽ được tính lại khi cần).
import 'package:flutter/foundation.dart';

import '../features/shadowing/services/phoneme_analyzer.dart';

/// 1 token của dòng khi hiển thị IPA (READ-IPA-003).
///
/// [surface] = token thô (giữ dấu câu bám ngoài, vd `Hello,`).
/// [wordCore] = lõi sau khi strip ký tự biên — rỗng ⇔ token render-only
/// (dấu câu / số đứng riêng).
/// [ipa] = phiên âm joined `''` của wordCore — null nếu resolver trống.
/// [phonemes] = phoneme từng bước (P4 tô màu); override seam trả về 1 blob.
class IpaSegment {
  final String surface;
  final String wordCore;
  final String? ipa;
  final List<String> phonemes;

  const IpaSegment({
    required this.surface,
    required this.wordCore,
    this.ipa,
    this.phonemes = const [],
  });

  bool get isWord => wordCore.isNotEmpty;
  bool get hasIpa => ipa != null && ipa!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IpaSegment &&
          other.surface == surface &&
          other.wordCore == wordCore &&
          other.ipa == ipa &&
          listEquals(other.phonemes, phonemes);

  @override
  int get hashCode =>
      Object.hash(surface, wordCore, ipa, Object.hashAll(phonemes));

  @override
  String toString() =>
      'IpaSegment($surface, core=$wordCore, ipa=$ipa)';
}

class LineIpaService {
  LineIpaService._();

  static final Map<String, List<IpaSegment>?> _cache = {};
  static const int _maxCache = 600;

  /// Seam test: thay pipeline PhonemeAnalyzer bằng fake
  /// (trả về IPA đã join `''`, hoặc null/rỗng nếu không có IPA).
  static String? Function(String word)? wordIpaOverride;

  /// Chỉ chữ Latin + apostrophe, bắt đầu bằng chữ cái.
  static final RegExp _asciiWord = RegExp(r"^[A-Za-z][A-Za-z']*$");

  /// Bỏ ký tự không phải chữ (letter Unicode) ở 2 đầu token.
  /// Giữ nguyên chữ có dấu để detect ≠ bỏ sót chữ Việt/Pali.
  static final RegExp _edgeNonLetter =
      RegExp(r"^[^\p{L}']+|[^\p{L}']+$", unicode: true);

  /// Segments cho dòng [content] — null nếu dòng không đủ điều kiện.
  /// Dùng cho interlinear (dòng active) + tô màu phoneme (P4).
  static List<IpaSegment>? buildLineIpaSegments(String content) {
    if (_cache.containsKey(content)) return _cache[content];
    final result = _computeSegments(content);
    if (_cache.length >= _maxCache) _cache.clear();
    _cache[content] = result;
    return result;
  }

  /// Dòng IPA phẳng (view P1) cho [content], null nếu không đủ điều kiện.
  static String? buildLineIpa(String content) =>
      flatIpa(buildLineIpaSegments(content));

  /// Join IPA của các segment bằng space — null nếu không có IPA nào
  /// (segment không có từ / mọi từ đều trống resolver).
  static String? flatIpa(List<IpaSegment>? segments) {
    if (segments == null) return null;
    final parts = <String>[];
    for (final s in segments) {
      if (s.ipa == null || s.ipa!.isEmpty) continue;
      parts.add(s.ipa!);
    }
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  /// Xóa toàn bộ cache — gọi sau khi CMU Dictionary finishes loading
  /// (entry cache trước đó có thể đã fallthrough sang G2P chất lượng thấp).
  static void clearCache() => _cache.clear();

  /// Số entry đang cache (cho test).
  static int get cacheSize => _cache.length;

  static List<IpaSegment>? _computeSegments(String content) {
    // Phase 1 — thu thập token + eligibility CẢ DÒNG
    // (resolver chỉ được gọi sau khi mọi token đạt điều kiện — P1 contract).
    final raws = <String>[];
    final cores = <String>[];
    var hasWord = false;
    for (final raw in content.split(RegExp(r'\s+'))) {
      if (raw.isEmpty) continue;
      final core = raw.replaceAll(_edgeNonLetter, '');
      if (core.isEmpty) {
        // token toàn dấu câu / số → render-only, không tra IPA.
        raws.add(raw);
        cores.add('');
        continue;
      }
      if (!_asciiWord.hasMatch(core)) return null; // chữ lạ → null cả dòng
      raws.add(raw);
      cores.add(core);
      hasWord = true;
    }
    if (!hasWord) return null;

    // Phase 2 — resolve IPA từng từ (từ không có phoneme → ipa null,
    // vẫn giữ segment để dựng interlinear; view phẳng sẽ bỏ qua).
    final override = wordIpaOverride;
    final out = <IpaSegment>[];
    for (var i = 0; i < raws.length; i++) {
      final core = cores[i];
      if (core.isEmpty) {
        out.add(IpaSegment(surface: raws[i], wordCore: ''));
        continue;
      }
      String? ipa;
      var phonemes = const <String>[];
      if (override != null) {
        ipa = override(core);
        phonemes =
            (ipa == null || ipa.isEmpty) ? const <String>[] : [ipa];
      } else {
        final r = PhonemeAnalyzer.getPhonemes(core);
        phonemes = r.phonemes;
        ipa = phonemes.join('');
      }
      out.add(IpaSegment(
        surface: raws[i],
        wordCore: core,
        ipa: ipa,
        phonemes: phonemes,
      ));
    }
    return out;
  }
}
