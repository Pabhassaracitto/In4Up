// lib/features/ocr/ocr_precheck.dart
//
// OCR-SCAN-CRASH-001 (giả thuyết 1 + 3) — QUYẾT ĐỊNH trước khi mở máy quét.
//
// Vì sao cần: `google_mlkit_document_scanner` 0.5.0 gọi thẳng
// `GmsDocumentScanning.getClient(options)` / `getStartScanIntent(activity)`
// trên luồng platform mà KHÔNG bọc try/catch (đối chiếu source tại đúng
// commit release `f29f844` = 0.5.0 — xem KANBAN OCR-SCAN-CRASH-001). Máy thiếu
// Google Play services, Play services bị tắt, hoặc RAM dưới ngưỡng Google yêu
// cầu (1,7 GB — tài liệu chính thức của ML Kit Document Scanner) thì lỗi ném
// ở tầng native: lớp try/catch của Dart KHÔNG bắt được, app biến mất không
// toast/dialog. Cách chữa đúng là **không đi vào đường đó** khi biết chắc nó
// không thể chạy, rồi nói cho người dùng biết vì sao + có đường thay thế.
//
// File này THUẦN DART (không Flutter, không plugin) → test chạy trên host VM.
// Việc hỏi thiết bị nằm ở `OcrNativeBridge` (MethodChannel `in4up/ocr`) và
// `OcrService.probeCapabilities()`.

/// Khả năng thiết bị — dữ liệu thô để [OcrPrecheck.decide] ra quyết định.
///
/// null của `totalRamBytes` = KHÔNG đo được (kênh native cũ/không trả) →
/// không được chặn oan người dùng vì lý do RAM.
class OcrDeviceCapabilities {
  /// Nền tảng có ML Kit hay không (Android/iOS).
  final bool platformSupported;

  /// Nền tảng có Document Scanner hay không (chỉ Android).
  final bool documentScannerSupported;

  /// `com.google.android.gms` có trên máy (PackageManager thấy).
  final bool playServicesInstalled;

  /// Gói Play services có đang bật (không bị user disable).
  final bool playServicesEnabled;

  /// versionCode của Play services (null = không đọc được).
  final int? playServicesVersionCode;

  /// Android SDK_INT (null khi không phải Android).
  final int? androidSdkInt;

  /// Tổng RAM thiết bị theo byte (null = không đo được).
  final int? totalRamBytes;

  const OcrDeviceCapabilities({
    required this.platformSupported,
    required this.documentScannerSupported,
    this.playServicesInstalled = false,
    this.playServicesEnabled = false,
    this.playServicesVersionCode,
    this.androidSdkInt,
    this.totalRamBytes,
  });

  /// Dựng từ map thô của kênh native. Giá trị thiếu/sai kiểu KHÔNG được coi
  /// là "có" — thà rơi về trạng thái an toàn (Play services = false) còn hơn
  /// đi vào đường native đã biết là chết.
  factory OcrDeviceCapabilities.fromNativeMap(
    Map<Object?, Object?> map, {
    required bool platformSupported,
    required bool documentScannerSupported,
  }) {
    int? asInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    bool asBool(Object? value, {required bool fallback}) {
      if (value is bool) return value;
      return fallback;
    }

    return OcrDeviceCapabilities(
      platformSupported: platformSupported,
      documentScannerSupported: documentScannerSupported,
      playServicesInstalled: asBool(map['gmsInstalled'], fallback: false),
      playServicesEnabled: asBool(map['gmsEnabled'], fallback: false),
      playServicesVersionCode: asInt(map['gmsVersionCode']),
      androidSdkInt: asInt(map['sdkInt']),
      totalRamBytes: asInt(map['totalRamBytes']),
    );
  }

  @override
  String toString() => 'OcrDeviceCapabilities('
      'platformSupported: $platformSupported, '
      'scanner: $documentScannerSupported, '
      'gmsInstalled: $playServicesInstalled, '
      'gmsEnabled: $playServicesEnabled, '
      'gmsVersionCode: $playServicesVersionCode, '
      'sdkInt: $androidSdkInt, '
      'totalRamBytes: $totalRamBytes)';
}

/// Vì sao mở / không mở được máy quét.
enum OcrPrecheckStatus {
  /// Đủ điều kiện — mở máy quét được.
  ready,

  /// Desktop/web: ML Kit không tồn tại.
  unsupportedPlatform,

  /// iOS (hoặc Android thiếu plugin): không có Document Scanner.
  scannerUnsupported,

  /// Thiếu Play services (chưa cài / bị tắt) — Document Scanner là thư viện
  /// "unbundled": model + logic + UI do Play services tải và chạy.
  missingPlayServices,

  /// RAM dưới ngưỡng Google yêu cầu (1,7 GB) — tài liệu ML Kit nói API trả
  /// `MlKitException` mã `UNSUPPORTED` trong trường hợp này.
  lowRam,
}

/// Kết quả quyết định: mở được hay không + câu giải thích (chuỗi NGUỒN tiếng
/// Việt, đã đăng ký catalog — UI dịch qua `uiText`/ARB, không hard-code).
class OcrPrecheckResult {
  final OcrPrecheckStatus status;

  /// Câu giải thích cho người dùng (rỗng khi [status] == ready).
  final String message;

  const OcrPrecheckResult(this.status, this.message);

  /// Chỉ đúng ở [OcrPrecheckStatus.ready].
  bool get canOpenScanner => status == OcrPrecheckStatus.ready;

  /// Có nên mời người dùng mở Play services (hành động sửa được) hay không.
  bool get suggestPlayServices =>
      status == OcrPrecheckStatus.missingPlayServices;

  @override
  String toString() => 'OcrPrecheckResult($status)';
}

/// Quyết định thuần tuý — tách khỏi UI/native để test được trên host VM.
class OcrPrecheck {
  OcrPrecheck._();

  /// Ngưỡng RAM tối thiểu Google ghi trong tài liệu ML Kit Document Scanner:
  /// "It also requires a minimal device total RAM of 1.7GB. If lower, it
  /// returns an MlKitException with error code UNSUPPORTED when calling the
  /// API." 1,7 GB = 1.7 × 1024³ byte.
  static const int minTotalRamBytes = 1825361100; // (1.7 * 1024 * 1024 * 1024).round()

  static OcrPrecheckResult decide(OcrDeviceCapabilities caps) {
    if (!caps.platformSupported) {
      return const OcrPrecheckResult(
        OcrPrecheckStatus.unsupportedPlatform,
        'OCR chỉ chạy trên Android/iOS',
      );
    }
    if (!caps.documentScannerSupported) {
      return const OcrPrecheckResult(
        OcrPrecheckStatus.scannerUnsupported,
        'Máy quét tài liệu chỉ có trên Android — hãy chọn ảnh có sẵn.',
      );
    }
    if (!caps.playServicesInstalled || !caps.playServicesEnabled) {
      return const OcrPrecheckResult(
        OcrPrecheckStatus.missingPlayServices,
        'Máy này thiếu hoặc đang tắt Google Play services — máy quét tài liệu cần Play services để tải và chạy. Cài/cập nhật rồi thử lại.',
      );
    }
    final ram = caps.totalRamBytes;
    if (ram != null && ram > 0 && ram < minTotalRamBytes) {
      return const OcrPrecheckResult(
        OcrPrecheckStatus.lowRam,
        'Thiết bị dưới 1,7 GB RAM nên Google không hỗ trợ máy quét tài liệu. Hãy chọn ảnh có sẵn thay thế.',
      );
    }
    return const OcrPrecheckResult(OcrPrecheckStatus.ready, '');
  }
}
