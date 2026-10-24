// lib/features/iconize/models/iconize_span.dart
//
// ICONIZE-001b — data classes của Iconize Engine (ADR-0013, blueprint Khối A,
// docs/iconize_visual_context_blueprint.md mục 3.1).
//
// Nguyên tắc #1: Iconize là tầng render ephemeral — các class này KHÔNG được
// serialize vào TranslationCache hay bất kỳ store nào; plainText luôn là
// nguồn sự thật.

/// Nguồn icon đã chọn cho một span (fallback 4 tầng — blueprint mục 3.6).
enum IconizeSource { userVocabImage, localTwemoji, cdnFallback, none }

/// Mật độ icon — 3 nấc ngân sách % từ được icon hóa (ADR-0013 quyết định #5).
enum IconizeDensity { low, medium, high }

/// Ngân sách % từ tối đa được thay icon theo từng nấc density.
const Map<IconizeDensity, int> maxIconPercentByDensity = {
  IconizeDensity.low: 18,
  IconizeDensity.medium: 32,
  IconizeDensity.high: 48,
};

/// Từ loại rút gọn của Iconize. THỨ TỰ TRÙNG mã u8 trong concreteness.bin
/// (0=NOUN 1=VERB 2=ADJ 3=OTHER — hợp đồng tool/iconize/README.md).
enum IconizePos { noun, verb, adj, other }

extension IconizePosLabel on IconizePos {
  /// Nhãn chuẩn hóa dùng trong khóa tra cứu `lemma|POS`.
  String get label {
    switch (this) {
      case IconizePos.noun:
        return 'NOUN';
      case IconizePos.verb:
        return 'VERB';
      case IconizePos.adj:
        return 'ADJ';
      case IconizePos.other:
        return 'OTHER';
    }
  }
}

/// Một đoạn [start, end) trong plainText đủ điều kiện hiển thị icon.
class IconizeSpan {
  final int start;
  final int end;

  /// Dạng xuất hiện trong văn bản, ví dụ "catches".
  final String surfaceForm;

  /// Lemma đã chuẩn hóa, ví dụ "catch".
  final String lemma;

  /// Nhãn POS chuẩn hóa ("NOUN"/"ADJ" trong v1).
  final String pos;

  /// Điểm concreteness của lemma (thang 1.0–5.0, Brysbaert).
  final double concreteness;

  /// Tham chiếu icon dạng `bundle:<tên-codepoint>`, ví dụ "bundle:1f408".
  /// Renderer (lane 001d) phân giải qua IconsBundle; null = không có icon.
  final String? iconAssetRef;

  final IconizeSource source;

  /// true nếu phân giải nghĩa chưa chắc chắn (v1 luôn false — lookup theo
  /// (lemma,POS) đã loại từ đa nghĩa từ tầng build; xem blueprint mục 3.4).
  final bool isAmbiguous;

  const IconizeSpan({
    required this.start,
    required this.end,
    required this.surfaceForm,
    required this.lemma,
    required this.pos,
    required this.concreteness,
    required this.iconAssetRef,
    required this.source,
    this.isAmbiguous = false,
  });

  @override
  String toString() =>
      'IconizeSpan($start-$end "$surfaceForm" → $lemma|$pos $iconAssetRef)';
}

/// Kết quả của một lần iconize — bất biến, plainText KHÔNG bị sửa.
class IconizeResult {
  /// Nguồn sự thật, trả lại nguyên văn input.
  final String plainText;

  /// Span rời rạc, đã sort theo [IconizeSpan.start].
  final List<IconizeSpan> spans;

  final IconizeDensity density;

  /// % từ thực tế được icon hóa (0–100, luôn ≤ ngân sách density).
  final int actualIconPercent;

  const IconizeResult({
    required this.plainText,
    required this.spans,
    required this.density,
    required this.actualIconPercent,
  });

  static IconizeResult empty(String plainText, IconizeDensity density) =>
      IconizeResult(
        plainText: plainText,
        spans: const [],
        density: density,
        actualIconPercent: 0,
      );
}
