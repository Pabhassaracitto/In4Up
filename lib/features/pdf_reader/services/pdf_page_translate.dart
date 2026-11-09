// lib/features/pdf_reader/services/pdf_page_translate.dart
//
// Phần "não" của Dịch màn hình trong PDF Reader (PLAN-035 · KANBAN XLAT-SCR-001).
//
// Vì sao tách ra file riêng: controller sẽ gọi TranslationService (online/
// offline engine chain) — thứ không chạy được trên host VM. Toàn bộ logic
// trình tự (progress, dừng sau N lỗi liên tiếp, nhả giữa hai câu) sống ở đây
// với translator TIÊM VÀO, nên test thuần Dart được (mirror cách
// `pdf_tts_machine.dart` tách state machine khỏi TtsService).
//
// Hành vi mirror `TranslationMixin.translateAll`: dịch TUẦN TỰ (engine online
// cần throttle; Hy-MT isolate chỉ nhận 1 câu/lượt), dừng sau 5 lỗi liên tiếp
// thay vì đốt cả trăm request chết. Cache dịch nằm ở TranslationService —
// translation closure gọi vào đó thì lật lại trang gần như miễn phí.
//
// Hai nguồn "seed" (câu chờ dịch):
//  1. PDF có lớp chữ: `PdfSentenceCue` từ `extractSentences` (có toạ độ câu).
//  2. Trang scan: text OCR phẳng → `splitOcrTextIntoUnits` (không toạ độ).

import 'dart:ui' show Rect;

import '../models/pdf_page_translation.dart';
import '../models/pdf_sentence_cue.dart';

/// Dịch một chuỗi. Trả về bản dịch, hoặc null khi thất bại (closure quyết
/// định "thất bại" là gì — TranslationService: `result.isSuccess == false`).
typedef PdfSentenceTranslator = Future<String?> Function(String text);

/// Số lỗi liên tiếp tối đa trước khi dừng cả trang (mirror translateAll).
const int kPdfPageTranslateMaxConsecutiveFailures = 5;

/// Ngắt quãng giữa hai câu — hạ throttle cho engine online, nhả UI isolate.
const Duration kPdfPageTranslateDelay = Duration(milliseconds: 150);

/// Câu của trang (có lớp chữ) → seed chờ dịch. Chỉ giữ cue dùng được
/// (`isUsable` — có chữ + có rect để nâng cấp overlay sau này không phải đổi).
List<PdfPageSentenceTranslation> cuesToTranslationSeeds(
  int pageIndex,
  List<PdfSentenceCue> cues,
) {
  return [
    for (final cue in cues)
      if (cue.isUsable)
        PdfPageSentenceTranslation(
          pageIndex: pageIndex,
          original: cue.speakText,
          bounds: cue.bounds,
        ),
  ];
}

/// Text OCR của một trang scan → seed chờ dịch (toạ độ Rect.zero: OCR
/// phẳng không có vị trí câu).
List<PdfPageSentenceTranslation> ocrTextToTranslationSeeds(
  int pageIndex,
  String ocrText,
) {
  return [
    for (final unit in splitOcrTextIntoUnits(ocrText))
      PdfPageSentenceTranslation(
        pageIndex: pageIndex,
        original: unit,
        bounds: Rect.zero,
      ),
  ];
}

/// Tách văn bản OCR (trang scan không có lớp chữ) thành các đơn vị dịch.
///
/// OCR chỉ cho text phẳng. Quy tắc:
/// - ngắt theo DÒNG TRỐNG (paragraph break) — giữ ngữ cảnh trong đoạn;
/// - đoạn dài hơn [maxUnitLength] gom theo CÂU (dấu `. ! ? …`) thành các unit
///   ≤ budget — không nhét nửa trang vào một request dịch (engine online có
///   giới hạn độ dài, Hy-MT phải chunk nội bộ);
/// - câu đơn dài hơn budget (không có dấu chấm) cắt cứng tại budget — tốt hơn
///   để engine chết vì request khổng lồ;
/// - dòng trống/thẻ khoảng trắng bị bỏ.
///
/// Thuần Dart, không phụ thuộc OCR thật — test bằng chuỗi thường.
List<String> splitOcrTextIntoUnits(
  String text, {
  int maxUnitLength = 480,
}) {
  final units = <String>[];
  final paragraphs = text
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);

  for (final paragraph in paragraphs) {
    if (paragraph.length <= maxUnitLength) {
      units.add(paragraph);
      continue;
    }
    final sentences = paragraph
        .replaceAll(RegExp(r'\s+'), ' ')
        .split(RegExp(r'(?<=[.!?…])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .expand((s) => _hardSplitLong(s, maxUnitLength));

    final buffer = StringBuffer();
    for (final sentence in sentences) {
      if (buffer.isNotEmpty &&
          buffer.length + sentence.length + 1 > maxUnitLength) {
        units.add(buffer.toString().trim());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(sentence);
      if (buffer.length >= maxUnitLength) {
        units.add(buffer.toString().trim());
        buffer.clear();
      }
    }
    final rest = buffer.toString().trim();
    if (rest.isNotEmpty) units.add(rest);
  }
  return units;
}

/// Câu đơn dài hơn budget (không có dấu chấm — vd bảng, kệ dài): cắt cứng
/// theo budget — tốt hơn để engine dịch chết vì request khổng lồ. Không mất
/// ký tự: ghép các phần lại bằng đúng chuỗi gốc.
Iterable<String> _hardSplitLong(String sentence, int maxUnitLength) sync* {
  if (sentence.length <= maxUnitLength) {
    yield sentence;
    return;
  }
  for (var start = 0; start < sentence.length; start += maxUnitLength) {
    final end = start + maxUnitLength > sentence.length
        ? sentence.length
        : start + maxUnitLength;
    yield sentence.substring(start, end);
  }
}

/// Dịch các seed của MỘT trang, tuần tự, có progress + điểm dừng.
///
/// [shouldStop] cho caller hủy từ ngoài (đổi trang, đóng panel, dịch lại).
Future<PdfPageTranslateReport> translatePdfPageUnits({
  required int pageIndex,
  required List<PdfPageSentenceTranslation> seeds,
  required PdfSentenceTranslator translate,
  void Function(int done, int total)? onProgress,
  bool Function()? shouldStop,
  Duration delayBetween = kPdfPageTranslateDelay,
  int maxConsecutiveFailures = kPdfPageTranslateMaxConsecutiveFailures,
}) async {
  if (seeds.isEmpty) {
    return const PdfPageTranslateReport(
      translations: [],
      translatedCount: 0,
      failedCount: 0,
    );
  }

  final results = <PdfPageSentenceTranslation>[];
  var translated = 0;
  var failed = 0;
  var consecutiveFailures = 0;
  String? lastError;

  for (var i = 0; i < seeds.length; i++) {
    if (shouldStop?.call() ?? false) {
      return PdfPageTranslateReport(
        translations: results,
        translatedCount: translated,
        failedCount: failed,
        stoppedEarly: true,
        error: lastError,
      );
    }

    final seed = seeds[i];
    String? translation;
    try {
      translation = await translate(seed.original);
    } catch (_) {
      translation = null;
    }

    final ok = translation != null && translation.trim().isNotEmpty;
    results.add(seed.copyWith(translation: ok ? translation!.trim() : null));

    if (ok) {
      translated++;
      consecutiveFailures = 0;
    } else {
      failed++;
      consecutiveFailures++;
      lastError = 'translate_failed';
    }

    onProgress?.call(i + 1, seeds.length);

    if (consecutiveFailures >= maxConsecutiveFailures) {
      return PdfPageTranslateReport(
        translations: results,
        translatedCount: translated,
        failedCount: failed,
        stoppedEarly: true,
        error: lastError,
      );
    }

    if (i < seeds.length - 1 && delayBetween > Duration.zero) {
      await Future<void>.delayed(delayBetween);
    }
  }

  return PdfPageTranslateReport(
    translations: results,
    translatedCount: translated,
    failedCount: failed,
    error: lastError,
  );
}
