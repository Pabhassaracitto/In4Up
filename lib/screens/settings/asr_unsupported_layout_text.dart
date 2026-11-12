// lib/screens/settings/asr_unsupported_layout_text.dart
//
// PSRC-34 (audit 1.27.0) — import thư mục `parakeet-tdt-0.6b-v3-int8` gồm
// `encoder-model.int8.onnx`, `decoder_joint-model.int8.onnx`, `nemo128.onnx`,
// `vocab.txt` bị app từ chối. Owner hỏi: lỗi nhận diện hay định dạng chưa hỗ
// trợ?
//
// KẾT LUẬN (đã đối chiếu, chi tiết ở card PSRC-34 trong KANBAN): ĐỊNH DẠNG
// CHƯA HỖ TRỢ, không phải lỗi nhận diện.
//   • Đây là dạng đóng gói của onnx-asr cho model NVIDIA NeMo: `nemo128.onnx`
//     là đồ thị tính log-mel (128 băng), `decoder_joint-model` là decoder và
//     joiner GỘP trong một đồ thị, `vocab.txt` là bảng token, `config.json`
//     ghi `"model_type": "nemo-conformer-tdt"`.
//   • sherpa-onnx (bộ máy nhận diện của app, 1.13.6 — và cả bản mới nhất
//     2.0.1) chỉ có loader cho transducer NeMo gồm BA đồ thị riêng
//     (`offline-transducer-nemo-model.cc`: encoder / decoder / joiner) cộng
//     metadata do script export của sherpa ghi vào encoder; không có loader
//     nào cho đồ thị `decoder_joint` gộp.
//   • App nhận diện bộ này CHÍNH XÁC (`ZipformerRoleFiles.isNeMoExport`) và
//     dừng trước khi copy 670 MB — đó là hành vi đúng. Cái thiếu là lối ra cho
//     người dùng: thông báo cũ là một snackbar dài tự biến mất sau vài giây.
//
// File này chỉ chứa CHUỖI + QUYẾT ĐỊNH thuần (không widget) để test được:
// hộp thoại trong `stt_model_settings_screen.dart` dùng lại y nguyên.

/// Tiêu đề hộp thoại.
const String kAsrLayoutDialogTitle = 'Bộ model này chưa dùng được trong app';

/// Bộ này LÀ gì.
const String kAsrLayoutWhatItIs =
    'Đây là bản export NVIDIA NeMo (kiểu onnx-asr): decoder và joiner gộp '
    'chung trong một file, phần tính đặc trưng âm thanh nằm ở một file riêng.';

/// Vì sao app không dùng được — và rằng import lại chính bộ này không giúp gì.
///
/// KHÔNG viết "file của bạn không hỏng": ở bước này app dừng ngay khi nhận ra
/// layout, chưa hề kiểm tra tính toàn vẹn của file ⇒ chỉ nói điều đã biết
/// (đã nhận ra đúng loại model; lý do từ chối là dạng đóng gói).
const String kAsrLayoutWhyNot =
    'Bộ máy nhận diện của app (sherpa-onnx) chỉ nạp được bộ có encoder, '
    'decoder, joiner tách riêng kèm tokens.txt. App đã nhận ra đúng loại '
    'model — chỉ là dạng đóng gói này chưa được hỗ trợ, nên import lại chính '
    'bộ này cũng cho kết quả như cũ.';

/// Dòng dẫn trước danh sách tên file app đã nhận ra.
const String kAsrLayoutFilesHeader = 'File đã nhận ra:';

/// Khi bộ Parakeet tương thích đã có sẵn trên máy.
const String kAsrLayoutAlreadyInstalled =
    'Bộ Parakeet tương thích đã được cài trên máy — bạn không cần import bộ '
    'này nữa.';

/// Khi bộ Parakeet tương thích đang được tải.
const String kAsrLayoutDownloading =
    'Bộ Parakeet tương thích đang được tải về.';

/// Nhãn nút tải bộ app dùng được.
const String kAsrLayoutDownloadButton = 'Tải bộ tương thích';

/// Mẫu câu mời tải trong bảng dịch (`{value0}` = dung lượng MB).
const String kAsrLayoutDownloadOfferTemplate =
    'App có sẵn bộ Parakeet tương thích để tải (khoảng {value0}MB).';

/// Câu mời tải với dung lượng thật — khớp [kAsrLayoutDownloadOfferTemplate].
String asrLayoutDownloadOffer(int approxSizeMB) =>
    'App có sẵn bộ Parakeet tương thích để tải (khoảng ${approxSizeMB}MB).';

/// Bước kế tiếp mà hộp thoại đưa cho người dùng.
enum AsrLayoutNextStep {
  /// Mời tải bộ Parakeet tương thích (có nút).
  offerDownload,

  /// Bộ tương thích đã cài — không cần làm gì.
  alreadyInstalled,

  /// Bộ tương thích đang tải — không mời tải lần nữa.
  downloading,

  /// Bản build không kèm profile Parakeet — chỉ giải thích.
  explainOnly,
}

/// Chọn bước kế tiếp. Thứ tự ưu tiên: đã cài → đang tải → mời tải.
AsrLayoutNextStep asrLayoutNextStep({
  required bool hasParakeetProfile,
  required bool installed,
  required bool downloading,
}) {
  if (!hasParakeetProfile) return AsrLayoutNextStep.explainOnly;
  if (installed) return AsrLayoutNextStep.alreadyInstalled;
  if (downloading) return AsrLayoutNextStep.downloading;
  return AsrLayoutNextStep.offerDownload;
}
