enum WhisperModelLevel {
  tiny,
  base,
  small,
  medium,
  large,
}

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
    }
  }

  String get fileName {
    switch (this) {
      case WhisperModelLevel.base:
        return 'ggml-base.en-q5_1.bin';
      default:
        return 'ggml-$name-q5_1.bin';
    }
  }

  /// Tên file ưu tiên + các tên có thể chấp nhận khi scan/import.
  List<String> get candidateFileNames {
    switch (this) {
      case WhisperModelLevel.tiny:
        return const [
          'ggml-tiny-q5_1.bin',
          'ggml-tiny.bin',
          'tiny.bin',
        ];
      case WhisperModelLevel.base:
        return const [
          'ggml-base.en-q5_1.bin',
          'ggml-base-q5_1.bin',
          'ggml-base.en.bin',
          'ggml-base.bin',
          'base.bin',
        ];
      case WhisperModelLevel.small:
        return const [
          'ggml-small-q5_1.bin',
          'ggml-small.bin',
          'small.bin',
        ];
      case WhisperModelLevel.medium:
        return const [
          'ggml-medium-q5_1.bin',
          'ggml-medium.bin',
          'medium.bin',
        ];
      case WhisperModelLevel.large:
        return const [
          'ggml-large-v3-q5_1.bin',
          'ggml-large-v3.bin',
          'ggml-large.bin',
          'large.bin',
        ];
    }
  }

  /// Chỉ dùng để lọc file rác / file sai format quá nhỏ.
  double get minimumAcceptedSizeMB {
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
    }
  }

  int get sizeInMB {
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
    }
  }

  String get downloadUrl {
    const base = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';
    return '$base/$fileName';
  }

  String get mirrorUrl {
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

  String get expectedSha1 {
    switch (this) {
      case WhisperModelLevel.tiny:
        return '2827a03e495b1ed3048ef28a6a4620537db4ee51';
      case WhisperModelLevel.base:
        return 'a3733eda680ef76256db5fc5dd9de8629e62c5e7';
      case WhisperModelLevel.small:
        return '6fe57ddcfdd1c6b07cdcc73aaf620810ce5fc771';
      case WhisperModelLevel.medium:
        return '';
      case WhisperModelLevel.large:
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
