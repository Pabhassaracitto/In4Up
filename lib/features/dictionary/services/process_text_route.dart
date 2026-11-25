// ADR-0018 P2 — BỐC CHỮ TỪ `ACTION_PROCESS_TEXT` (thuần Dart, không plugin).
//
// Khi người dùng bôi chữ ở app khác (Chrome, đọc PDF…) và chọn "In4Up",
// Android gửi `Intent.ACTION_PROCESS_TEXT` kèm `EXTRA_PROCESS_TEXT`. Native
// CHỈ chuyển tiếp chuỗi thô sang kênh `in4up/process_text`; toàn bộ quyết
// định nằm ở đây — đúng khuôn ADR-0018: native làm thin, Dart làm logic.
//
// Smart split (owner chọn 2026-11-24 — "1 từ → từ điển, cụm/dòng → dịch"):
//   • Một từ (không có khoảng trắng, ≤ 64 ký tự) → mở `DictionaryScreen`
//     (cùng trần 64 rune với `DictDeepLink.maxWordLength` — từ thật sự dài
//     hơn 64 ký tự không phải từ để tra).
//   • Còn lại (cụm, câu, nhiều dòng, chuỗi quá dài) → dịch bằng
//     `TranslationService` và hiện bảng `ReadSelectionTranslateSheet`.
//
// Vì sao thuần Dart: dữ liệu đến từ Intent của hệ điều hành — dữ liệu lạ,
// phải kiểm tra được trên CI không cần thiết bị (test/
// dictionary/process_text_route_test.dart).

/// Hành động cho một chuỗi bôi chọn từ app khác.
enum ProcessTextAction {
  /// Mở màn Từ điển với chuỗi làm từ cần tra.
  dictionary,

  /// Dịch chuỗi và hiện bảng kết quả dịch.
  translate,
}

/// Kết quả bóc một chuỗi `EXTRA_PROCESS_TEXT`. Bất biến, không phụ thuộc
/// Flutter — test được trên host VM.
class ProcessTextRoute {
  final ProcessTextAction action;

  /// Chuỗi đã chuẩn hoá: đã trim, đã bỏ ký tự điều khiển.
  final String text;

  const ProcessTextRoute(this.action, this.text);

  @override
  String toString() => 'ProcessTextRoute($action, ${text.length} chars)';

  @override
  bool operator ==(Object other) =>
      other is ProcessTextRoute &&
      other.action == action &&
      other.text == text;

  @override
  int get hashCode => Object.hash(action, text);
}

/// Ký tự điều khiển KHÔNG phải khoảng trắng (NUL, ESC, DEL…) — loại bỏ vì
/// chúng không bao giờ là nội dung người dùng chọn thật. `\\n` `\\r` `\\t`
/// được GIỮ lại: chúng là khoảng trắng hợp lệ (chọn nhiều dòng ⇒ dịch).
final RegExp _controlChars = RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]');

/// Trần độ dài từ tra cứu — đồng nhất với `DictDeepLink.maxWordLength`.
const int kProcessTextMaxWordLength = 64;

/// Bóc một chuỗi `EXTRA_PROCESS_TEXT` thành [ProcessTextRoute].
///
/// Trả `null` khi không có gì xử lý được (chuỗi rỗng / toàn khoảng trắng) —
/// người gọi im lặng bỏ qua, KHÔNG mở màn nào cả.
///
/// Không ném exception trong mọi trường hợp — đầu vào là dữ liệu lạ từ
/// ứng dụng khác.
ProcessTextRoute? routeProcessText(String raw) {
  // Bỏ ký tự điều khiển nhưng GIỮ khoảng trắng (xem _controlChars).
  final cleaned = raw.replaceAll(_controlChars, '').trim();
  if (cleaned.isEmpty) return null;

  // Có khoảng trắng (cụm từ, câu, nhiều dòng) ⇒ dịch.
  if (RegExp(r'\s').hasMatch(cleaned)) {
    return ProcessTextRoute(ProcessTextAction.translate, cleaned);
  }

  // Một token duy nhất: ≤ 64 rune ⇒ tra từ điển; dài hơn thì không phải
  // từ để tra (URL/path/snippet dài) ⇒ đưa đi dịch thay vì tra vớ vẩn.
  if (cleaned.runes.length > kProcessTextMaxWordLength) {
    return ProcessTextRoute(ProcessTextAction.translate, cleaned);
  }
  return ProcessTextRoute(ProcessTextAction.dictionary, cleaned);
}
