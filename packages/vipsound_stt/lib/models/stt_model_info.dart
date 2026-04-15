enum WhisperModelLevel {
  tiny,
  base,
  small,
}

extension WhisperModelLevelX on WhisperModelLevel {
  String get name {
    switch (this) {
      case WhisperModelLevel.tiny:  return 'tiny';
      case WhisperModelLevel.base:  return 'base';
      case WhisperModelLevel.small: return 'small';
    }
  }

  String get fileName => 'ggml-$name.en.bin';

  int get sizeInMB {
    switch (this) {
      case WhisperModelLevel.tiny:  return 75;
      case WhisperModelLevel.base:  return 145;
      case WhisperModelLevel.small: return 466;
    }
  }

  /// ✅ Dùng Hugging Face — miễn phí, không cần thẻ tín dụng
  /// Model gốc từ ggerganov/whisper.cpp (official repo)
  String get downloadUrl {
    const base =
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';
    return '$base/$fileName';
  }

  /// URL dự phòng nếu HuggingFace chậm
  String get mirrorUrl {
    // GitHub Releases của whisper.cpp (bản official)
    const base =
        'https://github.com/ggerganov/whisper.cpp/releases/download/v1.5.4';
    return '$base/$fileName';
  }

  String get description {
    switch (this) {
      case WhisperModelLevel.tiny:
        return 'Siêu nhẹ (~75MB) - Nhanh, phù hợp ghi chú nhanh';
      case WhisperModelLevel.base:
        return 'Cân bằng (~145MB) - Tốt cho hầu hết trường hợp';
      case WhisperModelLevel.small:
        return 'Chính xác cao (~466MB) - Lý tưởng cho Deep Learning';
    }
  }

  int get requiredFreeSpaceMB => (sizeInMB * 1.2).ceil();

  /// SHA1 checksum để verify file (lấy từ HuggingFace)
  String get expectedSha1 {
    switch (this) {
      case WhisperModelLevel.tiny:
        return 'bd577a113a864445d4c299885e0cb97d4ba92b5f';
      case WhisperModelLevel.base:
        return '465707469ff3a37a2b9b8d8f89f2f99de7299dac';
      case WhisperModelLevel.small:
        return '55356645c2b361a969dfd0ef2c5a50d530afd8d5';
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

  bool get isReady =>
      status == ModelStatus.downloaded && localPath != null;

  bool get isDownloading => status == ModelStatus.downloading;

  SttModelInfo copyWith({
    ModelStatus? status,
    String? localPath,
    double? downloadProgress,
    String? errorMessage,
  }) {
    return SttModelInfo(
      level: level,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
