/// Các model Whisper app hỗ trợ tải/import.
///
/// WHISPER-VARIANT-001 — Whisper có 2 dòng model cho mỗi kích thước:
/// - **đa ngôn ngữ** (`ggml-tiny.bin`, 99 ngôn ngữ) — `tiny`…`large`;
/// - **English-only** (`ggml-tiny.en.bin`) — `tinyEn`…`mediumEn`.
///
/// Model `.en` cùng số tham số nhưng chỉ nhận tiếng Anh: với audio tiếng Anh
/// nó chính xác hơn bản đa ngữ ở cùng kích thước và không bao giờ "đoán" sang
/// ngôn ngữ khác. Ngược lại nó KHÔNG dùng được cho VI/ZH/… — UI phải nói rõ.
///
/// `large` không có bản `.en` (OpenAI chỉ phát hành .en cho tiny→medium) nên
/// dòng English-only dừng ở [mediumEn].
enum WhisperModelLevel {
  // ── Đa ngôn ngữ (multilingual) ──────────────────────────────────────────
  tiny,
  base,
  small,
  medium,
  large,

  // ── English-only (.en) ──────────────────────────────────────────────────
  tinyEn,
  baseEn,
  smallEn,
  mediumEn,
}

/// Model đa ngôn ngữ (99 ngôn ngữ) — thứ tự hiển thị trong UI.
const List<WhisperModelLevel> kWhisperMultilingualLevels = [
  WhisperModelLevel.tiny,
  WhisperModelLevel.base,
  WhisperModelLevel.small,
  WhisperModelLevel.medium,
  WhisperModelLevel.large,
];

/// Model English-only (`.en`) — nhẹ/chính xác hơn cho audio tiếng Anh.
const List<WhisperModelLevel> kWhisperEnglishOnlyLevels = [
  WhisperModelLevel.tinyEn,
  WhisperModelLevel.baseEn,
  WhisperModelLevel.smallEn,
  WhisperModelLevel.mediumEn,
];

extension WhisperModelLevelX on WhisperModelLevel {
  String get keyName {
    switch (this) {
      case WhisperModelLevel.tiny:
        return 'tiny';
      case WhisperModelLevel.base:
        return 'base';
      case WhisperModelLevel.small:
        return 'small';
      case WhisperModelLevel.medium:
        return 'medium';
      case WhisperModelLevel.large:
        return 'large';
      case WhisperModelLevel.tinyEn:
        return 'tinyEn';
      case WhisperModelLevel.baseEn:
        return 'baseEn';
      case WhisperModelLevel.smallEn:
        return 'smallEn';
      case WhisperModelLevel.mediumEn:
        return 'mediumEn';
    }
  }

  /// Model chỉ nhận tiếng Anh (`.en`).
  bool get isEnglishOnly {
    switch (this) {
      case WhisperModelLevel.tiny:
      case WhisperModelLevel.base:
      case WhisperModelLevel.small:
      case WhisperModelLevel.medium:
      case WhisperModelLevel.large:
        return false;
      case WhisperModelLevel.tinyEn:
      case WhisperModelLevel.baseEn:
      case WhisperModelLevel.smallEn:
      case WhisperModelLevel.mediumEn:
        return true;
    }
  }

  /// Bản đa ngữ cùng kích thước (dùng để đối chiếu size/kích thước tối thiểu
  /// và làm "model thay thế" khi user đổi ngôn ngữ).
  WhisperModelLevel get multilingualTwin {
    switch (this) {
      case WhisperModelLevel.tiny:
      case WhisperModelLevel.tinyEn:
        return WhisperModelLevel.tiny;
      case WhisperModelLevel.base:
      case WhisperModelLevel.baseEn:
        return WhisperModelLevel.base;
      case WhisperModelLevel.small:
      case WhisperModelLevel.smallEn:
        return WhisperModelLevel.small;
      case WhisperModelLevel.medium:
      case WhisperModelLevel.mediumEn:
        return WhisperModelLevel.medium;
      case WhisperModelLevel.large:
        return WhisperModelLevel.large;
    }
  }

  /// Tên kích thước không kèm hậu tố: `TINY`, `BASE`… (UI tự thêm `· EN`).
  String get sizeLabel {
    switch (this) {
      case WhisperModelLevel.tiny:
      case WhisperModelLevel.tinyEn:
        return 'TINY';
      case WhisperModelLevel.base:
      case WhisperModelLevel.baseEn:
        return 'BASE';
      case WhisperModelLevel.small:
      case WhisperModelLevel.smallEn:
        return 'SMALL';
      case WhisperModelLevel.medium:
      case WhisperModelLevel.mediumEn:
        return 'MEDIUM';
      case WhisperModelLevel.large:
        return 'LARGE';
    }
  }

  /// Nhãn ngắn cho chip/nút: `TINY`, `TINY · EN`.
  String get displayLabel =>
      isEnglishOnly ? '$sizeLabel · EN' : sizeLabel;

  String get fileName {
    switch (this) {
      case WhisperModelLevel.tiny:
        return 'ggml-tiny.bin';
      case WhisperModelLevel.base:
        return 'ggml-base.bin';
      case WhisperModelLevel.small:
        return 'ggml-small.bin';
      case WhisperModelLevel.medium:
        return 'ggml-medium.bin';
      case WhisperModelLevel.large:
        return 'ggml-large-v2.bin';
      case WhisperModelLevel.tinyEn:
        return 'ggml-tiny.en.bin';
      case WhisperModelLevel.baseEn:
        return 'ggml-base.en.bin';
      case WhisperModelLevel.smallEn:
        return 'ggml-small.en.bin';
      case WhisperModelLevel.mediumEn:
        return 'ggml-medium.en.bin';
    }
  }

  /// Tên file ưu tiên + các tên có thể chấp nhận khi scan/import.
  List<String> get candidateFileNames {
    switch (this) {
      case WhisperModelLevel.tiny:
        return const ['ggml-tiny.bin'];
      case WhisperModelLevel.base:
        return const ['ggml-base.bin'];
      case WhisperModelLevel.small:
        return const ['ggml-small.bin'];
      case WhisperModelLevel.medium:
        return const ['ggml-medium.bin'];
      case WhisperModelLevel.large:
        return const ['ggml-large-v2.bin'];
      case WhisperModelLevel.tinyEn:
        return const ['ggml-tiny.en.bin'];
      case WhisperModelLevel.baseEn:
        return const ['ggml-base.en.bin'];
      case WhisperModelLevel.smallEn:
        return const ['ggml-small.en.bin'];
      case WhisperModelLevel.mediumEn:
        return const ['ggml-medium.en.bin'];
    }
  }

  /// Chỉ dùng để lọc file rác / file sai format quá nhỏ.
  double get minimumAcceptedSizeMB => multilingualTwin._minimumMB;

  double get _minimumMB {
    switch (this) {
      case WhisperModelLevel.tiny:
        return 10;
      case WhisperModelLevel.base:
        return 20;
      case WhisperModelLevel.small:
        return 60;
      case WhisperModelLevel.medium:
        return 150;
      case WhisperModelLevel.large:
        return 300;
      case WhisperModelLevel.tinyEn:
      case WhisperModelLevel.baseEn:
      case WhisperModelLevel.smallEn:
      case WhisperModelLevel.mediumEn:
        return 10;
    }
  }

  /// Kích thước tham khảo (MB) — model `.en` cùng số tham số với bản đa ngữ.
  int get sizeInMB => multilingualTwin._sizeMB;

  int get _sizeMB {
    switch (this) {
      case WhisperModelLevel.tiny:
        return 31;
      case WhisperModelLevel.base:
        return 57;
      case WhisperModelLevel.small:
        return 181;
      case WhisperModelLevel.medium:
        return 515;
      case WhisperModelLevel.large:
        return 1050;
      case WhisperModelLevel.tinyEn:
      case WhisperModelLevel.baseEn:
      case WhisperModelLevel.smallEn:
      case WhisperModelLevel.mediumEn:
        return 31;
    }
  }

  String get downloadUrl {
    const base = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';
    return '$base/$fileName';
  }

  /// URL dự phòng. RỖNG có chủ đích: GitHub release của whisper.cpp **không**
  /// đính kèm file `ggml-*.bin` (đã kiểm tra API `releases/tags/v1.5.4` →
  /// danh sách asset trống), nên URL GitHub cũ chỉ tốn 1 vòng 404 rồi mới báo
  /// lỗi. [SttModelManager._urlsFor] tự bỏ qua URL rỗng.
  String get mirrorUrl => '';

  String get description {
    switch (this) {
      // ── Đa ngôn ngữ ────────────────────────────────────────────────────
      case WhisperModelLevel.tiny:
        return 'Siêu nhẹ (~31MB) - Nhanh, phù hợp ghi chú nhanh';
      case WhisperModelLevel.base:
        return 'Cân bằng (~57MB) - Tốt cho hầu hết trường hợp';
      case WhisperModelLevel.small:
        return 'Chính xác (~181MB) - Cân bằng giữa tốc độ và chất lượng';
      case WhisperModelLevel.medium:
        return 'Chuyên nghiệp (~515MB) - Rất tốt để phân tích phiên âm';
      case WhisperModelLevel.large:
        return 'Tối thượng (~1GB) - Tốt nhất để sửa lỗi phát âm';
      // ── English-only ───────────────────────────────────────────────────
      case WhisperModelLevel.tinyEn:
        return 'English-only (~31MB) - Nhanh hơn bản đa ngữ, chỉ tiếng Anh';
      case WhisperModelLevel.baseEn:
        return 'English-only (~57MB) - Chính xác hơn bản đa ngữ cho tiếng Anh';
      case WhisperModelLevel.smallEn:
        return 'English-only (~181MB) - Rất tốt cho file tiếng Anh dài';
      case WhisperModelLevel.mediumEn:
        return 'English-only (~515MB) - Chất lượng cao nhất cho tiếng Anh';
    }
  }

  int get requiredFreeSpaceMB => (sizeInMB * 1.2).ceil();

  /// Thư mục con (trong `<documents>/in4up_whisper_models/`) chứa bản sao file
  /// model mà plugin `whisper_flutter_new` nạp được.
  ///
  /// Plugin hard-code đường dẫn `ggml-<tên-model-của-plugin>.bin` và KHÔNG có
  /// enum `.en` ⇒ model `.en` phải được "dịch" sang tên plugin. Đặt bản dịch
  /// trong thư mục con để KHÔNG đè file đa ngữ cùng kích thước và để vòng
  /// quét model (`_listLocalBinFiles`, chỉ đọc cấp 1) không nhìn thấy nó.
  String get pluginAliasSubdir =>
      isEnglishOnly ? 'plugin_alias/$keyName' : '';

  String get expectedSha1 {
    switch (this) {
      case WhisperModelLevel.tiny:
        return '2827a03e495b1ed3048ef28a6a4620537db4ee51';
      case WhisperModelLevel.base:
        return 'a3733eda680ef76256db5fc5dd9de8629e62c5e7';
      case WhisperModelLevel.small:
        return '6fe57ddcfdd1c6b07cdcc73aaf620810ce5fc771';
      case WhisperModelLevel.medium:
      case WhisperModelLevel.large:
      case WhisperModelLevel.tinyEn:
      case WhisperModelLevel.baseEn:
      case WhisperModelLevel.smallEn:
      case WhisperModelLevel.mediumEn:
        return '';
    }
  }
}

enum ModelStatus {
  notDownloaded,
  downloading,
  downloaded,
  corrupted,
  insufficientSpace,
}

class SttModelInfo {
  final WhisperModelLevel level;
  final ModelStatus status;
  final String? localPath;
  final double downloadProgress;
  final String? errorMessage;

  const SttModelInfo({
    required this.level,
    required this.status,
    this.localPath,
    this.downloadProgress = 0.0,
    this.errorMessage,
  });

  bool get isReady => status == ModelStatus.downloaded && localPath != null;

  bool get isDownloading => status == ModelStatus.downloading;

  SttModelInfo copyWith({
    ModelStatus? status,
    String? localPath,
    double? downloadProgress,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return SttModelInfo(
      level: level,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
