import 'dart:io';

/// Model cho 1 file video trên thiết bị
class VideoInfo {
  final String filePath;
  final String fileName;
  final int fileSizeBytes;
  final DateTime lastModified;
  final String extension;

  const VideoInfo({
    required this.filePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.lastModified,
    required this.extension,
  });

  String get fileSizeFormatted {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Tìm file phụ đề .srt/.ass/.vtt cạnh video
  String? get subtitlePath {
    final dir = Directory(filePath.substring(0, filePath.lastIndexOf('/')));
    final baseName = fileName.substring(0, fileName.lastIndexOf('.'));

    for (final ext in ['srt', 'ass', 'vtt']) {
      final subFile = File('${dir.path}/$baseName.$ext');
      if (subFile.existsSync()) return subFile.path;
    }
    return null;
  }

  /// Có phụ đề cạnh video không
  bool get hasSubtitle => subtitlePath != null;

  static List<String> get supportedExtensions =>
      ['mp4', 'mkv', 'webm', 'avi', 'mov', 'm4v', 'flv', '3gp', 'ts'];
}
