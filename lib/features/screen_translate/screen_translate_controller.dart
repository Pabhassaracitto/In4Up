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
import '../translation/translation_service.dart';
import 'screen_translate_geometry.dart';
import 'screen_translate_models.dart';

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

    final selected = selectBlocksToTranslate(ocr.blocks, _maxBlocks);
    final translatable = <int>[
      for (var i = 0; i < selected.length; i++)
        if (hasTranslatableLetters(selected[i].text)) i,
    ];
    if (translatable.isEmpty) {
      // Có khung chữ nhưng toàn số/ký hiệu ⇒ không có gì để dịch. Nói rõ
      // thay vì trả `ok` với màn hình trống.
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.noText,
        message: _t('Không thấy chữ nào cần dịch trên màn hình'),
        elapsed: stopwatch.elapsed,
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
        textSizeSp: suggestedTextSizeSp(rect, geometry.devicePixelRatio),
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
      final text = block.text.trim();
      var translation = '';
      if (hasTranslatableLetters(text)) {
        try {
          final result = await translateOnce(text);
          if (result.isSuccess && result.translatedText.trim().isNotEmpty) {
            translation = result.translatedText.trim();
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
        textSizeSp: suggestedTextSizeSp(rect, geometry.devicePixelRatio),
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

    final blocks = <ScreenBlock>[
      for (final block in out)
        if (block != null) block,
    ];

    stopwatch.stop();

    if (!anyTranslated && missing.isNotEmpty) {
      // Luật vàng: KHÔNG tự tải model. Nói rõ thiếu gì để user vào Cài đặt
      // dịch bấm "Tải về".
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.missingModel,
        blocks: blocks,
        message: _t('Chưa tải gói dịch ngoại tuyến cho ngôn ngữ này'),
        missingModelCodes: missing.toList(growable: false),
        elapsed: stopwatch.elapsed,
      );
    }
    if (!anyTranslated) {
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.error,
        blocks: blocks,
        message: _t('Dịch màn hình thất bại'),
        elapsed: stopwatch.elapsed,
      );
    }

    return ScreenTranslateResult(
      status: ScreenTranslateStatus.ok,
      blocks: blocks,
      engine: engines.isEmpty ? '' : engines.first,
      message: '',
      missingModelCodes: missing.toList(growable: false),
      elapsed: stopwatch.elapsed,
    );
  }
}

/// Khối chữ có gì để dịch không?
///
/// ML Kit trả cả khối chỉ có số/ký hiệu ("12:30", "▸", "--"). Dịch những khối
/// đó vừa vô nghĩa vừa tốn một request ⇒ bỏ qua. Dùng `\p{L}` (Unicode) để
/// chữ Hán/Cyrillic/Devanagari vẫn được tính.
bool hasTranslatableLetters(String text) =>
    text.trim().isNotEmpty && RegExp(r'\p{L}', unicode: true).hasMatch(text);

/// Chọn tối đa [maxBlocks] khối ĐÁNG dịch nhất, GIỮ thứ tự đọc.
///
/// Tiêu chí "đáng": diện tích khung × độ dài chữ — khối to và nhiều chữ là
/// nội dung chính; icon/nhãn một ký tự rơi xuống cuối.
List<OcrBlock> selectBlocksToTranslate(List<OcrBlock> blocks, int maxBlocks) {
  if (maxBlocks <= 0) return const <OcrBlock>[];
  if (blocks.length <= maxBlocks) return List<OcrBlock>.of(blocks);

  final ranked = List<OcrBlock>.of(blocks)
    ..sort((a, b) => _weight(b).compareTo(_weight(a)));
  final keep = ranked.take(maxBlocks).toSet();
  return blocks.where(keep.contains).toList(growable: false);
}

int _weight(OcrBlock block) =>
    block.rect.width * block.rect.height * block.text.trim().length;
