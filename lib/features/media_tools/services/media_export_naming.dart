// lib/features/media_tools/services/media_export_naming.dart
//
// AVTOOL-002 (PLAN-046 P1) — ĐẶT TÊN FILE đầu ra. HÀM THUẦN.
//
// Vì sao không dùng `AudioConverter.sanitizeFileName`: hàm đó đổi MỌI ký tự
// ngoài ASCII thành `_` ⇒ "Bài giảng số 1" → "B_i_gi_ng_s_1". Với bản xuất cho
// NGƯỜI DÙNG, tên file là thứ họ nhìn thấy trong thư viện/chia sẻ ⇒ phải giữ
// dấu tiếng Việt (giống `AudioImportService.sanitizeFileName`, chỉ loại ký tự
// thật sự nguy hiểm cho FAT/exFAT/Windows: \ / : * ? " < > | và ký tự điều khiển).

import 'package:path/path.dart' as p;

class MediaExportNaming {
  const MediaExportNaming._();

  static const int maxBaseLength = 90;

  /// Tên file an toàn, GIỮ unicode. Rỗng → "audio".
  static String sanitize(String name) {
    var cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Dấu chấm ở cuối bị Windows cắt ⇒ tên đổi sau khi copy.
    cleaned = cleaned.replaceAll(RegExp(r'[. ]+$'), '');
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return 'audio';
    if (cleaned.length > maxBaseLength) {
      cleaned = cleaned.substring(0, maxBaseLength).trimRight();
    }
    return cleaned;
  }

  /// Tên hiển thị cho clip: `Bài giảng 01 [01-02-03]`.
  ///
  /// Dùng `[HH-MM-SS]` (không dùng `:` vì không hợp lệ trên Windows/exFAT).
  static String clipBaseName({
    required String sourceTitle,
    required Duration start,
    Duration? duration,
  }) {
    final base = sanitize(_stripExtension(sourceTitle));
    final startPart = _clock(start);
    if (duration == null) return '$base [$startPart]';
    final end = start + duration;
    return '$base [$startPart-$(_clock(end))]';
  }

  /// Tên cho từng chặng khi tách theo chương.
  static String chapterBaseName({
    required String sourceTitle,
    required int index,
    String? chapterTitle,
    Duration? start,
  }) {
    final base = sanitize(_stripExtension(sourceTitle));
    final order = (index + 1).toString().padLeft(2, '0');
    final custom = (chapterTitle ?? '').trim();
    if (custom.isEmpty) {
      return start == null
          ? '$base - Phần $order'
          : '$base - $order ${_clock(start)}';
    }
    return '$base - $order ${sanitize(custom)}';
  }

  static String _clock(Duration d) {
    final ms = d.inMilliseconds < 0 ? 0 : d.inMilliseconds;
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    // Clip ngắn không cần giờ ⇒ tên gọn hơn.
    return h > 0 ? '$hh-$mm-$ss' : '$mm-$ss';
  }

  static String _stripExtension(String name) {
    final base = p.basename(name.replaceAll(r'\', '/'));
    final dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }

  /// Ghép `base.ext` cho một thư mục, KHÔNG ghi đĩa.
  ///
  /// [exists] cho phép bơm hàm kiểm tra (test thuần không cần ổ đĩa):
  /// trùng tên → `base (2).ext`, `base (3).ext`… đúng quy ước
  /// `AudioImportService` đang dùng ⇒ người dùng không thấy hai kiểu tên.
  static String uniqueFileName({
    required String baseName,
    required String extension,
    required String directory,
    required bool Function(String path) exists,
    int maxAttempts = 200,
  }) {
    final ext = extension.startsWith('.') ? extension : '.$extension';
    final first = p.join(directory, '$baseName$ext');
    if (!exists(first)) return first;
    for (var i = 2; i <= maxAttempts; i++) {
      final candidate = p.join(directory, '$baseName ($i)$ext');
      if (!exists(candidate)) return candidate;
    }
    // Rơi vào trường hợp cực hiếm (200 bản trùng) — thêm dấu thời gian.
    return p.join(
      directory,
      '$baseName ${DateTime.now().millisecondsSinceEpoch}$ext',
    );
  }

  /// `%03d` cho segment muxer: FFmpeg tự thay bằng 000, 001…
  static String segmentPattern({
    required String directory,
    required String baseName,
    required String extension,
  }) {
    final ext = extension.startsWith('.') ? extension : '.$extension';
    return p.join(directory, '${sanitize(baseName)}_%03d$ext');
  }

  /// File danh sách cho concat demuxer (đặt trong thư mục tạm của app).
  static String concatListPath(String tempDirectory) =>
      p.join(tempDirectory, 'in4up_concat_${DateTime.now().millisecondsSinceEpoch}.txt');
}
