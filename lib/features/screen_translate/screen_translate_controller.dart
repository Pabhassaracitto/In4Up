// lib/features/screen_translate/screen_translate_controller.dart
//
// Bộ não phía Dart của "dịch màn hình toàn hệ thống" (XLAT-SCR-002 · ADR-0011).
//
// Nguyên tắc kiến trúc (ADR-0011): CHỤP + VẼ ở native, HIỂU CHỮ + DỊCH ở Dart.
// File này KHÔNG biết gì về MediaProjection/WindowManager; nó chỉ nhận một
// frame pixel + hình học màn hình rồi trả về danh sách khối đã dịch.
//
// Nhờ vậy toàn bộ logic quyết định (debounce, cắt bớt khối, gom lỗi thiếu
// model, thông điệp i18n) test được trên host VM — sandbox không có Android.
//
// Tái dùng 100%:
//  - OCR: `OcrService.recognizeBitmapBlocks` (ML Kit Latin, cùng timeout/cancel).
//  - Dịch: `TranslationService.translateText` → cache → engine đang chọn.
//    KHÔNG có engine dịch thứ hai, KHÔNG tự tải model (luật vàng).

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

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

/// Bộ điều phối một lượt dịch màn hình.
class ScreenTranslateController {
  ScreenTranslateController({
    ScreenOcrRunner? ocrRunner,
    ScreenBlockTranslator? translator,
    CaptureGate? gate,
    int maxBlocks = kScreenTranslateMaxBlocks,
    String localeCode = 'vi',
  })  : _ocrRunner = ocrRunner ?? _defaultOcrRunner,
        _translator = translator ?? _defaultTranslator,
        _gate = gate ?? CaptureGate(),
        _maxBlocks = maxBlocks,
        _localeCode = localeCode;

  final ScreenOcrRunner _ocrRunner;
  final ScreenBlockTranslator _translator;
  final CaptureGate _gate;
  final int _maxBlocks;
  String _localeCode;

  /// Locale chrome hiện hành (UI engine gửi xuống khi bật service) — thông
  /// điệp overlay/notification phải theo locale đó, KHÔNG fallback `vi`
  /// (quy tắc vàng #5).
  set localeCode(String value) {
    if (value.trim().isNotEmpty) _localeCode = value.trim();
  }

  String get localeCode => _localeCode;

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

  static Future<TranslationResult> _defaultTranslator(
    String text,
    String targetLanguage,
  ) {
    return TranslationService().translateText(text, targetLang: targetLanguage);
  }

  /// Xử lý một frame thô từ native.
  ///
  /// Map bắt buộc có: `pixels` (Uint8List), `width`, `height`.
  /// Tuỳ chọn: `rowStride`, `alreadyBgra`, `screenWidth`, `screenHeight`,
  /// `devicePixelRatio`, `targetLanguage`, `locale`.
  Future<ScreenTranslateResult> handleFrame(Map<Object?, Object?> frame) async {
    final locale = frame['locale'];
    if (locale is String) localeCode = locale;

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

    final ocr = await _ocrRunner(
      pixels: normalized,
      width: geometry.captureWidth,
      height: geometry.captureHeight,
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
        ? targetRaw.trim().toUpperCase()
        : 'VI';

    final selected = selectBlocksToTranslate(ocr.blocks, _maxBlocks);
    final out = <ScreenBlock>[];
    final missing = <String>{};
    var engine = '';
    var anyTranslated = false;

    for (final block in selected) {
      final rect = mapCaptureRectToOverlay(block.rect, geometry);
      String translation = '';
      try {
        final result = await _translator(block.text, target);
        if (result.isSuccess && result.translatedText.trim().isNotEmpty) {
          translation = result.translatedText.trim();
          anyTranslated = true;
          if (engine.isEmpty) engine = result.engineName;
        } else {
          final codes = result.missingModelCodes;
          if (codes != null) missing.addAll(codes);
        }
      } catch (e) {
        debugPrint('❌ screen translate khối "${block.text}": $e');
      }
      out.add(
        ScreenBlock(
          rect: rect,
          original: block.text,
          translation: translation,
          textSizeSp: suggestedTextSizeSp(rect, geometry.devicePixelRatio),
        ),
      );
    }

    stopwatch.stop();

    if (!anyTranslated && missing.isNotEmpty) {
      // Luật vàng: KHÔNG tự tải model. Nói rõ thiếu gì để user vào Cài đặt
      // dịch bấm "Tải về".
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.missingModel,
        blocks: out,
        message: _t('Chưa tải gói dịch ngoại tuyến cho ngôn ngữ này'),
        missingModelCodes: missing.toList(growable: false),
        elapsed: stopwatch.elapsed,
      );
    }
    if (!anyTranslated) {
      return ScreenTranslateResult(
        status: ScreenTranslateStatus.error,
        blocks: out,
        message: _t('Dịch màn hình thất bại'),
        elapsed: stopwatch.elapsed,
      );
    }

    return ScreenTranslateResult(
      status: ScreenTranslateStatus.ok,
      blocks: out,
      engine: engine,
      message: '',
      missingModelCodes: missing.toList(growable: false),
      elapsed: stopwatch.elapsed,
    );
  }
}

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
