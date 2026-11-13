// lib/features/screen_translate/screen_translate_text_flow.dart
//
// PSRC-211 — "dòng" và "đoạn" của chữ OCR trên màn hình. THUẦN DART (chỉ phụ
// thuộc `ocr_block.dart`), test được trên host VM.
//
// Vì sao có file này — ba lỗ hổng cùng một gốc: pipeline cũ coi MỖI khối ML Kit
// là một đơn vị đo + dịch + vẽ, mà không hề nhìn vào DÒNG bên trong nó:
//
//  1. **Cỡ chữ đo theo cả khối.** Một đoạn văn 5 dòng cao 300px bị coi như MỘT
//     dòng cao 300px ⇒ `suggestedTextSizeSp` kẹp trần 28sp (chữ gốc chỉ ~14sp)
//     ⇒ bản dịch cần gấp ~4 lần diện tích ⇒ đẩy mọi khối bên dưới xuống ⇒ tràn
//     đáy ⇒ khối bị bỏ. Đúng triệu chứng "bỏ sót khối + sai vị trí". Cần
//     [countTextLines] để chia chiều cao cho số dòng.
//
//  2. **Xuống dòng cứng của OCR đi thẳng vào engine dịch và ra màn hình.** ML
//     Kit nối các dòng của khối bằng `\n`, tức là ngắt câu ở đúng chỗ MÀN HÌNH
//     hết bề ngang. Engine nhận câu bị chặt ngang (dịch kém hơn) và bản dịch
//     nào còn mang `\n` thì native (`StaticLayout`) xuống dòng THẬT ở đó, còn
//     bộ ước lượng của Dart lại coi `\n` là dấu cách ⇒ Dart cấp thiếu chỗ ⇒
//     native bỏ vẽ khối. Bản dịch thường dài hơn dòng gốc nên mỗi dòng cứng
//     còn tự gãy thêm một dòng mồ côi ⇒ khung cao hơn hẳn mức cần.
//     ⇒ [reflowOcrText] nối các dòng BỊ NGẮT MỀM lại thành câu trước khi dịch;
//     [normalizeOverlayText] dọn bản dịch trước khi xếp chỗ.
//
//  3. **Một đoạn văn bị ML Kit tách thành nhiều khối 1 dòng** (xảy ra khi giãn
//     dòng rộng). Mỗi dòng thành một bong bóng riêng, bản dịch nào cũng dài
//     hơn dòng của nó ⇒ đẩy dồn (10 dòng ⇒ dòng cuối lệch cả trăm pixel).
//     ⇒ [mergeWrappedBlocks] gộp các dòng CÙNG ĐOẠN thành một khối (một
//     request, một bong bóng, đúng chỗ). Tần suất trên máy thật CHƯA đo —
//     log `screen translate blocks: ocr=… paragraphs=…` của controller cho
//     biết mỗi lượt gộp được bao nhiêu.
//
// Nguyên tắc chung: THẬN TRỌNG. Gộp nhầm hai mục menu thành một câu tệ hơn
// nhiều so với không gộp (không gộp = đúng hành vi cũ). Vì vậy mọi phép gộp
// đều đòi bằng chứng ở CẢ chữ (dòng trên chưa hết câu, dòng dưới viết thường)
// LẪN hình học (sát nhau, cùng cỡ, cùng lề, dòng trên đã kín bề ngang).

import 'dart:math' as math;

import '../ocr/ocr_block.dart';

/// Dòng "bị ngắt mềm" phải dài ít nhất chừng này ký tự. Nhãn UI ngắn ("OK",
/// "Cài đặt", "Tên") không bao giờ là một dòng văn bị xuống dòng tự động.
const int kSoftWrapMinChars = 16;

/// …và có ít nhất chừng này từ.
const int kSoftWrapMinWords = 3;

/// Khe dọc tối đa giữa hai dòng cùng đoạn, tính theo chiều cao MỘT dòng.
/// Đoạn văn: khe ≈ 0,1–0,6 dòng. Hai hàng danh sách: thường ≥ 1 dòng.
const double kMergeMaxGapLines = 0.9;

/// Hai khối sát nhau còn được phép lấn vào nhau chừng này (bbox OCR chồng mép).
const double kMergeMaxOverlapLines = 0.35;

/// Chênh lệch chiều cao dòng tối đa (tỉ lệ) để coi là cùng cỡ chữ.
const double kMergeMaxLineHeightDelta = 0.25;

/// Lệch lề trái tối đa, tính theo chiều cao một dòng.
const double kMergeMaxLeftDeltaLines = 0.6;

/// Dòng trên phải rộng ít nhất chừng này so với dòng rộng hơn trong cặp —
/// dòng bị ngắt mềm thì đã chạy kín bề ngang của đoạn.
const double kMergeMinFullWidthRatio = 0.8;

/// Tách chuỗi OCR thành các dòng KHÔNG rỗng (đã trim).
List<String> splitTextLines(String text) {
  if (text.isEmpty) return const <String>[];
  final out = <String>[];
  for (final raw in text.replaceAll('\r', '\n').split('\n')) {
    final line = raw.trim();
    if (line.isNotEmpty) out.add(line);
  }
  return out;
}

/// Số dòng chữ của một khối OCR (≥ 1 khi có chữ, 0 khi rỗng).
int countTextLines(String text) => splitTextLines(text).length;

const String _sentenceEnders = '.!?:;…。！？：；';
const String _closers = '"\'”’»)]}›';
const String _openers = '"\'“‘«([{‹¿¡';

/// Ký hiệu đầu dòng của một MỤC danh sách — luôn là ngắt THẬT.
const String _bullets = '-–—•·*▪◦‣○●■□▶▸►→';

/// Dòng bắt đầu bằng gạch đầu dòng / số thứ tự ("1.", "2)", "a)") ⇒ mục mới.
final RegExp _numberedItem = RegExp(r'^(?:\d{1,3}|[A-Za-z])[.)]\s');

bool _startsListItem(String line) {
  if (line.isEmpty) return false;
  if (_bullets.contains(line[0])) return true;
  return _numberedItem.hasMatch(line);
}

/// Ký tự có nghĩa cuối cùng của dòng (bỏ qua ngoặc/nháy đóng).
String _lastMeaningful(String line) {
  var end = line.length;
  while (end > 0 && _closers.contains(line[end - 1])) {
    end--;
  }
  return end > 0 ? line[end - 1] : '';
}

/// Ký tự có nghĩa đầu tiên của dòng (bỏ qua ngoặc/nháy mở).
String _firstMeaningful(String line) {
  var start = 0;
  while (start < line.length &&
      (_openers.contains(line[start]) || line[start] == ' ')) {
    start++;
  }
  return start < line.length ? line[start] : '';
}

bool _isLowercaseLetter(String ch) {
  if (ch.isEmpty) return false;
  final lower = ch.toLowerCase();
  final upper = ch.toUpperCase();
  // Chữ có phân biệt hoa/thường và đang ở dạng thường.
  return lower != upper && ch == lower;
}

int _wordCount(String line) =>
    line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

/// Dòng [next] có phải phần NỐI TIẾP của câu đang dở ở [prev] không?
///
/// Đúng khi MỌI điều sau cùng đúng:
///  • [prev] đủ dài để là một dòng văn (≥ [kSoftWrapMinChars] ký tự,
///    ≥ [kSoftWrapMinWords] từ) — nhãn ngắn không bao giờ là ngắt mềm;
///  • [prev] CHƯA kết câu (không tận cùng `. ! ? : ; …`);
///  • [next] KHÔNG mở đầu một mục danh sách (gạch đầu dòng, "1.", "a)");
///  • có dấu hiệu nối: [next] bắt đầu bằng chữ THƯỜNG, hoặc [prev] tận cùng
///    bằng dấu phẩy / gạch nối.
///
/// Dòng dưới viết HOA mà dòng trên không có dấu nối ⇒ coi là mục riêng (menu,
/// tiêu đề, danh sách). Tiếng Đức / tiêu đề viết hoa từng từ vì thế không
/// được nối — chấp nhận: không nối = hành vi cũ, còn nối nhầm = sai nghĩa.
bool isSoftWrap(String prev, String next) {
  final a = prev.trim();
  final b = next.trim();
  if (a.isEmpty || b.isEmpty) return false;
  if (a.length < kSoftWrapMinChars) return false;
  if (_wordCount(a) < kSoftWrapMinWords) return false;
  final last = _lastMeaningful(a);
  if (last.isEmpty || _sentenceEnders.contains(last)) return false;
  // Dòng dưới mở đầu một mục danh sách ⇒ không bao giờ là phần nối tiếp.
  if (_startsListItem(b)) return false;
  if (last == ',' || last == '-' || last == '‐') return true;
  return _isLowercaseLetter(_firstMeaningful(b));
}

/// Nối hai dòng đã được xác nhận là ngắt mềm.
///
/// Dòng trên tận cùng bằng gạch nối dính chữ ("well-" / "known") ⇒ nối KHÔNG
/// thêm khoảng trắng và GIỮ gạch (từ ghép vẫn đúng; từ bị ngắt âm tiết thì
/// engine dịch vẫn hiểu được "exam-ple" tốt hơn "exam- ple").
String _joinSoftWrap(String prev, String next) {
  if (prev.length >= 2 &&
      (prev.endsWith('-') || prev.endsWith('‐')) &&
      prev[prev.length - 2] != ' ') {
    return '$prev$next';
  }
  return '$prev $next';
}

/// Trả chữ của khối OCR về dạng CÂU: nối các dòng bị ngắt mềm, giữ `\n` ở
/// những chỗ ngắt THẬT (mục danh sách, hết câu, tiêu đề).
///
/// Đây là chuỗi gửi cho engine dịch. Một dòng thì trả nguyên (đã trim).
String reflowOcrText(String text) {
  final lines = splitTextLines(text);
  if (lines.isEmpty) return '';
  final out = <String>[lines.first];
  for (var i = 1; i < lines.length; i++) {
    if (isSoftWrap(lines[i - 1], lines[i])) {
      out[out.length - 1] = _joinSoftWrap(out.last, lines[i]);
    } else {
      out.add(lines[i]);
    }
  }
  return out.join('\n');
}

/// Chuẩn hoá BẢN DỊCH trước khi xếp chỗ + vẽ.
///
/// Engine có thể trả về `\r\n`, dòng trống, khoảng trắng đầu/cuối dòng. Native
/// vẽ mỗi `\n` thành một lần xuống dòng thật ⇒ dòng trống = khoảng trống thừa
/// trong khung. Gộp khoảng trắng liền nhau, bỏ dòng rỗng, GIỮ các `\n` còn lại
/// (chúng tương ứng với ngắt thật của bản gốc — xem [reflowOcrText]).
String normalizeOverlayText(String translation) {
  final lines = <String>[];
  for (final raw in translation.replaceAll('\r', '\n').split('\n')) {
    final line = raw.replaceAll(RegExp(r'[ \t\u00A0]+'), ' ').trim();
    if (line.isNotEmpty) lines.add(line);
  }
  return lines.join('\n');
}

/// Chiều cao trung bình MỘT dòng của khối (pixel ảnh).
double _lineHeightOf(OcrBlock block) {
  final lines = math.max(1, countTextLines(block.text));
  return block.rect.height / lines;
}

/// Hai khối [upper] (trên) và [lower] (dưới) có phải hai phần của CÙNG một
/// đoạn văn không? Xem các hằng `kMerge*` cho từng ngưỡng.
bool belongToSameParagraph(OcrBlock upper, OcrBlock lower) {
  final a = upper.rect;
  final b = lower.rect;
  if (!a.isValid || !b.isValid) return false;

  final hA = _lineHeightOf(upper);
  final hB = _lineHeightOf(lower);
  final line = math.min(hA, hB);
  if (line <= 0) return false;

  // (1) Cùng cỡ chữ.
  if ((hA - hB).abs() > kMergeMaxLineHeightDelta * math.max(hA, hB)) {
    return false;
  }
  // (2) Sát nhau theo chiều dọc: dưới nằm ngay sau trên.
  final gap = b.top - a.bottom;
  if (gap > kMergeMaxGapLines * line) return false;
  if (gap < -kMergeMaxOverlapLines * line) return false;
  if (b.top <= a.top) return false;
  // (3) Cùng lề trái (đoạn văn canh trái).
  if ((a.left - b.left).abs() > kMergeMaxLeftDeltaLines * line) return false;
  // (4) Dòng trên đã chạy kín bề ngang: nếu dòng dưới rộng hơn hẳn thì dòng
  //     trên là một mục ngắn đứng riêng, không phải dòng bị ngắt.
  final widest = math.max(a.width, b.width);
  if (a.width < kMergeMinFullWidthRatio * widest) return false;
  // (5) Bằng chứng ở chữ: câu đang dở.
  final upperLines = splitTextLines(upper.text);
  final lowerLines = splitTextLines(lower.text);
  if (upperLines.isEmpty || lowerLines.isEmpty) return false;
  return isSoftWrap(upperLines.last, lowerLines.first);
}

/// Gộp các khối OCR là những DÒNG của cùng một đoạn văn thành một khối.
///
/// Đầu vào theo thứ tự đọc (như `sortOcrBlocksForReading` trả về). Khối gộp
/// mang chữ nối bằng `\n` (để [countTextLines] vẫn đếm đúng số dòng — cỡ chữ
/// đo theo dòng) và khung là HỢP của các khung thành phần. Thứ tự đầu ra =
/// thứ tự của khối ĐẦU mỗi nhóm; khối không gộp được giữ nguyên.
///
/// Mỗi khối chỉ nối vào nhóm có khối cuối nằm NGAY trên nó — không nhảy cóc
/// qua khối khác, nên hai cột chữ cạnh nhau không bao giờ bị trộn.
List<OcrBlock> mergeWrappedBlocks(List<OcrBlock> blocks) {
  if (blocks.length < 2) return List<OcrBlock>.of(blocks);

  final groups = <_Group>[];
  for (final block in blocks) {
    _Group? target;
    for (final group in groups) {
      if (belongToSameParagraph(group.last, block)) {
        // Nhiều nhóm cùng khớp (hiếm): lấy nhóm có đáy gần khối này nhất.
        if (target == null ||
            (block.rect.top - group.last.rect.bottom).abs() <
                (block.rect.top - target.last.rect.bottom).abs()) {
          target = group;
        }
      }
    }
    if (target == null) {
      groups.add(_Group(block));
    } else {
      target.add(block);
    }
  }
  return <OcrBlock>[for (final group in groups) group.toBlock()];
}

class _Group {
  _Group(OcrBlock first) : members = <OcrBlock>[first];

  final List<OcrBlock> members;

  OcrBlock get last => members.last;

  void add(OcrBlock block) => members.add(block);

  OcrBlock toBlock() {
    if (members.length == 1) return members.single;
    var left = members.first.rect.left;
    var top = members.first.rect.top;
    var right = members.first.rect.right;
    var bottom = members.first.rect.bottom;
    for (final member in members.skip(1)) {
      left = math.min(left, member.rect.left);
      top = math.min(top, member.rect.top);
      right = math.max(right, member.rect.right);
      bottom = math.max(bottom, member.rect.bottom);
    }
    return OcrBlock(
      text: members.map((m) => m.text.trim()).join('\n'),
      rect: OcrBlockRect(left: left, top: top, right: right, bottom: bottom),
    );
  }
}
