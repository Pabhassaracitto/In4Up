// lib/services/image_cache_policy.dart
//
// PERF-001-A — hạn mức `ImageCache` của Flutter, đặt TƯỜNG MINH.
//
// Vấn đề đo được (không phải phỏng đoán): `grep -rn "imageCache" lib` trước
// bản này = 0 kết quả ⇒ app dùng mặc định của Flutter là **1000 ảnh /
// 100 MB** (`ImageCache.maximumSize`/`maximumSizeBytes`) và KHÔNG giảm khi
// rời màn. Trên máy 3–4 GB RAM, 100 MB chỉ riêng ảnh + model GGUF đang nạp
// là lý do bị Android thu hồi tiến trình.
//
// Bản này chỉ đặt lại HAI hạn mức đó + đếm số lần bị trim để đo được về sau,
// không đổi API công khai nào của Flutter/pdfrx.
//
// Ghi chú chọn số:
//   • 48 MB đủ cho ~2 màn ảnh đầy đủ (ảnh 160–720 px đã decode) mà vẫn rẻ
//     hơn mặc định 100 MB một nửa.
//   • 160 ảnh: list từ vựng/explorer YouTube cuộn nhanh vẫn không bị decode
//     lại liên tục (mặc định 1000 ảnh là quá nhiều so với kích thước màn hình).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Hạn mức + kích thước decode ảnh dùng chung cho toàn app.
///
/// Test `test/perf/image_cache_policy_test.dart` pin các hằng số này nằm
/// trong khoảng hợp lý và pin rằng widget ảnh ở các list DÀY có `cacheWidth`
/// (chi tiết: `ImageCachePolicy.thumbCacheWidth`).
class ImageCachePolicy {
  ImageCachePolicy._();

  /// Hạn mức byte của `PaintingBinding.instance.imageCache`.
  ///
  /// Mặc định Flutter = 100 MB (`100 << 20`). Chọn 48 MB (dải hợp lý
  /// 32–96 MB mà test pin).
  static const int maxBytes = 48 * 1024 * 1024;

  /// Hạn mức số ảnh giữ trong cache. Mặc định Flutter = 1000.
  static const int maxImages = 160;

  /// Thumbnail nhỏ trong list (ô 56–96 px @2x ≈ 192 px) ⇒ decode 160 px là
  /// đủ nét, tiết kiệm ~4× bộ nhớ so với decode ảnh gốc (ảnh web 1280 px).
  static const int thumbCacheWidth = 160;

  /// Ảnh vừa trong card/sheet (ô ~120–160 px @2x).
  static const int cardCacheWidth = 320;

  /// Ảnh xem trước lớn trong sheet (cao tối đa 320 px).
  static const int previewCacheWidth = 720;

  /// Đã set hạn mức hay chưa (idempotent — `main()` có thể gọi lại trong test).
  static bool _applied = false;

  /// Số lần cache phải bỏ một ảnh (đo được ở màn chẩn đoán debug).
  static int evictionCount = 0;

  static bool get isApplied => _applied;

  /// Áp hạn mức vào [cache] (mặc định `PaintingBinding.instance.imageCache`).
  ///
  /// Gọi MỘT lần trong `main()` ngay sau `WidgetsFlutterBinding.ensureInitialized()`.
  /// Gọi lại là no-op.
  static void apply({
    ImageCache? cache,
    bool force = false,
    void Function(String message)? log,
  }) {
    final print = log ?? debugPrint;
    if (_applied && !force) return;
    final target = cache ?? PaintingBinding.instance.imageCache;
    target.maximumSizeBytes = maxBytes;
    target.maximumSize = maxImages;
    _lastObservedBytes = target.currentSizeBytes;
    _applied = true;
    print('[in4up-perf] image-cache: tối đa ${maxBytes ~/ (1024 * 1024)} MB / '
        '$maxImages ảnh');

    // Log 1 dòng khi cache bị trim (yêu cầu PERF-001-A).
    //
    // ⚠ Flutter 3.44.1 KHÔNG có `ImageCache.onEvict` (đã thử: analyzer báo
    // `undefined_setter` ở build `835e53a`). Không có listener công khai nào
    // cho việc framework tự bỏ ảnh, nên bản này dò bằng CÁCH SO KÍCH THƯỚC
    // theo nhịp — rẻ và không phụ thuộc API riêng của từng bản Flutter.
    // Chỉ chạy ở build debug: release không có bộ đếm này (không tốn pin).
    if (kDebugMode && _sampler == null) {
      _sampler = Timer.periodic(const Duration(seconds: 10), (_) => observe());
    }
  }

  static Timer? _sampler;
  static int _lastObservedBytes = 0;

  /// So kích thước cache với lần quan sát trước; nếu TỤT thì coi như vừa bị
  /// trim (framework bỏ ảnh để giữ hạn mức) ⇒ tăng bộ đếm + log 1 dòng.
  ///
  /// Gọi từ sampler debug, từ [trimAfterHeavyScreenExit], và từ màn "Chẩn đoán
  /// bộ nhớ" (mỗi lần mở/refresh).
  static bool observe({ImageCache? cache, void Function(String message)? log}) {
    final print = log ?? debugPrint;
    final target = cache ?? PaintingBinding.instance.imageCache;
    final now = target.currentSizeBytes;
    final trimmed = now < _lastObservedBytes;
    final dropped = trimmed ? _lastObservedBytes - now : 0;
    _lastObservedBytes = now;
    if (!trimmed) return false;
    evictionCount++;
    print('[in4up-perf] image-cache trim #$evictionCount '
        '(-${dropped ~/ 1024} KB, đang giữ ${now ~/ 1024} KB / '
        '${target.currentSize} ảnh)');
    return true;
  }

  /// Gọi khi RỜI một màn nặng ảnh (PDF/Web reader).
  ///
  /// Chỉ xoá khi cache đang VƯỢT hạn mức (trường hợp thật sự cần trả RAM):
  /// xoá vô điều kiện sẽ làm list ảnh của màn khác decode lại ngay khi người
  /// dùng quay lại ⇒ khựng — đúng thứ PERF-001 phải tránh. Trả về `true` nếu
  /// lần này có xoá.
  static bool trimAfterHeavyScreenExit({
    ImageCache? cache,
    void Function(String message)? log,
  }) {
    final print = log ?? debugPrint;
    final target = cache ?? PaintingBinding.instance.imageCache;
    if (target.currentSizeBytes <= maxBytes) return false;
    final before = target.currentSizeBytes;
    target.clear();
    print('[in4up-perf] image-cache clear khi rời màn: '
        '${before ~/ (1024 * 1024)} MB → ${target.currentSizeBytes ~/ 1024} KB');
    _lastObservedBytes = target.currentSizeBytes;
    return true;
  }

  /// Reset số đếm (test).
  @visibleForTesting
  static void resetForTest() {
    _applied = false;
    evictionCount = 0;
    _lastObservedBytes = 0;
    _sampler?.cancel();
    _sampler = null;
  }
}
