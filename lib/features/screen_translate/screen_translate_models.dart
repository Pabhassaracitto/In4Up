// lib/features/screen_translate/screen_translate_models.dart
//
// Mô hình dữ liệu + GIAO THỨC giữa Dart và native cho "dịch màn hình toàn
// hệ thống" (XLAT-SCR-002 · ADR-0011). THUẦN DART — test host VM được.
//
// Giao thức là hợp đồng hai chiều, nên mọi encode/decode nằm ở ĐÂY (một chỗ
// duy nhất) và có test: sai một tên khoá là overlay vẽ rỗng mà không ai biết
// vì sao — lỗi kiểu đó chỉ lộ ra trên thiết bị thật.

import 'screen_translate_geometry.dart';

/// Một khối chữ đã dịch, sẵn sàng cho native vẽ đè.
class ScreenBlock {
  /// Vị trí vẽ (pixel màn hình, y-down).
  final OverlayRect rect;

  /// Chữ gốc OCR đọc được (native hiển thị khi user bật "xem bản gốc").
  final String original;

  /// Bản dịch. Rỗng = dịch hỏng khối này → native vẽ lại chữ gốc mờ, KHÔNG
  /// vẽ ô trống (người dùng phải thấy có chuyện gì xảy ra).
  final String translation;

  /// Cỡ chữ gợi ý (sp) — xem [suggestedTextSizeSp].
  final double textSizeSp;

  const ScreenBlock({
    required this.rect,
    required this.original,
    required this.translation,
    this.textSizeSp = 14.0,
  });

  bool get hasTranslation => translation.trim().isNotEmpty;

  Map<String, Object?> toMap() => <String, Object?>{
        ...rect.toMap(),
        'original': original,
        'translation': translation,
        'textSizeSp': textSizeSp,
      };

  static ScreenBlock? fromMap(Map<Object?, Object?> map) {
    int? toInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.round();
      if (v is String) return int.tryParse(v);
      return null;
    }

    final left = toInt(map['left']);
    final top = toInt(map['top']);
    final right = toInt(map['right']);
    final bottom = toInt(map['bottom']);
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    final size = map['textSizeSp'];
    return ScreenBlock(
      rect: OverlayRect(left: left, top: top, right: right, bottom: bottom),
      original: (map['original'] as String?) ?? '',
      translation: (map['translation'] as String?) ?? '',
      textSizeSp: size is num ? size.toDouble() : 14.0,
    );
  }
}

/// Trạng thái kết thúc của một lượt dịch màn hình.
///
/// Native dựa vào đây để chọn hiển thị: overlay chữ, toast "không thấy chữ",
/// hay thông báo lỗi có hành động.
enum ScreenTranslateStatus {
  /// Có ít nhất một khối dịch được.
  ok,

  /// OCR chạy xong nhưng màn hình không có chữ Latin nào.
  noText,

  /// Lượt này bị bỏ qua vì đang có lượt khác chạy / bấm quá nhanh (debounce).
  skipped,

  /// Thiếu gói dịch offline (ML Kit) — native phải nói RÕ ngôn ngữ nào thiếu
  /// và hướng user vào Cài đặt dịch để bấm "Tải về". KHÔNG tự tải (luật vàng:
  /// không HTTP tải model ngoài thao tác user).
  missingModel,

  /// Lỗi khác (OCR fail, timeout, engine dịch hỏng).
  error,
}

/// Kết quả một lượt dịch màn hình trả về native.
class ScreenTranslateResult {
  final ScreenTranslateStatus status;
  final List<ScreenBlock> blocks;

  /// Thông điệp cho người dùng (đã i18n ở phía Dart trước khi gửi xuống).
  final String message;

  /// Tên engine đã dịch (hiện trong notification để chứng minh "đúng engine
  /// đang chọn trong Cài đặt dịch" — tiêu chí nghiệm thu #3).
  final String engine;

  /// Mã ngôn ngữ thiếu model offline (khi [status] = missingModel).
  final List<String> missingModelCodes;

  /// Tổng thời gian OCR + dịch.
  final Duration elapsed;

  const ScreenTranslateResult({
    required this.status,
    this.blocks = const <ScreenBlock>[],
    this.message = '',
    this.engine = '',
    this.missingModelCodes = const <String>[],
    this.elapsed = Duration.zero,
  });

  bool get isOk => status == ScreenTranslateStatus.ok;

  /// Payload gửi qua MethodChannel. Chỉ dùng kiểu chuẩn (String/int/double/
  /// bool/List/Map) — StandardMessageCodec không nhận enum hay class.
  Map<String, Object?> toMap() => <String, Object?>{
        'status': status.name,
        'message': message,
        'engine': engine,
        'elapsedMs': elapsed.inMilliseconds,
        'missingModelCodes': missingModelCodes,
        'blocks': blocks.map((b) => b.toMap()).toList(growable: false),
      };

  static ScreenTranslateResult fromMap(Map<Object?, Object?> map) {
    final rawStatus = (map['status'] as String?) ?? 'error';
    final status = ScreenTranslateStatus.values.firstWhere(
      (s) => s.name == rawStatus,
      orElse: () => ScreenTranslateStatus.error,
    );
    final rawBlocks = map['blocks'];
    final blocks = <ScreenBlock>[];
    if (rawBlocks is List) {
      for (final item in rawBlocks) {
        if (item is Map) {
          final block = ScreenBlock.fromMap(item);
          if (block != null) blocks.add(block);
        }
      }
    }
    final rawMissing = map['missingModelCodes'];
    final missing = <String>[
      if (rawMissing is List)
        for (final code in rawMissing)
          if (code != null) code.toString(),
    ];
    final elapsedMs = map['elapsedMs'];
    return ScreenTranslateResult(
      status: status,
      blocks: blocks,
      message: (map['message'] as String?) ?? '',
      engine: (map['engine'] as String?) ?? '',
      missingModelCodes: missing,
      elapsed: Duration(milliseconds: elapsedMs is num ? elapsedMs.toInt() : 0),
    );
  }

  factory ScreenTranslateResult.failure(String message) =>
      ScreenTranslateResult(
        status: ScreenTranslateStatus.error,
        message: message,
      );

  factory ScreenTranslateResult.skipped(String message) =>
      ScreenTranslateResult(
        status: ScreenTranslateStatus.skipped,
        message: message,
      );
}

/// Tên channel + tên method — hằng số dùng chung để Dart và Kotlin không
/// "lệch chính tả" trong im lặng.
class ScreenTranslateProtocol {
  const ScreenTranslateProtocol._();

  /// Channel mà UI engine dùng để điều khiển service.
  static const String controlChannel = 'in4up/screentranslate';

  /// Channel mà engine NỀN (service tự khởi) dùng để nhận frame.
  static const String workerChannel = 'in4up/screentranslate/worker';

  // UI → native
  static const String methodIsSupported = 'isSupported';
  static const String methodHasOverlayPermission = 'hasOverlayPermission';
  static const String methodRequestOverlayPermission =
      'requestOverlayPermission';
  static const String methodStart = 'start';
  static const String methodStop = 'stop';
  static const String methodIsRunning = 'isRunning';
  static const String methodSetTargetLanguage = 'setTargetLanguage';

  // XLAT-SCR-003 — tự kiểm tra quyền trước khi hiện bong bóng.
  /// Trả Map trạng thái quyền (khoá xem [ScreenTranslateNativeStatus]).
  static const String methodStatus = 'status';

  /// Xin consent MediaProjection NGAY (chỉ gọi khi app đang foreground).
  static const String methodRequestConsent = 'requestConsent';

  // native → Dart (engine nền)
  static const String methodOnFrame = 'onFrame';
  static const String methodOnStopped = 'onStopped';

  // Dart (engine nền) → native
  static const String methodWorkerReady = 'workerReady';
  static const String methodReportProgress = 'reportProgress';
}
