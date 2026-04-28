enum WhisperModelLevel {
  tiny,
  base,
  small,
  medium,
  large,
}

extension WhisperModelLevelX on WhisperModelLevel {
  String get name {
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
    }
  }

  /// Tên file mặc định khi tải về và tìm kiếm trong assets.
  /// Hiện đang sử dụng phiên bản lượng tử hóa Q5_1.
  String get fileName {
    switch (this) {
      case WhisperModelLevel.base:
        return 'ggml-base.en-q5_1.bin';
      default:
        return 'ggml-$name-q5_1.bin';
    }
  }

  int get sizeInMB {
    switch (this) {
      case WhisperModelLevel.tiny:
        return 31; // tiny-q5_1 chuẩn
      case WhisperModelLevel.base:
        return 57; // base-q5_1 chuẩn
      case WhisperModelLevel.small:
        return 181; // small-q5_1 chuẩn
      case WhisperModelLevel.medium:
        return 515; // medium-q5_1 ước tính
      case WhisperModelLevel.large:
        return 1050; // large-v3-q5_1 ước tính
    }
  }

  /// ✅ Dùng Hugging Face — miễn phí, không cần thẻ tín dụng
  /// Model gốc từ ggerganov/whisper.cpp (official repo)
  String get downloadUrl {
    // Cập nhật URL nếu các model q5_1 nằm ở một đường dẫn khác
    const base = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';
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
        return 'Siêu nhẹ (~31MB) - Nhanh, phù hợp ghi chú nhanh';
      case WhisperModelLevel.base:
        return 'Cân bằng (~57MB) - Tốt cho hầu hết trường hợp';
      case WhisperModelLevel.small:
        return 'Chính xác (~181MB) - Cân bằng giữa tốc độ và chất lượng';
      case WhisperModelLevel.medium:
        return 'Chuyên nghiệp (~515MB) - Rất tốt để phân tích phiên âm';
      case WhisperModelLevel.large:
        return 'Tối thượng (~1GB) - Tốt nhất để sửa lỗi phát âm';
    }
  }

  int get requiredFreeSpaceMB => (sizeInMB * 1.2).ceil();

  /// SHA1 checksum để verify file (lấy từ HuggingFace)
  String get expectedSha1 {
    switch (this) {
      case WhisperModelLevel.tiny:
        return '2827a03e495b1ed3048ef28a6a4620537db4ee51';
      case WhisperModelLevel.base:
        return 'a3733eda680ef76256db5fc5dd9de8629e62c5e7';
      case WhisperModelLevel.small:
        return '6fe57ddcfdd1c6b07cdcc73aaf620810ce5fc771';
      case WhisperModelLevel.medium:
        return ''; // Cập nhật SHA1 sau khi bạn tải file thực tế
      case WhisperModelLevel.large:
        return ''; // Cập nhật SHA1 sau khi bạn tải file thực tế
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
