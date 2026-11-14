// lib/features/screen_translate/screen_translate_controller.dart
//
// Bộ não phía Dart của "dịch màn hình toàn hệ thống" (XLAT-SCR-002 · ADR-0011).
//
// Nguyên tắc kiến trúc (ADR-0011): CHỤP + VẼ ở native, HIỂU CHỮ + DỊCH ở Dart.
// File này KHÔNG biết gì về MediaProjection/WindowManager; nó chỉ nhận một
// frame pixel + hình học màn hình rồi trả về danh sách khối đã dịch.
//
// Nhờ vậy toàn bộ logic quyết định (debounce, cắt vùng, cắt bớt khối, gom lỗi
// thiếu model, thông điệp i18n) test được trên host VM — sandbox không có
// Android.
//
// Tái dùng 100%:
//  - OCR: `OcrService.recognizeBitmapBlocks` (ML Kit Latin, cùng timeout/cancel).
//  - Dịch: `TranslationService.translateText` → cache → engine đang chọn.
//    KHÔNG có engine dịch thứ hai, KHÔNG tự tải model (luật vàng).
//
// XLAT-SCR-005 (owner 24/10) — ba thay đổi hành vi, đều xuất phát từ phản hồi
// "bấm bong bóng lâu quá mà không biết nó đang làm gì":
//  1. **Vùng kéo chọn**: native gửi `regionLeft/Top/Right/Bottom` (toạ độ màn
//     hình); ảnh được CẮT trước khi OCR ⇒ ít chữ, ít request, nhanh hơn hẳn.
//  2. **Dịch song song có giới hạn** (`kScreenTranslateConcurrency`) + gộp
//     khối trùng nội dung: trước đây mỗi khối là một request TUẦN TỰ (32 khối
//     × 300–900ms = 10–30 giây). Đây là nguyên nhân chính của độ trễ.
//  3. **Báo tiến trình**: `onProgress` để native đổi bong bóng/thông báo ngay
//     từ giây đầu, thay vì đứng im rồi bất ngờ có kết quả.
//
// Ngôn ngữ: `sourceLanguage` đi kèm mỗi frame (AUTO = để engine tự nhận diện).
// Trước đây chỉ có ngôn ngữ đích vì pipeline luôn tự nhận diện nguồn — owner
// yêu cầu mở ra để dịch được mọi cặp (kể cả đảo chiều, kể cả hai ngôn ngữ
// khác tiếng Anh).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/language/app_language.dart';
import '../../core/language/app_ui_translations.dart';
import '../ocr/ocr_block.dart';
import '../ocr/ocr_service.dart';
import '../translation/engines/translation_engine.dart';
import '../translation/translation_link_guard.dart';
import '../translation/translation_service.dart';
import 'screen_translate_geometry.dart';
import 'screen_translate_models.dart';
import 'screen_translate_overlay_layout.dart';
import 'screen_translate_text_flow.dart';

/// Chạy OCR trên một frame đã chuẩn hoá (BGRA đặc).
typedef ScreenOcrRunner = Future<OcrBlocksResult> Function({
  required Uint8List pixels,
  required int width,
  required int height,
});

/// Dịch một khối chữ sang [targetLanguage] (mã dịch, vd 'VI').
typedef ScreenBlockTranslator = Future<TranslationResult> Function(
  String text,
  String targetLanguage,
);

/// Chặng của một lượt dịch — native dùng để đổi bong bóng/thông báo.
enum ScreenTranslateStage {
  /// Đang cắt ảnh theo vùng người dùng kéo.
  cropping,

  /// Đang OCR.
  ocr,

  /// Đang dịch từng khối (có thể nhiều request song song).
  translating,

  /// Đã dịch xong, đang chuẩn bị kết quả.
  finishing,
}

/// Báo tiến trình ra ngoài (native → bong bóng + notification).
typedef ScreenProgressReporter = void Function(
  ScreenTranslateStage stage,
  int done,
  int total,
);

/// Cổng chống spam: mỗi lần bấm bong bóng mới chụp một lần, và hai lần bấm
/// quá gần nhau thì bỏ lần sau.
///
/// Đồng hồ bơm từ ngoài vào ([now]) để test không phải `sleep`.
class CaptureGate {
  CaptureGate({
    this.minInterval = const Duration(milliseconds: 1500),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration minInterval;
  final DateTime Function() _now;

  DateTime? _lastAccepted;
  bool _busy = false;

  bool get isBusy => _busy;

  /// True nếu lượt này được chạy. Caller BẮT BUỘC gọi [complete] sau đó
  /// (dùng try/finally) nếu không cổng sẽ kẹt ở trạng thái bận.
  bool tryAcquire() {
    if (_busy) return false;
    final now = _now();
    final last = _lastAccepted;
    if (last != null && now.difference(last) < minInterval) return false;
    _lastAccepted = now;
    _busy = true;
    return true;
  }

  void complete() {
    _busy = false;
    // Mốc debounce tính từ lúc KẾT THÚC: một lượt dịch mất 2–3s, nếu tính từ
    // lúc bắt đầu thì user bấm lại được ngay khi vừa xong — đúng kiểu spam
    // mà card này muốn tránh.
    _lastAccepted = _now();
  }

  /// Dùng khi service bị tắt: lượt sau được chạy ngay, không phải chờ.
  void reset() {
    _busy = false;
    _lastAccepted = null;
  }
}

/// Giới hạn số khối dịch trong một lượt.
///
/// Màn hình dày chữ (trang web dài) có thể ra 60–80 block; dịch hết sẽ vượt
/// mốc 3 giây của tiêu chí nghiệm thu #2 và đốt quota engine online. Ưu tiên
/// khối TO nhất (chữ chính), phần còn lại giữ nguyên bản gốc.
const int kScreenTranslateMaxBlocks = 32;

/// Số request dịch chạy SONG SONG trong một lượt.
///
/// 3 là điểm cân bằng: 32 khối chia 3 luồng ⇒ nhanh hơn ~3 lần so với tuần
/// tự, nhưng vẫn đủ thấp để Google Free/MyMemory không trả 429 (các engine
/// này giới hạn theo IP). Đừng nâng lên "cho nhanh" mà không thử rate limit.
const int kScreenTranslateConcurrency = 3;

/// Ngôn ngữ nguồn mặc định: để engine tự nhận diện.
const String kScreenTranslateAutoSource = 'AUTO';

/// Một khối còn dư của lượt trước, đã quy về TOẠ ĐỘ MÀN HÌNH.
///
/// PSRC-211 vòng 2 (mục 4): trần [kScreenTranslateMaxBlocks] giữ nguyên, phần
/// dư không bị bỏ mà để dành cho lượt "Dịch tiếp". Toạ độ đã map sẵn nên lượt
/// sau không phải đoán lại ảnh chụp cũ (ảnh đó không còn).
class PendingScreenBlock {
  const PendingScreenBlock({
    required this.rect,
    required this.original,
    required this.text,
    required this.textSizeSp,
  });

  /// Khung trên màn hình (pixel) tại lượt phát hiện ra nó.
  final OverlayRect rect;

  /// Chữ gốc như OCR đọc được (hiện khi user bật "xem bản gốc").
  final String original;

  /// Chữ đã nối dòng (gửi cho engine).
  final String text;

  final double textSizeSp;

  Map<String, Object?> toMap() => <String, Object?>{
        ...rect.toMap(),
        'original': original,
        'text': text,
        'textSizeSp': textSizeSp,
      };

  static PendingScreenBlock? fromMap(Map<Object?, Object?> map) {
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
    final text = map['text'];
    if (left == null || top == null || right == null || bottom == null) {
      return null;
    }
    if (text is! String || text.trim().isEmpty) return null;
    final size = map['textSizeSp'];
    return PendingScreenBlock(
      rect: OverlayRect(left: left, top: top, right: right, bottom: bottom),
      original: (map['original'] as String?) ?? text,
      text: text,
      textSizeSp: size is num ? size.toDouble() : 14.0,
    );
  }
}

/// Bộ điều phối một lượt dịch màn hình.
class ScreenTranslateController {
  ScreenTranslateController({
    ScreenOcrRunner? ocrRunner,
    ScreenBlockTranslator? translator,
    CaptureGate? gate,
    ScreenProgressReporter? onProgress,
    int maxBlocks = kScreenTranslateMaxBlocks,
    int concurrency = kScreenTranslateConcurrency,
    String localeCode = 'vi',
    String sourceLanguage = kScreenTranslateAutoSource,
  })  : _ocrRunner = ocrRunner ?? _defaultOcrRunner,
        _translator = translator,
        _gate = gate ?? CaptureGate(),
        _onProgress = onProgress,
        _maxBlocks = maxBlocks,
        _concurrency = concurrency,
        _localeCode = localeCode,
        _sourceLanguage = sourceLanguage;

  final ScreenOcrRunner _ocrRunner;

  /// Engine dịch BƠM VÀO (test). null = dùng pipeline thật của app
  /// ([TranslationService]) với đúng ngôn ngữ nguồn/đích của lượt này.
  final ScreenBlockTranslator? _translator;

  final CaptureGate _gate;
  final ScreenProgressReporter? _onProgress;
  final int _maxBlocks;

  /// Phần dư của lượt gần nhất (tối đa [_maxBlocks] khối, đã ở toạ độ màn
  /// hình) — nguồn cho lượt "Dịch tiếp" (PSRC-211 vòng 2, mục 4).
  List<PendingScreenBlock> _pending = const <PendingScreenBlock>[];
  final int _concurrency;
  String _localeCode;
  String _sourceLanguage;

  /// Locale chrome hiện hành (UI engine gửi xuống khi bật service) — thông
  /// điệp overlay/notification phải theo locale đó, KHÔNG fallback `vi`
  /// (quy tắc vàng #5).
  set localeCode(String value) {
    if (value.trim().isNotEmpty) _localeCode = value.trim();
  }

  String get localeCode => _localeCode;

  /// Ngôn ngữ nguồn hiện hành ('AUTO' hoặc mã dịch như 'EN').
  String get sourceLanguage => _sourceLanguage;

  /// Số khối còn dư của lượt gần nhất (chưa dịch, đang chờ "Dịch tiếp").
  int get pendingCount => _pending.length;

  /// Phần dư đang chờ — chỉ để test/chẩn đoán, không gửi xuống native.
  List<PendingScreenBlock> get pendingBlocks => _pending;

  /// Mốc báo tiến trình gần nhất — chặn spam (mỗi khối xong mà đẩy
  /// notification + vẽ lại bong bóng 32 lần thì chính việc báo tiến trình lại
  /// làm chậm lượt dịch).
  DateTime? _lastProgressAt;
  static const Duration _progressMinInterval = Duration(milliseconds: 250);

  String _t(String source) => AppUITranslations.translate(source, _localeCode);

  static Future<OcrBlocksResult> _defaultOcrRunner({
    required Uint8List pixels,
    required int width,
    required int height,
  }) {
    return OcrService.instance.recognizeBitmapBlocks(
      pixels: pixels,
      width: width,
      height: height,
    );
  }

  /// Dịch một khối bằng pipeline thật (hoặc engine bơm vào khi test).
  ///
  /// `sourceLanguage` là tham số của LƯỢT (native gửi xuống), không phải
  /// biến toàn cục: đổi ngôn ngữ trong Cài đặt khi bong bóng đang chạy phải
  /// có hiệu lực ngay ở lượt kế tiếp.
  Future<TranslationResult> _translateBlock(
    String text,
    String targetLanguage,
    String sourceLanguage,
  ) {
    final injected = _translator;
    if (injected != null) return injected(text, targetLanguage);
    return TranslationService().translateText(
      text,
      sourceLang:
          sourceLanguage == kScreenTranslateAutoSource ? null : sourceLanguage,
      targetLang: targetLanguage,
    );
  }

  void _report(
    ScreenTranslateStage stage, {
    int done = 0,
    int total = 0,
    bool force = true,
  }) {
    final reporter = _onProgress;
    if (reporter == null) return;
    if (!force && stage == ScreenTranslateStage.translating && done < total) {
      final now = DateTime.now();
      final last = _lastProgressAt;
      if (last != null && now.difference(last) < _progressMinInterval) {
        return;
      }
      _lastProgressAt = now;
    }
    try {
      reporter(stage, done, total);
    } catch (e) {
      // Tiến trình là trang trí — không được làm hỏng lượt dịch.
      debugPrint('⚠️ screen translate onProgress: $e');
    }
  }

  /// Câu mô tả chặng, đã i18n theo locale chrome — worker gửi thẳng sang
  /// native để hiện trên bong bóng/thông báo.
  String progressText(
    ScreenTranslateStage stage, {
    int done = 0,
    int total = 0,
  }) {
    switch (stage) {
      case ScreenTranslateStage.cropping:
        return _t('Đang cắt vùng đã chọn…');
      case ScreenTranslateStage.ocr:
        return _t('Đang nhận dạng chữ…');
      case ScreenTranslateStage.translating:
        if (total <= 0) return _t('Đang dịch màn hình…');
        return _t('Đang dịch $done/$total khối chữ…');
      case ScreenTranslateStage.finishing:
        return _t('Sắp xong…');
    }
  }

  /// Xử lý một frame thô từ native.
  ///
  /// Map bắt buộc có: `pixels` (Uint8List), `width`, `height`.
  /// Tuỳ chọn: `rowStride`, `alreadyBgra`, `screenWidth`, `screenHeight`,
  /// `devicePixelRatio`, `targetLanguage`, `sourceLanguage`, `locale`,
  /// `regionLeft/regionTop/regionRight/regionBottom` (vùng kéo chọn, pixel
  /// màn hình).
  Future<ScreenTranslateResult> handleFrame(Map<Object?, Object?> frame) async {
    final locale = frame['locale'];
    if (locale is String) localeCode = locale;
    final sourceRaw = frame['sourceLanguage'];
    if (sourceRaw is String && sourceRaw.trim().isNotEmpty) {
      _sourceLanguage = _normalizeSource(sourceRaw);
    }

    if (!_gate.tryAcquire()) {
      return ScreenTranslateResult.skipped(_t('Đang dịch màn hình, chờ chút…'));
    }
    final stopwatch = Stopwatch()..start();
    try {
      return await _run(frame, stopwatch);
    } catch (e) {
      debugPrint('❌ screen translate handleFrame: $e');
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.error,
        message: _t('Dịch màn hình thất bại'),
        elapsed: stopwatch.elapsed,
      );
    } finally {
      _gate.complete();
    }
  }

  /// Lượt "Dịch tiếp": dịch phần dư [pendingBlocks] của lượt gần nhất.
  ///
  /// PSRC-211 vòng 2 (mục 4 của `L4-hub-tra-loi.md`): chip "còn N khối · Dịch
  /// tiếp" của native gọi vào đây. Toạ độ khối đã ở hệ màn hình nên KHÔNG cần
  /// chụp lại — ảnh của lượt trước đã được giải phóng, và chụp mới sẽ là một
  /// lượt khác (có thể ra tập khối khác) chứ không phải "dịch tiếp phần dư".
  ///
  /// Không có phần dư ⇒ null (native coi như đã hết, ẩn chip).
  /// Cổng [CaptureGate]: bấm liên tục vẫn bị chặn như lượt chụp thường, nên
  /// không tự vòng lặp vô hạn và không đốt quota engine.
  Future<ScreenTranslateResult?> translatePendingBlocks({
    String? targetLanguage,
  }) async {
    if (_pending.isEmpty) return null;
    if (!_gate.tryAcquire()) {
      return ScreenTranslateResult.skipped(_t('Đang dịch màn hình, chờ chút…'));
    }
    final stopwatch = Stopwatch()..start();
    try {
      return await _runPending(
        targetLanguage ??
            AppLanguageCatalog.normalizeTranslationCode('VI', fallback: 'VI'),
        stopwatch,
      );
    } catch (e) {
      debugPrint('❌ screen translate translatePendingBlocks: $e');
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.error,
        message: _t('Dịch màn hình thất bại'),
        elapsed: stopwatch.elapsed,
      );
    } finally {
      _gate.complete();
    }
  }

  /// Phần thân của lượt "Dịch tiếp" — thuần Dart, test được trên host VM.
  Future<ScreenTranslateResult> _runPending(
    String target,
    Stopwatch stopwatch,
  ) async {
    // Mỗi lượt vẫn giữ trần [kScreenTranslateMaxBlocks] (mốc 3 giây + quota
    // engine). Phần dư còn lại ở yên trong hàng đợi cho lần bấm tiếp theo ⇒
    // không bao giờ mất khối, cũng không tự lặp vô hạn.
    final limit = math.max(0, _maxBlocks);
    final batch = _pending.take(limit).toList(growable: false);
    final rest = _pending.skip(limit).toList(growable: false);
    final missing = <String>{};
    final engines = <String>[];
    var anyTranslated = false;
    var doneCount = 0;

    _report(
      ScreenTranslateStage.translating,
      done: 0,
      total: batch.length,
    );

    final inflight = <String, Future<TranslationResult>>{};
    Future<TranslationResult> translateOnce(String text) {
      final key = text.trim();
      return inflight.putIfAbsent(
        key,
        () => _translateBlock(key, target, _sourceLanguage),
      );
    }

    final out = List<ScreenBlock?>.filled(batch.length, null);
    Future<void> runOne(int index) async {
      final pending = batch[index];
      var translation = '';
      try {
        final result = await translateOnce(pending.text);
        if (result.isSuccess && result.translatedText.trim().isNotEmpty) {
          translation = normalizeOverlayText(result.translatedText);
          anyTranslated = true;
          if (engines.isEmpty) engines.add(result.engineName);
        } else {
          final codes = result.missingModelCodes;
          if (codes != null) missing.addAll(codes);
        }
      } catch (e) {
        debugPrint('❌ screen translate khối dư "${pending.text}": $e');
      }
      out[index] = ScreenBlock(
        rect: pending.rect,
        original: pending.original,
        translation: translation,
        textSizeSp: pending.textSizeSp,
      );
      doneCount++;
      _report(
        ScreenTranslateStage.translating,
        done: doneCount,
        total: batch.length,
        force: doneCount >= batch.length,
      );
    }

    var next = 0;
    final workerCount = math.max(1, math.min(_concurrency, batch.length));
    Future<void> worker() async {
      while (true) {
        final slot = next;
        if (slot >= batch.length) return;
        next = slot + 1;
        await runOne(slot);
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );

    _report(ScreenTranslateStage.finishing);

    // Lượt này xong `batch`; phần còn lại (nếu có) vẫn chờ ⇒ chip "còn N
    // khối" tự cập nhật đúng số, về 0 khi đã dịch hết.
    _pending = rest;

    final rawBlocks = <ScreenBlock>[
      for (final block in out)
        if (block != null) block,
    ];
    final translatedCount = rawBlocks.where((b) => b.hasTranslation).length;
    debugPrint(
      'ℹ️ screen translate pending round: pending=${batch.length} '
      'translated=$translatedCount',
    );

    if (!anyTranslated) {
      if (missing.isNotEmpty) {
        return ScreenTranslateResult(
          status: ScreenTranslateStatus.missingModel,
          blocks: rawBlocks,
          message: _t('Chưa tải gói dịch ngoại tuyến cho ngôn ngữ này'),
          missingModelCodes: missing.toList(growable: false),
          elapsed: stopwatch.elapsed,
          pendingBlocks: rest.length,
        );
      }
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.error,
        blocks: rawBlocks,
        message: _t('Dịch màn hình thất bại'),
        elapsed: stopwatch.elapsed,
        pendingBlocks: rest.length,
      );
    }

    return ScreenTranslateResult(
      status: ScreenTranslateStatus.ok,
      blocks: rawBlocks,
      engine: engines.isEmpty ? '' : engines.first,
      missingModelCodes: missing.toList(growable: false),
      elapsed: stopwatch.elapsed,
      // Vẫn còn khối chờ (màn hình > 2× trần 32) ⇒ chip tiếp tục hiện đúng số.
      pendingBlocks: rest.length,
    );
  }

  /// Chuẩn hoá mã ngôn ngữ nguồn. Lạ/không hỗ trợ ⇒ AUTO (không đoán bừa).
  static String _normalizeSource(String raw) {
    final value = raw.trim().replaceAll('_', '-').toUpperCase();
    if (value.isEmpty || value == 'AUTO' || value == 'SYSTEM') {
      return kScreenTranslateAutoSource;
    }
    final resolved = AppLanguageCatalog.maybeFromCode(value);
    return resolved?.translationCode ?? kScreenTranslateAutoSource;
  }

  Future<ScreenTranslateResult> _run(
    Map<Object?, Object?> frame,
    Stopwatch stopwatch,
  ) async {
    final pixels = frame['pixels'];
    if (pixels is! Uint8List || pixels.isEmpty) {
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.error,
        message: _t('Không chụp được màn hình'),
        elapsed: stopwatch.elapsed,
      );
    }

    final geometry = ScreenCaptureGeometry.fromMap(frame);
    if (!geometry.isValid) {
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.error,
        message: _t('Không chụp được màn hình'),
        elapsed: stopwatch.elapsed,
      );
    }

    final rowStrideRaw = frame['rowStride'];
    final rowStride = rowStrideRaw is num
        ? rowStrideRaw.toInt()
        : geometry.captureWidth * 4;
    final alreadyBgra = frame['alreadyBgra'] == true;

    final Uint8List normalized;
    try {
      normalized = normalizeCaptureFrame(
        pixels,
        width: geometry.captureWidth,
        height: geometry.captureHeight,
        rowStride: rowStride,
        alreadyBgra: alreadyBgra,
      );
    } on ArgumentError catch (e) {
      debugPrint('❌ screen translate frame không hợp lệ: ${e.message}');
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.error,
        message: _t('Không chụp được màn hình'),
        elapsed: stopwatch.elapsed,
      );
    }

    // ── Vùng kéo chọn (tuỳ chọn) ──────────────────────────────────────
    // Lỗi cắt KHÔNG được làm hỏng lượt dịch: rơi về "cả màn hình" và ghi log
    // — native đang chờ kết quả, im lặng bỏ qua sẽ thành "bấm không ra gì".
    final requestedRegion = ScreenRegion.fromMap(frame);
    final captureRegion = screenRegionToCapture(requestedRegion, geometry);
    var workPixels = normalized;
    var workWidth = geometry.captureWidth;
    var workHeight = geometry.captureHeight;
    var offsetX = 0;
    var offsetY = 0;
    if (captureRegion != null) {
      _report(ScreenTranslateStage.cropping);
      try {
        workPixels = cropPackedFrame(
          normalized,
          width: geometry.captureWidth,
          height: geometry.captureHeight,
          region: captureRegion,
        );
        workWidth = captureRegion.width;
        workHeight = captureRegion.height;
        offsetX = captureRegion.left;
        offsetY = captureRegion.top;
      } on ArgumentError catch (e) {
        debugPrint('⚠️ screen translate cắt vùng lỗi, dùng cả màn hình: $e');
        workPixels = normalized;
        workWidth = geometry.captureWidth;
        workHeight = geometry.captureHeight;
        offsetX = 0;
        offsetY = 0;
      }
    } else if (requestedRegion != null) {
      debugPrint(
        'ℹ️ screen translate: vùng chọn $requestedRegion quá bé/ngoài màn '
        'hình ⇒ dịch cả màn hình',
      );
    }

    _report(ScreenTranslateStage.ocr);
    final ocr = await _ocrRunner(
      pixels: workPixels,
      width: workWidth,
      height: workHeight,
    );
    if (!ocr.isSuccess) {
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.error,
        message: ocr.isTimeout
            ? _t('Nhận dạng chữ quá lâu, thử lại')
            : _t('Không nhận dạng được chữ trên màn hình'),
        elapsed: stopwatch.elapsed,
      );
    }
    if (ocr.blocks.isEmpty) {
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.noText,
        message: _t('Không thấy chữ nào trên màn hình'),
        elapsed: stopwatch.elapsed,
      );
    }

    final targetRaw = frame['targetLanguage'];
    final target = (targetRaw is String && targetRaw.trim().isNotEmpty)
        ? AppLanguageCatalog.normalizeTranslationCode(targetRaw, fallback: 'VI')
        : 'VI';

    // PSRC-211: ML Kit có lúc tách MỘT đoạn văn thành nhiều khối 1 dòng. Dịch
    // từng dòng cụt vừa sai nghĩa vừa tạo ra chuỗi bong bóng đẩy nhau lệch
    // khỏi chữ gốc ⇒ gộp các dòng CÙNG ĐOẠN thành một khối trước khi chọn.
    // Điều kiện gộp rất chặt (xem `belongToSameParagraph`); không khớp thì
    // danh sách giữ nguyên như trước.
    final paragraphs = mergeWrappedBlocks(ocr.blocks);

    // PSRC-211 (mục 7.3 của `L4-hub-tra-loi.md`) - LỌC RÁC TRƯỚC KHI CẮT HẠN
    // MỨC. Bản trước cắt `take(32)` rồi mới loại số/ký hiệu/link, nên trên màn
    // hình dày chữ những khối rác (giờ, icon, URL) vẫn chiếm suất của khối chữ
    // thật ⇒ khối thật bị bỏ. Giờ rác bị loại trước, hạn mức chỉ tính khối có
    // chữ; TRẦN VẪN LÀ [kScreenTranslateMaxBlocks] (không nâng lên 64).
    final worthTranslating = <OcrBlock>[
      for (final block in paragraphs)
        if (hasTranslatableLetters(block.text) &&
            // AUDIT-1.21.0 #6: thanh địa chỉ / link trong trang không phải
            // nội dung cần dịch (trước đây overlay hiện nguyên URL như "bản
            // dịch" và đốt 1 request engine cho mỗi link).
            !isLinkOnlyText(block.text))
          block,
    ];

    // Mục 4: khối đang nằm trong viewport được dịch trước; phần dư trả về
    // `pendingBlocks` thay vì biến mất.
    //
    // Xếp hạng chạy trên ĐÚNG tập ĐÁNG dịch (mục 7.3): nếu xếp hạng cả khối
    // số/ký hiệu/link thì trên màn hình dày chữ chúng vẫn chiếm suất của trần
    // 32 ⇒ khối chữ thật rơi vào phần dư. Khối rác KHÔNG bị bỏ: nó vẫn có mặt
    // trong kết quả với bản dịch rỗng (native bỏ qua khi vẽ) như hành vi cũ,
    // chỉ là không tính vào hạn mức.
    final selection = rankBlocksForTranslate(
      worthTranslating,
      _maxBlocks,
      viewportTop: 0,
      viewportBottom: geometry.screenHeight,
    );
    final keptForTranslate = selection.selected.toSet();
    final worthSet = worthTranslating.toSet();
    // Giữ NGUYÊN thứ tự đọc của màn hình (trần 32 chỉ quyết định khối nào
    // được dịch, không đổi thứ tự trả về).
    final selected = <OcrBlock>[
      for (final block in paragraphs)
        if (keptForTranslate.contains(block) || !worthSet.contains(block)) block,
    ];
    final translatable = <int>[
      for (var i = 0; i < selected.length; i++)
        if (hasTranslatableLetters(selected[i].text) &&
            !isLinkOnlyText(selected[i].text))
          i,
    ];

    // Số khối CÓ CHỮ còn lại sau lượt này (đã trừ rác/link) — chip "còn N
    // khối · Dịch tiếp" ở native đọc đúng số này.
    final pendingBlocks = selection.pendingBlocks;
    if (translatable.isEmpty) {
      // Có khung chữ nhưng toàn số/ký hiệu ⇒ không có gì để dịch. Nói rõ
      // thay vì trả `ok` với màn hình trống.
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.noText,
        message: _t('Không thấy chữ nào cần dịch trên màn hình'),
        elapsed: stopwatch.elapsed,
        ocrBlocks: ocr.blocks.length,
      );
    }

    final out = List<ScreenBlock?>.filled(selected.length, null);

    // Khối KHÔNG có chữ cái (giờ, số, icon, ký hiệu) vẫn phải có mặt trong
    // kết quả với bản dịch rỗng: native bỏ qua khối rỗng khi vẽ (không tạo ô
    // trống) nhưng nhờ vậy bên gọi biết ĐỦ vị trí các khối đã nhận dạng thay
    // vì tưởng chúng biến mất. Trước đây các khối này bị loại khỏi danh sách
    // ⇒ test "khối chỉ có số/ký hiệu" bắt được (1 khối thay vì 2).
    final translatableSet = translatable.toSet();
    for (var i = 0; i < selected.length; i++) {
      if (translatableSet.contains(i)) continue;
      final block = selected[i];
      final rect = mapCaptureRectToOverlay(
        offsetOcrRect(block.rect, dx: offsetX, dy: offsetY),
        geometry,
      );
      out[i] = ScreenBlock(
        rect: rect,
        original: block.text,
        translation: '',
        textSizeSp: _blockTextSizeSp(rect, block.text, geometry),
      );
    }

    final missing = <String>{};
    final engines = <String>[];
    var anyTranslated = false;
    var doneCount = 0;

    // Gộp khối TRÙNG nội dung: một màn hình hay lặp nhãn ("Settings", "OK",
    // tên menu) — dịch 1 lần rồi dùng lại. Không chỉ nhanh hơn mà còn tránh
    // bị engine online rate-limit vì gửi cùng một câu 5 lần.
    final inflight = <String, Future<TranslationResult>>{};
    Future<TranslationResult> translateOnce(String text) {
      final key = text.trim();
      return inflight.putIfAbsent(
        key,
        () => _translateBlock(key, target, _sourceLanguage),
      );
    }

    Future<void> runOne(int index) async {
      final block = selected[index];
      final rect = mapCaptureRectToOverlay(
        offsetOcrRect(block.rect, dx: offsetX, dy: offsetY),
        geometry,
      );
      // PSRC-211: gửi cho engine CÂU đã nối lại, không phải các dòng bị màn
      // hình ngắt giữa chừng (`\n` của OCR). Xuống dòng THẬT (mục danh sách,
      // hết câu) vẫn giữ.
      final text = reflowOcrText(block.text);
      var translation = '';
      if (hasTranslatableLetters(text)) {
        try {
          final result = await translateOnce(text);
          if (result.isSuccess && result.translatedText.trim().isNotEmpty) {
            // Native vẽ mỗi `\n` thành một lần xuống dòng ⇒ bỏ dòng trống /
            // khoảng trắng thừa engine trả về, kẻo khung có khoảng trống.
            translation = normalizeOverlayText(result.translatedText);
            anyTranslated = true;
            if (engines.isEmpty) engines.add(result.engineName);
          } else {
            final codes = result.missingModelCodes;
            if (codes != null) missing.addAll(codes);
          }
        } catch (e) {
          debugPrint('❌ screen translate khối "$text": $e');
        }
      }
      out[index] = ScreenBlock(
        rect: rect,
        original: block.text,
        translation: translation,
        textSizeSp: _blockTextSizeSp(rect, block.text, geometry),
      );
      doneCount++;
      _report(
        ScreenTranslateStage.translating,
        done: doneCount,
        total: translatable.length,
        force: doneCount >= translatable.length,
      );
    }

    _report(
      ScreenTranslateStage.translating,
      done: 0,
      total: translatable.length,
    );

    // Hàng đợi có giới hạn: mỗi luồng lấy index kế tiếp rồi `await` — giữa
    // lúc đọc và tăng `next` không có `await` nên không thể trùng index.
    var next = 0;
    final workerCount = math.max(
      1,
      math.min(_concurrency, translatable.length),
    );
    Future<void> worker() async {
      while (true) {
        final slot = next;
        if (slot >= translatable.length) return;
        next = slot + 1;
        await runOne(translatable[slot]);
      }
    }

    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => worker()),
    );

    _report(ScreenTranslateStage.finishing);

    final rawBlocks = <ScreenBlock>[
      for (final block in out)
        if (block != null) block,
    ];

    // AUDIT-1.21.0 #1 (XLAT-SCR-005 hồi quy): bản dịch dài hơn chữ gốc ⇒
    // native trước đây phình ô xuống dưới, đè lên khối kế tiếp ⇒ chữ chồng
    // lên nhau khi dịch nhiều khối. Xếp chỗ ở Dart (thuần, có test) rồi native
    // chỉ vẽ ĐÚNG khung được cấp — không tự phình nữa.
    final blocks = layoutTranslatedBlocks(
      rawBlocks,
      screenWidth: geometry.screenWidth,
      screenHeight: geometry.screenHeight,
      devicePixelRatio: geometry.devicePixelRatio,
      // XLAT-SCR-006: cỡ chữ hệ thống. Native vẽ bằng `TypedValue(SP)` nên bỏ
      // qua tham số này ⇒ máy bật cỡ chữ lớn vẫn cấp thiếu chỗ ⇒ chữ bị cắt.
      fontScale: geometry.fontScale,
    );

    stopwatch.stop();

    // PSRC-211 — số liệu để truy "bỏ sót khối" trên máy thật (logcat): mỗi
    // bước của phễu OCR → gộp đoạn → chọn (trần [kScreenTranslateMaxBlocks])
    // → có chữ để dịch → dịch được → VẼ được. Hai số cuối lệch nhau = layout
    // phải bỏ khối vì hết chỗ.
    final translatedCount = rawBlocks.where((b) => b.hasTranslation).length;
    final drawnCount = blocks.where((b) => b.hasTranslation).length;
    debugPrint(
      'ℹ️ screen translate blocks: ocr=${ocr.blocks.length} '
      'paragraphs=${paragraphs.length} selected=${selected.length} '
      'translatable=${translatable.length} translated=$translatedCount '
      'drawn=$drawnCount pending=$pendingBlocks',
    );

    // Mục 4: ghi lại TOÀN BỘ phần dư (ĐÃ map sang toạ độ màn hình) để lượt
    // "Dịch tiếp" không phải chụp lại ảnh cũ. KHÔNG cắt ở đây: hạn mức
    // [kScreenTranslateMaxBlocks] áp cho MỖI lượt, còn hàng đợi phải giữ đủ
    // phần dư (70 khối ⇒ 32 dịch + 38 chờ; cắt ngay 32 thì 6 khối biến mất
    // sau lượt thứ hai — đúng lỗi "bỏ khối im lặng" mà mục 4 cấm).
    _pending = <PendingScreenBlock>[
      for (final block in selection.pending)
        PendingScreenBlock(
          rect: mapCaptureRectToOverlay(
            offsetOcrRect(block.rect, dx: offsetX, dy: offsetY),
            geometry,
          ),
          original: block.text,
          text: reflowOcrText(block.text),
          textSizeSp: _blockTextSizeSp(
            mapCaptureRectToOverlay(
              offsetOcrRect(block.rect, dx: offsetX, dy: offsetY),
              geometry,
            ),
            block.text,
            geometry,
          ),
        ),
    ];

    if (!anyTranslated && missing.isNotEmpty) {
      // Luật vàng: KHÔNG tự tải model. Nói rõ thiếu gì để user vào Cài đặt
      // dịch bấm "Tải về".
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.missingModel,
        blocks: blocks,
        message: _t('Chưa tải gói dịch ngoại tuyến cho ngôn ngữ này'),
        missingModelCodes: missing.toList(growable: false),
        elapsed: stopwatch.elapsed,
        pendingBlocks: pendingBlocks,
        ocrBlocks: ocr.blocks.length,
      );
    }
    if (!anyTranslated) {
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.error,
        blocks: blocks,
        message: _t('Dịch màn hình thất bại'),
        elapsed: stopwatch.elapsed,
        pendingBlocks: pendingBlocks,
        ocrBlocks: ocr.blocks.length,
      );
    }

    return ScreenTranslateResult(
      status: ScreenTranslateStatus.ok,
      blocks: blocks,
      engine: engines.isEmpty ? '' : engines.first,
      message: '',
      missingModelCodes: missing.toList(growable: false),
      elapsed: stopwatch.elapsed,
      // Mục 4: phần dư của trần 32 vẫn ĐẾM ĐƯỢC (native hiện "còn N khối ·
      // Dịch tiếp"), không bị bỏ vĩnh viễn.
      pendingBlocks: pendingBlocks,
      ocrBlocks: ocr.blocks.length,
    );
  }
}

/// Cỡ chữ gốc (sp) của một khối OCR: chiều cao MỘT dòng, đã chia `fontScale`.
///
/// PSRC-211: trước đây lấy chiều cao CẢ KHỐI và bỏ qua `fontScale` ⇒ đoạn văn
/// nhiều dòng bị gán 28sp, máy bật cỡ chữ lớn vẽ bản dịch to hơn chữ gốc.
/// `layoutTranslatedBlocks` tính lại đúng công thức này; giá trị ở đây là để
/// khối KHÔNG qua layout (frame giả, khối không dịch) vẫn mang số đúng.
double _blockTextSizeSp(
  OverlayRect rect,
  String ocrText,
  ScreenCaptureGeometry geometry,
) {
  return suggestedTextSizeSp(
    rect,
    geometry.devicePixelRatio,
    lineCount: countTextLines(ocrText),
    fontScale: geometry.fontScale,
  );
}

/// Khối chữ có gì để dịch không?
///
/// ML Kit trả cả khối chỉ có số/ký hiệu ("12:30", "▸", "--"). Dịch những khối
/// đó vừa vô nghĩa vừa tốn một request ⇒ bỏ qua. Dùng `\p{L}` (Unicode) để
/// chữ Hán/Cyrillic/Devanagari vẫn được tính.
bool hasTranslatableLetters(String text) =>
    text.trim().isNotEmpty && RegExp(r'\p{L}', unicode: true).hasMatch(text);

/// Kết quả chọn khối của MỘT lượt: phần dịch ngay + phần dư ĐẾM ĐƯỢC.
///
/// PSRC-211 vòng 2 (mục 4 của `L4-hub-tra-loi.md`): trần
/// [kScreenTranslateMaxBlocks] giữ nguyên, nhưng phần dư KHÔNG bị bỏ vĩnh
/// viễn — nó thành [pendingBlocks] để native hiện chip "còn N khối · Dịch
/// tiếp". Nhờ vậy không còn đường nào bỏ khối im lặng.
class ScreenBlockSelection {
  const ScreenBlockSelection({
    required this.selected,
    required this.pendingBlocks,
    this.pending = const <OcrBlock>[],
  });

  /// Khối dịch trong lượt này — GIỮ NGUYÊN thứ tự đọc của màn hình.
  final List<OcrBlock> selected;

  /// Số khối CÓ CHỮ còn lại, chưa dịch trong lượt này.
  final int pendingBlocks;

  /// Chính các khối đó, theo thứ tự ưu tiên của lượt kế tiếp.
  final List<OcrBlock> pending;

  bool get isEmpty => selected.isEmpty;
}

/// Chọn tối đa [maxBlocks] khối ĐÁNG dịch nhất, GIỮ thứ tự đọc.
///
/// Tiêu chí "đáng" (thứ tự ưu tiên, dừng ngay khi đủ):
///  1. Khối **đang nằm trong viewport** ([viewTop]..[viewBottom]) trước — dịch
///     cái người dùng đang nhìn thấy trước đã.
///  2. Rồi tới "diện tích khung × độ dài chữ" như cũ: khối to nhiều chữ là nội
///     dung chính, icon/nhãn một ký tự rơi xuống cuối.
///
/// [viewport] = null (mặc định) ⇒ chỉ xếp theo độ "đáng" như hành vi cũ; đây
/// là bản giữ tương thích của [rankBlocksForTranslate].
List<OcrBlock> selectBlocksToTranslate(List<OcrBlock> blocks, int maxBlocks) =>
    rankBlocksForTranslate(blocks, maxBlocks).selected;

/// Chọn khối cho MỘT lượt dịch + đếm phần dư (xem [ScreenBlockSelection]).
///
/// [viewport] là khung nhìn hiện tại theo pixel màn hình (thường là `0..screenHeight`);
/// truyền `null` để bỏ tiêu chí "đang nhìn thấy".
ScreenBlockSelection rankBlocksForTranslate(
  List<OcrBlock> blocks,
  int maxBlocks, {
  int? viewportTop,
  int? viewportBottom,
}) {
  if (blocks.isEmpty) {
    return const ScreenBlockSelection(
      selected: <OcrBlock>[],
      pendingBlocks: 0,
    );
  }
  if (maxBlocks <= 0) {
    // Hạn mức 0 = không dịch gì; vẫn ĐẾM phần dư (không được bỏ im lặng).
    final withLetters =
        blocks.where((b) => hasTranslatableLetters(b.text)).length;
    return ScreenBlockSelection(
      selected: const <OcrBlock>[],
      pendingBlocks: withLetters,
      pending: const <OcrBlock>[],
    );
  }
  if (blocks.length <= maxBlocks) {
    return ScreenBlockSelection(
      selected: List<OcrBlock>.of(blocks),
      pendingBlocks: 0,
    );
  }

  final top = viewportTop ?? 0;
  final bottom = viewportBottom;
  bool inViewport(OcrBlock block) =>
      bottom == null ||
      (block.rect.bottom > top && block.rect.top < bottom);

  // `index` phá thế hoà để kết quả ỔN ĐỊNH giữa hai lần chạy (không phụ thuộc
  // thứ tự của `sort` Dart khi điểm bằng nhau).
  final order = <OcrBlock, int>{
    for (var i = 0; i < blocks.length; i++) blocks[i]: i,
  };
  final ranked = List<OcrBlock>.of(blocks)
    ..sort((a, b) {
      final visibleA = inViewport(a);
      final visibleB = inViewport(b);
      if (visibleA != visibleB) return visibleA ? -1 : 1;
      final byWeight = _weight(b).compareTo(_weight(a));
      if (byWeight != 0) return byWeight;
      return order[a]!.compareTo(order[b]!);
    });

  final keep = ranked.take(maxBlocks).toSet();
  final selected = blocks.where(keep.contains).toList(growable: false);
  final pending = <OcrBlock>[
    for (final block in ranked)
      if (!keep.contains(block) && hasTranslatableLetters(block.text)) block,
  ];
  return ScreenBlockSelection(
    selected: selected,
    pendingBlocks: pending.length,
    pending: pending,
  );
}

int _weight(OcrBlock block) =>
    block.rect.width * block.rect.height * block.text.trim().length;
