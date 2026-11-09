// lib/services/offline_model_gate.dart
//
// AUDIT-1.21.0 #2 + #7 (CỤM model/offline) — chặn chọn / chạy model khi CHƯA
// có model thật sự trên máy. Logic THUẦN Dart nên test được không cần thiết bị.
//
// Bối cảnh: `SherpaModelManager._findAsrModelInDirSync()` hiện coi file
// `.onnx` > 1000 byte là "đã cài". Một bản import/tải DỞ (encoder 2KB, thiếu
// tokens, thiếu espeak-ng-data…) vẫn làm chip "Offline (sherpa)" / "Parakeet"
// sáng lên; user bấm «Tạo lời thoại» ⇒ sherpa-onnx dựng `OfflineRecognizer`
// trên file hỏng ⇒ SIGSEGV/SIGABRT ở C++ (Dart KHÔNG catch được ⇒ văng app).
//
// Gate này KHÔNG thay `detectEncoderKind()` / `isStreamingEncoderOnnx()` /
// `matchAsrProfile()` (quy tắc vàng #3). Nó chỉ là preflight ĐẦU VÀO, chạy
// trước mọi MethodChannel sang native.

/// Lý do model không dùng được.
enum OfflineModelIssue {
  none,

  /// Chưa import/tải model nào cho profile/ngôn ngữ này.
  notInstalled,

  /// Có file nhưng thiếu hoặc quá nhỏ (import dở / file rỗng / xoá một phần).
  incompleteFiles,

  /// Model streaming (`OnlineRecognizer`) bị đem vào đường file/LRC
  /// (`OfflineRecognizer`) — lỗi SIGABRT "Got N Expected 39".
  streamingOnly,

  /// Ngôn ngữ không có profile đã verify; không được map mò sang model khác.
  unsupportedLanguage,
}

class OfflineModelVerdict {
  const OfflineModelVerdict(this.issue, {this.detail = ''});

  final OfflineModelIssue issue;
  final String detail;

  bool get canUse => issue == OfflineModelIssue.none;

  /// Thông báo kỹ thuật (log/debug). Chuỗi UI bản địa nằm ở tầng widget.
  String get technicalMessage => switch (issue) {
        OfflineModelIssue.none => '',
        OfflineModelIssue.notInstalled =>
          'No offline model installed for this language.',
        OfflineModelIssue.incompleteFiles =>
          'Offline model files are missing or truncated$detail.',
        OfflineModelIssue.streamingOnly =>
          'Streaming model cannot be used with OfflineRecognizer.',
        OfflineModelIssue.unsupportedLanguage =>
          'No verified offline profile for this language.',
      };
}

/// Ngưỡng tối thiểu (byte) để một bộ file ASR được coi là NGUYÊN VẸN.
///
/// `SherpaModelManager` chỉ yêu cầu >1000 byte; ngưỡng dưới đây vẫn nhỏ hơn
/// nhiều so với model thật (Zipformer VI 30M int8 ≈ 32MB, Parakeet ≈ 600MB)
/// nên KHÔNG từ chối model hợp lệ, nhưng loại được bản tải dở.
const int kMinAsrEncoderBytes = 1024 * 1024; // 1 MB
const int kMinAsrDecoderBytes = 64 * 1024; // 64 KB
const int kMinAsrJoinerBytes = 64 * 1024; // 64 KB
const int kMinAsrTokensBytes = 1024; // 1 KB

bool asrFilesPlausible({
  required int encoderBytes,
  required int decoderBytes,
  required int joinerBytes,
  required int tokensBytes,
}) {
  return encoderBytes >= kMinAsrEncoderBytes &&
      decoderBytes >= kMinAsrDecoderBytes &&
      joinerBytes >= kMinAsrJoinerBytes &&
      tokensBytes >= kMinAsrTokensBytes;
}

/// Preflight chung cho cả ASR (sherpa/Parakeet) và TTS (Piper).
///
/// [installed]      — manager báo profile/voice đã có.
/// [filesPlausible] — kiểm tra kích thước file thực (asrFilesPlausible / piper).
/// [isStreaming]    — true với model EN streaming.
/// [needsOffline]   — true khi đường đi là transcribe FILE (LRC/Cabin file).
OfflineModelVerdict assessOfflineModel({
  required bool installed,
  required bool filesPlausible,
  bool languageSupported = true,
  bool isStreaming = false,
  bool needsOffline = false,
}) {
  if (!languageSupported) {
    return const OfflineModelVerdict(OfflineModelIssue.unsupportedLanguage);
  }
  if (!installed) {
    return const OfflineModelVerdict(OfflineModelIssue.notInstalled);
  }
  if (needsOffline && isStreaming) {
    return const OfflineModelVerdict(OfflineModelIssue.streamingOnly);
  }
  if (!filesPlausible) {
    return const OfflineModelVerdict(
      OfflineModelIssue.incompleteFiles,
      detail: ' (re-import the model in Quản lý Model AI)',
    );
  }
  return const OfflineModelVerdict(OfflineModelIssue.none);
}
