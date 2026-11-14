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

  /// Cỡ chữ (sp) mà layout ĐẢM BẢO vừa [rect] — xem [suggestedTextSizeSp].
  final double textSizeSp;

  /// PSRC-211 — cỡ chữ ƯA THÍCH (sp, = cỡ chữ gốc), luôn ≥ [textSizeSp].
  ///
  /// Dart không đo được font thật nên ước DƯ; khi khung chật nó hạ
  /// [textSizeSp] theo số ước lượng đó. Native đo được font thật ⇒ được phép
  /// thử từ cỡ này trước và chỉ thu nhỏ khi chữ THẬT SỰ không vừa [rect].
  /// `null` = dùng [textSizeSp] (payload cũ / khối không qua layout).
  final double? maxTextSizeSp;

  /// PSRC-211 — đáy của CHỮ GỐC trong [rect] (pixel màn hình).
  ///
  /// [rect] là chỗ Dart GIỮ cho khối (theo ước lượng dư). Native vẽ nền ÔM SÁT
  /// chữ thật: `đáy nền = max(đáy chữ dịch, coverBottom)`, không vượt
  /// `rect.bottom` — vừa hết "khoảng trống thừa bên dưới", vừa không để chữ
  /// gốc lòi ra dưới nền. `null` = phủ kín cả [rect] (hành vi cũ).
  final int? coverBottom;

  /// PSRC-211 (hub 2026-11-13) — trạng thái thứ ba: THU GỌN.
  ///
  /// Khối không còn chỗ cho NGUYÊN bản dịch ở cỡ chữ sàn (cấm hạ dưới 10sp,
  /// cấm cắt chữ) ⇒ thay vì bỏ vẽ im lặng, native vẽ một CHIP nhỏ tại [rect]
  /// (lúc này [rect] là chỗ của chip, không phải khung chữ) và chạm chip mở
  /// popup với [translation] đầy đủ. `false` = khung bình thường.
  final bool collapsed;

  const ScreenBlock({
    required this.rect,
    required this.original,
    required this.translation,
    this.textSizeSp = 14.0,
    this.maxTextSizeSp,
    this.coverBottom,
    this.collapsed = false,
  });

  bool get hasTranslation => translation.trim().isNotEmpty;

  /// Bản dịch được vẽ NGAY TẠI CHỖ chữ gốc (không phải chip thu gọn).
  bool get isShownInPlace => hasTranslation && !collapsed;

  /// Các khoá PSRC-211 CHỈ có mặt khi layout đặt giá trị: payload của khối
  /// không qua layout giữ nguyên 7 khoá cũ (native đọc thiếu ⇒ hành vi cũ).
  Map<String, Object?> toMap() => <String, Object?>{
        ...rect.toMap(),
        'original': original,
        'translation': translation,
        'textSizeSp': textSizeSp,
        if (maxTextSizeSp != null) 'maxTextSizeSp': maxTextSizeSp,
        if (coverBottom != null) 'coverBottom': coverBottom,
        if (collapsed) 'collapsed': true,
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
    final maxSize = map['maxTextSizeSp'];
    return ScreenBlock(
      rect: OverlayRect(left: left, top: top, right: right, bottom: bottom),
      original: (map['original'] as String?) ?? '',
      translation: (map['translation'] as String?) ?? '',
      textSizeSp: size is num ? size.toDouble() : 14.0,
      maxTextSizeSp: maxSize is num ? maxSize.toDouble() : null,
      coverBottom: toInt(map['coverBottom']),
      collapsed: map['collapsed'] == true,
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

  /// PSRC-211 (hub 2026-11-13) — số khối CHƯA dịch vì vượt trần một lượt
  /// (`kScreenTranslateMaxBlocks`). `> 0` ⇒ native hiện chip [pendingLabel];
  /// bấm chip gọi `translatePending` để dịch tiếp phần dư. Không mất khối nào.
  final int pendingCount;

  /// Nhãn chip "Còn N khối · Dịch tiếp" — đã i18n ở Dart (đủ 8 locale).
  /// Rỗng khi [pendingCount] = 0.
  final String pendingLabel;

  /// Tiêu đề popup mở ra khi chạm một chip thu gọn — đã i18n ở Dart.
  final String popupTitle;

  const ScreenTranslateResult({
    required this.status,
    this.blocks = const <ScreenBlock>[],
    this.message = '',
    this.engine = '',
    this.missingModelCodes = const <String>[],
    this.elapsed = Duration.zero,
    this.pendingCount = 0,
    this.pendingLabel = '',
    this.popupTitle = '',
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
        'pendingCount': pendingCount,
        'pendingLabel': pendingLabel,
        'popupTitle': popupTitle,
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
    final pending = map['pendingCount'];
    return ScreenTranslateResult(
      status: status,
      blocks: blocks,
      message: (map['message'] as String?) ?? '',
      engine: (map['engine'] as String?) ?? '',
      missingModelCodes: missing,
      elapsed: Duration(milliseconds: elapsedMs is num ? elapsedMs.toInt() : 0),
      pendingCount: pending is num ? pending.toInt() : 0,
      pendingLabel: (map['pendingLabel'] as String?) ?? '',
      popupTitle: (map['popupTitle'] as String?) ?? '',
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

  // XLAT-SCR-005 — đổi CẢ HAI đầu ngôn ngữ khi bong bóng đang chạy.
  static const String methodSetLanguages = 'setLanguages';

  /// Bật/tắt "mỗi lần bấm bong bóng = kéo chọn vùng" khi service đang chạy.
  static const String methodSetCaptureMode = 'setCaptureMode';

  // XLAT-SCR-003 — tự kiểm tra quyền trước khi hiện bong bóng.
  /// Trả Map trạng thái quyền (khoá xem [ScreenTranslateNativeStatus]).
  static const String methodStatus = 'status';

  /// Xin consent MediaProjection NGAY (chỉ gọi khi app đang foreground).
  static const String methodRequestConsent = 'requestConsent';

  // native → Dart (engine nền)
  static const String methodOnFrame = 'onFrame';
  static const String methodOnStopped = 'onStopped';

  /// PSRC-211 — bấm chip "Còn N khối · Dịch tiếp": dịch lượt kế tiếp của phần
  /// dư trên CÙNG ảnh chụp (không chụp lại). Trả cùng dạng payload như
  /// [methodOnFrame], `blocks` gồm cả các khối của lượt trước.
  static const String methodTranslatePending = 'translatePending';

  // Dart (engine nền) → native
  static const String methodWorkerReady = 'workerReady';
  static const String methodReportProgress = 'reportProgress';

  // Khoá payload frame (native → Dart). Khoá vùng kéo chọn phải KHỚP
  // `ScreenRegion.fromMap` — lệch tên là "kéo chọn vùng" im lặng thành
  // "dịch cả màn hình".
  static const String frameRegionLeft = 'regionLeft';
  static const String frameRegionTop = 'regionTop';
  static const String frameRegionRight = 'regionRight';
  static const String frameRegionBottom = 'regionBottom';
  static const String frameSourceLanguage = 'sourceLanguage';

  // PSRC-211 — lề hệ thống (pixel màn hình: thanh trạng thái / điều hướng /
  // tai thỏ) lấy từ `WindowMetrics`. Tuỳ chọn: thiếu cả bốn ⇒ không phân biệt
  // vùng nhìn. Khớp `screenViewportFromFrame`.
  static const String frameInsetLeft = 'insetLeft';
  static const String frameInsetTop = 'insetTop';
  static const String frameInsetRight = 'insetRight';
  static const String frameInsetBottom = 'insetBottom';
}
