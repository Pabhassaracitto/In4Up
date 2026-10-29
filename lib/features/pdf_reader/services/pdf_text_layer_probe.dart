// lib/features/pdf_reader/services/pdf_text_layer_probe.dart
//
// I4U18-PDF-OCR-TTS-001 (Agent F · F2) — phân biệt PDF CÓ lớp chữ với PDF SCAN.
//
// Vì sao cần: trước đây reader không hề biết tài liệu thuộc loại nào. Trang
// scan và trang bìa (thường trống chữ) trông giống hệt nhau với code, nên:
//   • nút OCR hiện cả với PDF đã có lớp chữ → người dùng bấm, chờ spinner,
//     nhận lại đúng thứ đã có sẵn (đó là "OCR khi không cần");
//   • ngược lại, PDF scan thật thì chỉ báo "trang này là ảnh" mà không nói
//     cả tài liệu là scan.
//
// Cách phân loại: LẤY MẪU vài trang (không quét cả cuốn — 800 trang sẽ treo)
// rồi đếm ký tự chữ thật. Một trang trống chữ KHÔNG đủ kết luận: sách nào
// cũng có trang bìa/trang trắng. Chỉ khi MỌI trang mẫu đều trống mới gọi là
// scan; có ít nhất một trang đủ chữ là `textLayer`.
//
// Thuần Dart (không pdfrx, không Flutter) để test chạy trên host: caller
// truyền vào text đã trích của các trang mẫu.

/// Kết luận về lớp chữ của một tài liệu PDF.
enum PdfTextLayerKind {
  /// Chưa dò xong (vừa mở tài liệu) — UI không được kết luận gì.
  unknown,

  /// Có lớp chữ: extract-by-code chạy được, KHÔNG cần OCR.
  textLayer,

  /// Không có lớp chữ trong các trang mẫu → gần như chắc chắn là bản scan.
  scanned,
}

/// Số trang lấy mẫu tối đa cho một lần dò.
const int kPdfTextLayerProbePages = 5;

/// Số ký tự chữ tối thiểu để coi một trang là "có chữ thật".
///
/// 12: đủ để loại số trang, watermark ngắn và rác OCR sót, nhưng vẫn
/// nhận một dòng tiêu đề ngắn là chữ.
const int kPdfTextLayerMinChars = 12;

/// Chỉ số trang nên lấy mẫu cho tài liệu [pageCount] trang (0-based).
///
/// Rải đều: đầu — giữa — cuối. Trang đầu hay là bìa ảnh ngay cả trong sách có
/// lớp chữ, nên KHÔNG bao giờ chỉ dựa vào trang 0. [startPage] cho phép ưu
/// tiên trang người dùng đang đọc.
List<int> pdfTextLayerProbePages(
  int pageCount, {
  int startPage = 0,
  int maxSamples = kPdfTextLayerProbePages,
}) {
  if (pageCount <= 0 || maxSamples <= 0) return const <int>[];
  final count = maxSamples < pageCount ? maxSamples : pageCount;
  final sample = <int>{};
  final safeStart = startPage < 0
      ? 0
      : (startPage > pageCount - 1 ? pageCount - 1 : startPage);
  sample.add(safeStart);
  for (var i = 0; i < count && sample.length < count; i++) {
    final idx = count == 1
        ? 0
        : ((pageCount - 1) * i / (count - 1)).round();
    sample.add(idx);
  }
  final out = sample.toList()..sort();
  return out.length <= count ? out : out.sublist(0, count);
}

/// Ký tự "chữ thật" (chữ cái hoặc chữ số của MỌI hệ chữ viết).
final RegExp _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Đếm ký tự chữ/số thật (bỏ khoảng trắng và dấu câu).
int pdfTextLayerCharCount(String text) =>
    _letterOrDigit.allMatches(text).length;

/// Phân loại tài liệu từ text của các trang mẫu.
///
/// [sampleTexts] rỗng → [PdfTextLayerKind.unknown] (chưa dò được, đừng đoán).
PdfTextLayerKind classifyPdfTextLayer(
  List<String> sampleTexts, {
  int minChars = kPdfTextLayerMinChars,
}) {
  if (sampleTexts.isEmpty) return PdfTextLayerKind.unknown;
  for (final text in sampleTexts) {
    if (pdfTextLayerCharCount(text) >= minChars) {
      return PdfTextLayerKind.textLayer;
    }
  }
  return PdfTextLayerKind.scanned;
}

/// Có nên mời người dùng chạy OCR cho trang này không?
///
/// Quy tắc F2 — "không bật OCR khi không cần": chỉ mời khi CHÍNH trang đang
/// xem không có chữ. Sách lai (vài trang là ảnh chụp trong một cuốn có lớp
/// chữ) vẫn được mời; ngược lại, PDF có lớp chữ không bao giờ phải chờ một
/// vòng OCR để nhận lại thứ đã có sẵn.
bool shouldOfferOcrForPage({required bool pageHasText}) => !pageHasText;
