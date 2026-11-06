// lib/features/cabin/services/cabin_finalization_dedup.dart
//
// AUDIT-1.21.0 #3 — "Cabin đang dịch mà nói thêm ⇒ 2 dòng trùng".
//
// Commit 57ad5a7 (CABIN-FLUSH-001 / KEEP-PARTIAL-001) đã sửa 2 lỗ MẤT câu,
// nhưng chống trùng vẫn chỉ bằng **một biến** `_lastFinalizedText`:
//
//   1. `_finalizeCurrentChunk` gán `_lastFinalizedText = trimmed` rồi `await`
//      bản dịch. Dịch LLM/offline có thể > 3s; cuối hàm có `Future.delayed(3s)`
//      XOÁ biến đó ⇒ cửa sổ chống trùng TẮT đúng lúc tác vụ dịch CỨN chưa
//      xong. Engine STT (nhất là speech_to_text / sherpa) phát lại `isFinal`
//      của câu cũ ⇒ `_trackFinalization` chạy lần 2 ⇒ 2 caption + 2 dòng LRC
//      + 2 entry journal giống hệt nhau.
//   2. Khi user nói thêm trong lúc đang dịch, partial MỚI tới; engine có thể
//      vừa gửi lại final CŨ vừa gửi partial MỚI ⇒ hai `_finalizeCurrentChunk`
//      bay song song. Một biến không phân biệt được "đang xử lý" với "đã
//      xử lý xong".
//
// Lớp này là hàm THUẦN (không Flutter/plugin, test host VM):
//   • `_inFlight` chặn finalization TRÙNG đang bay (kể cả khi dịch > 3s);
//   • `_recent` giữ vân tay câu đã chốt trong cửa sổ ngắn (mặc định 8s) để
//     callback lặp của engine không sinh dòng thứ hai;
//   • so sánh normalize (bỏ khoảng trắng/dấu câu/hoa thường) nên "Xin chào."
//     và "xin chào" bị coi là một, nhưng hai câu KHÁC nội dung không bao giờ
//     bị nuốt (đúng yêu cầu "tránh mất, thiếu" của owner).
//
// Không gộp 3 skill SM-2, không đụng `lib/ffi/` (quy tắc vàng).

/// Cửa sổ nhớ mặc định: đủ che một lượt dịch chậm + vài callback lặp của STT,
/// đủ ngắn để user cố ý nói lại cùng câu vẫn được ghi nhận.
const Duration kCabinDedupWindow = Duration(seconds: 8);

/// Kết quả của MỘT lần chốt: có thực sự tạo caption + ghi journal không.
///
/// AUDIT-1.21.0 #3 — recheck ngữ cảnh Cabin: `_finalizeCurrentChunk` có nhánh
/// `return` sớm (`_state == speaking`, text rỗng). Nếu `whenComplete` vẫn gọi
/// `complete()` thì câu được đưa vào cửa sổ nhớ 8s dù KHÔNG có caption nào
/// được tạo ⇒ khi engine replay `isFinal` ngay sau TTS, `shouldFinalize` trả
/// false ⇒ **MẤT CÂU** (đúng lỗi owner từng báo ở CABIN-FLUSH-001). Phải phân
/// biệt "đã chốt" với "bị bỏ qua".
class CabinFinalizationOutcome {
  bool createdCaption = false;
}

class CabinFinalizationDeduper {
  CabinFinalizationDeduper({
    this.window = kCabinDedupWindow,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration window;
  final DateTime Function() _now;

  final Map<String, DateTime> _recent = <String, DateTime>{};
  final Set<String> _inFlight = <String>{};

  /// Số câu tối đa giữ trong cửa sổ (phòng session dài / engine spam).
  static const int _maxRemembered = 32;

  bool get hasInFlight => _inFlight.isNotEmpty;

  static String normalize(String text) => text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]+', unicode: true), '')
      .trim();

  void _prune(DateTime now) {
    _recent.removeWhere((_, at) => now.difference(at) >= window);
    while (_recent.length > _maxRemembered) {
      final oldest = _recent.entries.reduce(
        (a, b) => a.value.isBefore(b.value) ? a : b,
      );
      _recent.remove(oldest.key);
    }
  }

  /// Có nên chốt câu [text] không? Gọi TRƯỚC khi tạo caption/timer.
  bool shouldFinalize(String text) {
    final key = normalize(text);
    if (key.isEmpty) return false;
    _prune(_now());
    if (_inFlight.contains(key)) return false;
    if (_recent.containsKey(key)) return false;
    return true;
  }

  /// Đánh dấu bắt đầu chốt (phải gọi NGAY SAU [shouldFinalize] = true, trước
  /// mọi `await`, nếu không có cửa sổ race cho 2 callback cùng lọt qua).
  void begin(String text) {
    final key = normalize(text);
    if (key.isEmpty) return;
    _inFlight.add(key);
  }

  /// Kết thúc chốt (kể cả khi dịch lỗi) ⇒ đưa vào cửa sổ nhớ.
  void complete(String text) {
    final key = normalize(text);
    if (key.isEmpty) return;
    _inFlight.remove(key);
    _recent[key] = _now();
  }

  /// Bỏ đánh dấu in-flight mà KHÔNG nhớ (vd câu bị huỷ do stop/pause).
  void cancel(String text) => _inFlight.remove(normalize(text));

  /// Đóng MỘT lần chốt ở `whenComplete`.
  ///
  /// [createdCaption] = false ⇒ chỉ `cancel()` (quên in-flight, KHÔNG đưa vào
  /// `_recent`), để final replay có cơ hội chốt lại thay vì bị nuốt 8s.
  /// = true ⇒ `complete()` như bình thường.
  void finish(String text, {required bool createdCaption}) {
    if (createdCaption) {
      complete(text);
    } else {
      cancel(text);
    }
  }

  /// Phiên mới / xoá lịch sử ⇒ quên hết.
  void reset() {
    _recent.clear();
    _inFlight.clear();
  }
}
