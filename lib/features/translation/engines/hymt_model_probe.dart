/// HYMT-003 (2026-11-06) — chẩn đoán file Hy-MT bằng SỰ THẬT trong GGUF.
///
/// Vì sao cần: triệu chứng owner báo là "Hy-MT không chịu dịch — không phản hồi
/// hoặc trả về rỗng" với CẢ bản 1.5/1.8/"2 bản 1 GB". Trước bản này app chỉ
/// kiểm tra magic + kích thước, nên 3 loại lỗi rất khác nhau bị gộp thành một
/// câu chung "Hy-MT native không load được":
///
///   1. File 2-bit của AngelSlim/tencent (`Hy-MT1.5-1.8B-2bit.gguf`, 601 MB)
///      dùng quant `q2_0` block 64 **cần kernel `q2_0c` từ llama.cpp PR #19357**
///      (chưa merge). llama.cpp trong app (pin `d7fa69b7`) hiểu `q2_0` theo
///      layout mainline ⇒ `llama_model_load_from_file()` trả NULL. File ĐÚNG
///      601 MB, magic ĐÚNG — mọi check cũ đều cho qua.
///   2. Model đúng (Q4_K_M/Q8_0…) nhưng prompt không có khung
///      `<｜hy_User｜>…<｜hy_Assistant｜>` của Tencent ⇒ model trả rỗng hoặc nhả
///      lại nguyên prompt (xem `hymt_prompts.dart` + native `frame_prompt`).
///   3. Sai kiến trúc (file Gemma/Qwen…) ⇒ load fail, thông báo phải khác.
///
/// Module này THUẦN (không Flutter/FFI) để test được bằng `flutter test`;
/// `ai_native_bindings.dart` chỉ lo phần đọc byte + gọi native.
library;

import 'package:in4up_ai/in4up_ai.dart' show GgufInfo;

/// Loại vấn đề của file model — UI/service phân nhánh theo enum, không theo
/// chuỗi (đổi câu chữ không làm hỏng logic).
enum HyMtModelIssueKind {
  /// Không mở/đọc được file (mất quyền, SAF, file bị xoá).
  unreadable,

  /// Thiếu magic GGUF — không phải file GGUF (hoặc file tải về là trang HTML).
  notGguf,

  /// Magic đúng nhưng nhỏ hơn nhiều so với bản phát hành ⇒ tải/import bị cắt.
  truncated,

  /// Kiến trúc không phải `hunyuan-*` ⇒ đây không phải model Hy-MT.
  wrongArchitecture,

  /// Kiến trúc hunyuan nhưng quant chưa có kernel trong llama.cpp đã pin.
  unsupportedQuant,

  /// Không đọc được header (bản native cũ, hoặc GGUF lạ) nhưng kích thước ổn.
  unknown,
}

/// Kết quả chẩn đoán: `kind == null` nghĩa là KHÔNG thấy vấn đề.
class HyMtModelDiagnosis {
  const HyMtModelDiagnosis({
    this.kind,
    this.message,
    this.info,
    this.sizeBytes,
  });

  final HyMtModelIssueKind? kind;

  /// Câu giải thích cụ thể cho người dùng (null khi file ổn).
  final String? message;

  /// Header đọc được từ native (null nếu bản native không hỗ trợ inspect).
  final GgufInfo? info;

  final int? sizeBytes;

  bool get isOk => kind == null;

  /// Quant bị chặn cứng bởi llama.cpp đã pin.
  bool get quantBlocked => kind == HyMtModelIssueKind.unsupportedQuant;

  @override
  String toString() =>
      'HyMtModelDiagnosis(${kind?.name ?? 'ok'}, ${info?.arch ?? '?'}/'
      '${info?.quant ?? '?'})';
}

class HyMtModelProbe {
  HyMtModelProbe._();

  /// Nhỏ hơn ngưỡng này = chắc chắn là file cắt của mọi bản Hy-MT 1.8B
  /// (bản nhỏ nhất từng phát hành là 1.25-bit ≈ 440 MB).
  static const int minPlausibleBytes = 400 * 1024 * 1024;

  /// Các quant llama.cpp đã pin (d7fa69b7) load được cho `hunyuan-dense`.
  /// `q2_0` KHÔNG nằm trong danh sách này: file 2-bit của AngelSlim được
  /// quantize bằng PR #19357 với block 512 + kernel SME2, không phải `q2_0`
  /// block 64 của mainline ⇒ sai layout ⇒ load NULL.
  static const Set<String> loadableQuants = <String>{
    'f32',
    'f16',
    'bf16',
    'q4_0',
    'q4_1',
    'q5_0',
    'q8_0',
    'q4_k',
    'q5_k',
    'q6_k',
  };

  /// Chẩn đoán từ thông tin header + kích thước file.
  ///
  /// [info] null = bản native không có `in4up_ai_inspect_gguf` (build cũ) →
  /// chỉ kiểm tra được kích thước, KHÔNG được kết luận sai là file hỏng.
  static HyMtModelDiagnosis diagnose({
    required int sizeBytes,
    GgufInfo? info,
  }) {
    if (sizeBytes < minPlausibleBytes) {
      final mb = (sizeBytes / 1048576).toStringAsFixed(0);
      return HyMtModelDiagnosis(
        kind: HyMtModelIssueKind.truncated,
        sizeBytes: sizeBytes,
        info: info,
        message: 'bị cắt ($mb MB; bản nhỏ nhất của Hy-MT 1.8B là ~440 MB)',
      );
    }
    if (info == null) {
      // Build cũ (hoặc GGUF lạ): KHÔNG đủ dữ kiện để kết luận hỏng — trả "ok"
      // để engine vẫn thử load. Chặn ở đây sẽ biến một bản native thiếu symbol
      // thành "mọi file đều hỏng".
      return HyMtModelDiagnosis(sizeBytes: sizeBytes);
    }
    if (info.arch.isNotEmpty && !info.isHunyuan) {
      return HyMtModelDiagnosis(
        kind: HyMtModelIssueKind.wrongArchitecture,
        sizeBytes: sizeBytes,
        info: info,
        message: 'không phải model Hy-MT '
            '(kiến trúc "${info.arch}", cần "hunyuan-dense")',
      );
    }
    if (!info.supported || !loadableQuants.contains(info.quant)) {
      return HyMtModelDiagnosis(
        kind: HyMtModelIssueKind.unsupportedQuant,
        sizeBytes: sizeBytes,
        info: info,
        message: 'dùng quant "${info.quant}" — llama.cpp trong app chưa có '
            'kernel này. File 2-bit/1.25-bit của AngelSlim cần bản llama.cpp '
            'ở PR #19357 (chưa merge) nên KHÔNG load được. Hãy dùng bản '
            'Q4_K_M (~1,1 GB) của tencent/HY-MT1.5-1.8B-GGUF.',
      );
    }
    return HyMtModelDiagnosis(sizeBytes: sizeBytes, info: info);
  }

  /// Có cần khung `<｜hy_User｜>` không. Hunyuan KHÔNG có `<|im_start|>` và
  /// không có BOS/EOS thường: thiếu khung ⇒ model coi prompt là văn bản thô,
  /// nhả rỗng hoặc nhả lại nguyên câu nguồn.
  static bool needsHunyuanFraming(GgufInfo? info) =>
      info == null || info.arch.isEmpty || info.isHunyuan;

  /// Dòng chẩn đoán ngắn để log (`adb logcat`/debugPrint) — KHÔNG hiện cho
  /// người dùng.
  static String describe(GgufInfo? info, int sizeBytes) {
    final mb = (sizeBytes / 1048576).toStringAsFixed(0);
    if (info == null) return '$mb MB · header chưa đọc được (native cũ?)';
    return '$mb MB · arch=${info.arch} · quant=${info.quant} · '
        'template=${info.hasChatTemplate ? 'có' : 'KHÔNG'} · '
        'tensors=${info.tensorCount}';
  }
}
