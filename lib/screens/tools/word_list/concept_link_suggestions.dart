// PLAN-043 Pha A (ADR-0023) — gợi ý NỐI các WordEntry sẵn có vào cùng
// một Nút Khái niệm. File THUẦN (không import Flutter/provider): nhận vào
// các bản rút gọn của entry, trả ra cặp đề xuất kèm lý do + điểm tin cậy.
//
// Kỷ luật "không tự gộp" (luật AT2 của MVA): hàm này CHỈ đề xuất. Người
// dùng bấm xác nhận ở màn duyệt mới ghi `conceptId`; cặp đã bỏ qua được
// phía UI ghi nhớ bằng [ConceptLinkSuggestion.pairKey] để không hỏi lại.
//
// Ba tín hiệu (điểm cộng dồn):
//  * translationPair (+3): từ của A xuất hiện nguyên vẹn trong nghĩa của B
//    hoặc ngược lại (vd A="dog" (EN), B="chó" nghĩa "dog").
//  * sameImage (+2): hai entry dùng chung một ảnh minh hoạ.
//  * sharedGloss (+1): nghĩa (cụm đầu) của hai entry khác ngôn ngữ trùng
//    nhau sau chuẩn hoá (vd cả hai cùng gloss "con chó").

/// Bản rút gọn của một WordEntry cho bộ gợi ý (test thuần không cần model).
class ConceptCandidateWord {
  final String id;
  final String word;
  final String meaning;
  final String language;
  final String? imageUrl;
  final String? conceptId;

  const ConceptCandidateWord({
    required this.id,
    required this.word,
    required this.meaning,
    this.language = 'en',
    this.imageUrl,
    this.conceptId,
  });
}

/// Lý do gợi ý (UI dịch mã này thành nhãn người đọc).
enum ConceptLinkReason { translationPair, sameImage, sharedGloss }

class ConceptLinkSuggestion {
  /// Hai entry id, đã sắp xếp (id nhỏ trước) để pairKey ổn định.
  final List<String> wordIds;
  final Set<ConceptLinkReason> reasons;

  /// Điểm tin cậy: translationPair=3, sameImage=2, sharedGloss=1.
  final int score;

  const ConceptLinkSuggestion({
    required this.wordIds,
    required this.reasons,
    required this.score,
  });

  /// Khoá ổn định cho việc ghi nhớ "đã bỏ qua cặp này".
  String get pairKey => wordIds.join('|');

  @override
  String toString() =>
      'ConceptLinkSuggestion($pairKey, ${reasons.map((r) => r.name).join('+')}, $score)';
}

/// Chuẩn hoá để so sánh: chữ thường, bỏ dấu câu bao quanh, gộp khoảng trắng.
String normalizeGlossText(String raw) {
  var s = raw.trim().toLowerCase();
  s = s.replaceAll(RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s.trim();
}

/// Tách meaning tự do thành các cụm gloss ("con chó; chó nhà, cún" →
/// {"con chó", "chó nhà", "cún"}) — bỏ phần chú thích trong ngoặc đơn.
Set<String> glossSegments(String meaning) {
  final noParen = meaning.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  final out = <String>{};
  for (final part in noParen.split(RegExp(r'[;,\n/]'))) {
    final n = normalizeGlossText(part);
    if (n.isNotEmpty) out.add(n);
  }
  return out;
}

/// Cụm gloss đầu tiên (nghĩa chính) đã chuẩn hoá, rỗng nếu không có.
String primaryGloss(String meaning) {
  final segs = glossSegments(meaning);
  return segs.isEmpty ? '' : segs.first;
}

/// Sinh danh sách đề xuất nối, sắp xếp theo điểm giảm dần.
///
/// Bỏ qua: cặp cùng một entry; cặp đã cùng một khái niệm; cặp mà hai entry
/// thuộc HAI khái niệm khác nhau (đó là gợi ý GỘP khái niệm — ngoài Pha A).
/// [dismissedPairKeys] = các pairKey người dùng đã bỏ qua trước đó.
List<ConceptLinkSuggestion> buildConceptLinkSuggestions(
  List<ConceptCandidateWord> words, {
  Set<String> dismissedPairKeys = const <String>{},
}) {
  final suggestions = <ConceptLinkSuggestion>[];

  // Chuẩn hoá trước một lượt (O(n)) để vòng cặp O(n²) chỉ so sánh rẻ.
  final normWord = <String, String>{};
  final segs = <String, Set<String>>{};
  final primaries = <String, String>{};
  for (final w in words) {
    normWord[w.id] = normalizeGlossText(w.word);
    segs[w.id] = glossSegments(w.meaning);
    primaries[w.id] = primaryGloss(w.meaning);
  }

  for (var i = 0; i < words.length; i++) {
    for (var j = i + 1; j < words.length; j++) {
      final a = words[i];
      final b = words[j];
      if (a.id == b.id) continue;

      final aConcept = (a.conceptId ?? '').trim();
      final bConcept = (b.conceptId ?? '').trim();
      if (aConcept.isNotEmpty && bConcept.isNotEmpty) {
        // Đã cùng khái niệm thì không gợi ý nữa; hai khái niệm khác nhau
        // là chuyện gộp khái niệm (ngoài Pha A).
        continue;
      }

      final reasons = <ConceptLinkReason>{};
      var score = 0;

      final aWord = normWord[a.id]!;
      final bWord = normWord[b.id]!;
      if (aWord.isNotEmpty && segs[b.id]!.contains(aWord) ||
          bWord.isNotEmpty && segs[a.id]!.contains(bWord)) {
        // Tránh tự khớp tầm thường: hai entry cùng chữ cùng ngôn ngữ mà
        // nghĩa chứa chính chữ đó (vd mục từ điển tự tham chiếu).
        if (!(aWord == bWord && a.language == b.language)) {
          reasons.add(ConceptLinkReason.translationPair);
          score += 3;
        }
      }

      final aImg = (a.imageUrl ?? '').trim();
      final bImg = (b.imageUrl ?? '').trim();
      if (aImg.isNotEmpty && aImg == bImg) {
        reasons.add(ConceptLinkReason.sameImage);
        score += 2;
      }

      final aPrimary = primaries[a.id]!;
      final bPrimary = primaries[b.id]!;
      if (aPrimary.isNotEmpty &&
          aPrimary == bPrimary &&
          a.language != b.language) {
        reasons.add(ConceptLinkReason.sharedGloss);
        score += 1;
      }

      if (reasons.isEmpty) continue;

      final pair = [a.id, b.id]..sort();
      final suggestion = ConceptLinkSuggestion(
        wordIds: pair,
        reasons: reasons,
        score: score,
      );
      if (dismissedPairKeys.contains(suggestion.pairKey)) continue;
      suggestions.add(suggestion);
    }
  }

  suggestions.sort((x, y) {
    final byScore = y.score.compareTo(x.score);
    return byScore != 0 ? byScore : x.pairKey.compareTo(y.pairKey);
  });
  return suggestions;
}
