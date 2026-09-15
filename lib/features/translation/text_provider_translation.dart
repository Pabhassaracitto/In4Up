// ignore_for_file: unintended_html_in_doc_comment
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/language/app_language.dart';
import '../../models/text_item.dart';
import '../../services/storage_service.dart';
import '../tts/language_detector.dart';
import 'cache/translation_cache.dart';
import 'engines/translation_engine.dart';
import 'translation_display_mode.dart';
import 'translation_service.dart';

mixin TranslationMixin on ChangeNotifier {
  TranslationDisplayMode _translationDisplayMode =
      TranslationDisplayMode.hidden;
  bool _isTranslating = false;
  double _translationProgress = 0.0;
  String? _translationError;
  String _currentEngine = '';
  int _translationRunId = 0;
  String? _appliedPipelineTag;

  /// Nguồn dịch EXPLICIT user đã gắn (translation code, vd 'EN');
  /// null = chế độ AUTO (nhận diện tự động).
  ///
  /// XLAT-MLKIT-001: khi đã gắn nguồn, mọi dòng dùng đúng nguồn đó — không
  /// re-detect từng dòng (câu ngắn dễ bị detector nhầm, vd EN → 'DE', rồi
  /// báo "Chưa tải gói dịch german" dù user chọn EN→VI). Chỉ AUTO mới
  /// re-detect từng dòng cho tài liệu hỗn hợp ngôn ngữ.
  String? _pinnedTranslationSourceCode;

  /// Seam test cho lane translation: thay singleton bằng instance
  /// `TranslationService.forTest` có engine giả. Production để null.
  @visibleForTesting
  TranslationService? translationServiceForTest;

  TranslationService get _translationService =>
      translationServiceForTest ?? TranslationService();

  List<TextItem> get lines;

  TranslationDisplayMode get translationDisplayMode => _translationDisplayMode;
  bool get isTranslating => _isTranslating;
  double get translationProgress => _translationProgress;
  String? get translationError => _translationError;
  String get currentEngine => _currentEngine;

  bool get translationPipelineStale {
    final current = _translationService.pipelineTag;
    return _appliedPipelineTag != null && _appliedPipelineTag != current;
  }

  /// Rebuild toolbar after engine/offline-only settings change.
  void refreshTranslationChrome() => notifyListeners();

  AppLanguage get translationTargetLanguage =>
      _translationService.targetLanguage;

  AppLanguage get detectedSourceLanguage {
    final sample = lines
        .where((line) => line.content.trim().isNotEmpty)
        .take(24)
        .map((line) => line.content)
        .join(' ');
    return LanguageDetector.detectLanguage(sample);
  }

  /// Nguồn dịch hiệu dụng của tài liệu: nguồn user GẮN (explicit) nếu có,
  /// ngược lại kết quả nhận diện tự động theo mẫu nội dung.
  AppLanguage get translationSourceLanguage =>
      _pinnedTranslationSourceCode == null
          ? detectedSourceLanguage
          : AppLanguageCatalog.fromCode(_pinnedTranslationSourceCode);

  /// True khi user đã gắn nguồn explicit (≠ AUTO).
  bool get translationSourceIsPinned => _pinnedTranslationSourceCode != null;

  /// Gắn nguồn dịch explicit cho tài liệu hiện tại.
  ///
  /// - 'AUTO' (hoặc rỗng) → bỏ gắn, quay lại nhận diện tự động.
  /// - Code hợp lệ trong catalog → gắn nguồn cho TẤT CẢ dòng (không
  ///   re-detect từng dòng, không retry bằng ngôn ngữ khác).
  /// - Code không có trong catalog → return false, không đổi gì.
  ///
  /// Đổi nguồn sẽ xoá bản dịch cũ và dịch lại như [setTranslationTargetLanguage].
  /// Nguồn gắn là state phiên/tài liệu (reset bởi [resetTranslationForNewDocument]);
  /// chưa lưu bền vững — việc lưu + UI chọn nguồn thuộc lane khác.
  Future<bool> setTranslationSourceLanguage(
    String code, {
    bool retranslateExisting = true,
  }) async {
    final normalized = code.trim().replaceAll('_', '-').toUpperCase();
    final isAuto = normalized.isEmpty || normalized == 'AUTO';
    final language =
        isAuto ? null : AppLanguageCatalog.maybeFromCode(normalized);
    if (!isAuto && language == null) return false;
    final newCode = language?.translationCode;
    if (newCode == _pinnedTranslationSourceCode) return false;

    final hadTranslations = lines.any(
      (line) => line.translation != null && line.translation!.trim().isNotEmpty,
    );

    _translationRunId++;
    _isTranslating = false;
    _translationProgress = 0;
    _translationError = null;
    _pinnedTranslationSourceCode = newCode;
    for (var index = 0; index < lines.length; index++) {
      lines[index] = lines[index].copyWith(clearTranslation: true);
    }
    notifyListeners();

    if (retranslateExisting &&
        hadTranslations &&
        !translationPairUsesSameLanguage) {
      unawaited(translateAll(forceRetranslate: true));
    }
    return true;
  }

  bool get translationPairUsesSameLanguage =>
      translationSourceLanguage.translationCode ==
      translationTargetLanguage.translationCode;

  int get translatedLineCount {
    final target = translationTargetLanguage.translationCode;
    return lines.where((line) {
      if (line.translation == null || line.translation!.trim().isEmpty) {
        return false;
      }
      // Legacy imported bilingual lines had no metadata and were VI.
      final lineTarget = line.translationLanguageCode ?? 'VI';
      return AppLanguageCatalog.normalizeTranslationCode(lineTarget) == target;
    }).length;
  }

  void restoreTranslationTargetLanguage(String code) {
    _translationService.configure(targetLang: code);
  }

  Future<bool> setTranslationTargetLanguage(
    String code, {
    bool retranslateExisting = true,
  }) async {
    final language = AppLanguageCatalog.maybeFromCode(code);
    if (language == null) return false;

    final service = _translationService;
    if (service.targetLang == language.translationCode) return false;

    final hadTranslations = lines.any(
      (line) => line.translation != null && line.translation!.trim().isNotEmpty,
    );

    _translationRunId++;
    _isTranslating = false;
    _translationProgress = 0;
    _translationError = null;
    service.configure(targetLang: language.translationCode);
    final storage = StorageService();
    if (storage.isInitialized) {
      await storage.saveTranslationTargetLanguage(language.translationCode);
    }

    for (var index = 0; index < lines.length; index++) {
      lines[index] = lines[index].copyWith(clearTranslation: true);
    }
    notifyListeners();

    if (retranslateExisting &&
        hadTranslations &&
        !translationPairUsesSameLanguage) {
      unawaited(translateAll(forceRetranslate: true));
    }
    return true;
  }

  void cycleTranslationMode() {
    switch (_translationDisplayMode) {
      case TranslationDisplayMode.hidden:
        _translationDisplayMode = TranslationDisplayMode.stackedBelow;
        break;
      case TranslationDisplayMode.stackedBelow:
        _translationDisplayMode = TranslationDisplayMode.sideBySide;
        break;
      case TranslationDisplayMode.sideBySide:
        _translationDisplayMode = TranslationDisplayMode.hidden;
        break;
    }
    notifyListeners();
  }

  void setTranslationDisplayMode(TranslationDisplayMode mode) {
    if (_translationDisplayMode == mode) return;
    _translationDisplayMode = mode;
    notifyListeners();
  }

  /// Nguồn của MỘT dòng. Chế độ AUTO (không gắn nguồn) re-detect từng dòng
  /// với fallback = nguồn tài liệu (hỗ trợ tài liệu hỗn hợp ngôn ngữ).
  /// Nguồn explicit dùng đúng nguồn đã gắn cho mọi dòng — KHÔNG re-detect
  /// (XLAT-MLKIT-001: không để câu ngắn đổi tài liệu EN thành DE).
  AppLanguage _lineSourceFor(String content, AppLanguage documentSource) {
    if (translationSourceIsPinned) return documentSource;
    return LanguageDetector.detectLanguage(content, fallback: documentSource);
  }

  /// Dịch 1 dòng qua service. Chế độ AUTO: nếu dòng bị nhận diện nhầm sang
  /// ngôn ngữ khác nguồn tài liệu và model của ngôn ngữ vừa nhận diện chưa
  /// tải (missingModelCodes) → retry ĐÚNG 1 LẦN với nguồn tài liệu trước khi
  /// chấp nhận lỗi. Nguồn explicit KHÔNG BAO GIỜ retry bằng ngôn ngữ khác.
  Future<(TranslationResult, AppLanguage)> _translateLineContent(
    TranslationService service, {
    required String content,
    required AppLanguage documentSource,
    required AppLanguage lineSource,
    required String targetCode,
    required bool skipCache,
  }) async {
    var result = await service.translateText(
      content,
      sourceLang: lineSource.translationCode,
      targetLang: targetCode,
      skipCache: skipCache,
    );
    var appliedSource = lineSource;
    if (!result.isSuccess &&
        !translationSourceIsPinned &&
        lineSource.translationCode != documentSource.translationCode &&
        (result.missingModelCodes ?? const <String>[])
            .contains(lineSource.translationCode)) {
      final retry = await service.translateText(
        content,
        sourceLang: documentSource.translationCode,
        targetCode: targetCode,
        skipCache: skipCache,
      );
      if (retry.isSuccess && retry.translatedText.trim().isNotEmpty) {
        result = retry;
        appliedSource = documentSource;
      }
    }
    return (result, appliedSource);
  }

  /// Lỗi dịch có cấu trúc: khi model của NGUỒN thiếu, phân biệt "nguồn tự
  /// nhận diện" (chế độ AUTO — user nên kiểm tra lại ngôn ngữ nguồn) với
  /// "cặp nguồn đã chọn" (explicit — không đổi ngôn ngữ âm thầm).
  String _translationErrorFor(
    TranslationResult result, {
    required AppLanguage lineSource,
  }) {
    final base = '${result.engineName}: ${result.error}';
    final missing = result.missingModelCodes;
    if (missing == null ||
        missing.isEmpty ||
        !missing.contains(lineSource.translationCode)) {
      return base;
    }
    return translationSourceIsPinned
        ? '$base (cặp nguồn đã chọn)'
        : '$base (nguồn tự nhận diện — kiểm tra lại ngôn ngữ nguồn)';
  }

  Future<void> translateLine(int index) async {
    if (index < 0 || index >= lines.length) return;
    final line = lines[index];
    if (line.content.trim().isEmpty) return;

    final service = _translationService;
    final source = translationSourceLanguage;
    final target = translationTargetLanguage;
    if (source.translationCode == target.translationCode) {
      _translationError =
          'Ngôn ngữ nguồn và ngôn ngữ đích đang giống nhau.';
      notifyListeners();
      return;
    }

    final lineSource = _lineSourceFor(line.content, source);
    final runId = _translationRunId;
    final (result, appliedSource) = await _translateLineContent(
      service,
      content: line.content,
      documentSource: source,
      lineSource: lineSource,
      targetCode: target.translationCode,
      skipCache: true,
    );

    if (runId != _translationRunId || index >= lines.length) return;
    if (service.targetLang != target.translationCode) return;

    if (result.isSuccess && result.translatedText.trim().isNotEmpty) {
      lines[index] = line.copyWith(
        translation: result.translatedText,
        sourceLanguageCode:
            result.detectedLang ?? appliedSource.translationCode,
        translationLanguageCode: target.translationCode,
      );
      _currentEngine = service.lastUsedEngine;
      _appliedPipelineTag = service.pipelineTag;
      _translationError = null;
    } else {
      _translationError = _translationErrorFor(result, lineSource: lineSource);
    }
    notifyListeners();
  }

  Future<void> translateAll({bool forceRetranslate = false}) async {
    if (_isTranslating) return;

    final service = _translationService;
    final source = translationSourceLanguage;
    final target = translationTargetLanguage;
    if (source.translationCode == target.translationCode) {
      _translationError =
          '${source.flag} ${source.nativeName} đã là ngôn ngữ đích. '
          'Hãy chọn một ngôn ngữ khác.';
      notifyListeners();
      return;
    }

    final targetCode = target.translationCode;
    final pipelineTag = service.pipelineTag;
    final pipelineChanged = _appliedPipelineTag != null &&
        _appliedPipelineTag != pipelineTag;
    final force = forceRetranslate || pipelineChanged;
    final toTranslate = <int>[];
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      if (line.content.trim().isEmpty) continue;
      final existingTarget = line.translationLanguageCode == null
          ? 'VI'
          : AppLanguageCatalog.normalizeTranslationCode(
              line.translationLanguageCode,
            );
      final hasCurrentTranslation = line.translation != null &&
          line.translation!.trim().isNotEmpty &&
          existingTarget == targetCode;
      if (!force && hasCurrentTranslation) continue;
      toTranslate.add(index);
    }

    if (toTranslate.isEmpty) {
      _appliedPipelineTag = pipelineTag;
      if (_translationDisplayMode == TranslationDisplayMode.hidden) {
        _translationDisplayMode = TranslationDisplayMode.stackedBelow;
      }
      notifyListeners();
      return;
    }

    final runId = ++_translationRunId;
    _isTranslating = true;
    _translationProgress = 0;
    _translationError = null;
    notifyListeners();

    var consecutiveErrors = 0;
    var doneCount = 0;
    const notifyEvery = 5;

    try {
      for (var position = 0; position < toTranslate.length; position++) {
        if (!_isTranslating || runId != _translationRunId) break;
        if (service.targetLang != targetCode) break;

        final lineIndex = toTranslate[position];
        if (lineIndex >= lines.length) continue;
        final line = lines[lineIndex];
        final lineSource = _lineSourceFor(line.content, source);
        final (result, appliedSource) = await _translateLineContent(
          service,
          content: line.content,
          documentSource: source,
          lineSource: lineSource,
          targetCode: targetCode,
          skipCache: force,
        );

        if (runId != _translationRunId || service.targetLang != targetCode) {
          break;
        }
        if (lineIndex < lines.length) {
          if (result.isSuccess && result.translatedText.trim().isNotEmpty) {
            lines[lineIndex] = line.copyWith(
              translation: result.translatedText,
              sourceLanguageCode:
                  result.detectedLang ?? appliedSource.translationCode,
              translationLanguageCode: targetCode,
            );
            _currentEngine = service.lastUsedEngine;
            consecutiveErrors = 0;
          } else {
            _translationError = _translationErrorFor(
              result,
              lineSource: lineSource,
            );
            consecutiveErrors++;
            if (consecutiveErrors >= 5) {
              _translationError =
                  'Dừng sau 5 lỗi liên tiếp. Kiểm tra kết nối mạng.';
              break;
            }
          }
        }

        doneCount++;
        _translationProgress = doneCount / toTranslate.length;
        final isLast = position == toTranslate.length - 1;
        if (isLast || doneCount % notifyEvery == 0) notifyListeners();

        if (!isLast) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }

      if (_translationDisplayMode == TranslationDisplayMode.hidden &&
          translatedLineCount > 0) {
        _translationDisplayMode = TranslationDisplayMode.stackedBelow;
      }

      // Issue2: tự động lưu translations vào cache/cloud sau khi dịch xong
      try {
        // Gọi qua dynamic để tránh import cycle với TextProvider
        final self = this as dynamic;
        if (self.saveCurrentTranslationsToCloud != null) {
          await self.saveCurrentTranslationsToCloud();
        }
      } catch (e) {
        debugPrint('⚠️ auto-save translations error: $e');
      }
    } catch (error) {
      _translationError = error.toString();
    } finally {
      if (runId == _translationRunId) {
        _isTranslating = false;
        _translationProgress = doneCount / toTranslate.length;
        _appliedPipelineTag = pipelineTag;
        notifyListeners();
      }
    }
  }

  void cancelTranslation() {
    _translationRunId++;
    _isTranslating = false;
    notifyListeners();
  }

  void clearAllTranslations() {
    _translationRunId++;
    _isTranslating = false;
    for (var index = 0; index < lines.length; index++) {
      lines[index] = lines[index].copyWith(clearTranslation: true);
    }
    _translationDisplayMode = TranslationDisplayMode.hidden;
    _translationProgress = 0;
    _translationError = null;
    _currentEngine = '';
    _appliedPipelineTag = null;
    notifyListeners();
  }

  /// Handover fix cho issue 1 & 2: khi load tài liệu mới (AI -> Cloud) phải reset
  /// translation state để tránh black screen do runId cũ còn chạy, và để chuẩn bị
  /// lưu translations mới.
  void resetTranslationForNewDocument() {
    _translationRunId++;
    _isTranslating = false;
    _translationProgress = 0;
    _translationError = null;
    _currentEngine = '';
    _appliedPipelineTag = null;
    _translationDisplayMode = TranslationDisplayMode.hidden;
    // Nguồn explicit gắn cho tài liệu CŨ không kéo sang tài liệu mới.
    _pinnedTranslationSourceCode = null;
    // Không notify ở đây — caller sẽ notify sau khi parse lines
  }

  /// Lưu translations hiện tại vào cache để issue 2 không phải dịch lại
  /// Trả về Map<lineIndex, translation>
  Map<int, String> exportCurrentTranslations() {
    final map = <int, String>{};
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].translation;
      if (t != null && t.trim().isNotEmpty) {
        map[i] = t;
      }
    }
    return map;
  }

  /// After reopen: paint saved translations onto lines (no network).
  Future<int> rehydrateTranslationsFromCache() async {
    if (lines.isEmpty) return 0;
    final cache = TranslationCache();
    final target = translationTargetLanguage.translationCode;
    var hits = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.content.trim().isEmpty) continue;
      if (line.translation != null && line.translation!.trim().isNotEmpty) {
        continue;
      }
      final source = _lineSourceFor(line.content, translationSourceLanguage);
      final cached = await cache.get(
        text: line.content,
        sourceLang: source.translationCode,
        targetLang: target,
        engine: _translationService.pipelineTag,
      );
      if (cached == null || cached.trim().isEmpty) continue;
      lines[i] = line.copyWith(
        translation: cached,
        sourceLanguageCode: source.translationCode,
        translationLanguageCode: target,
      );
      hits++;
    }
    if (hits > 0) {
      _appliedPipelineTag = _translationService.pipelineTag;
      if (_translationDisplayMode == TranslationDisplayMode.hidden) {
        _translationDisplayMode = TranslationDisplayMode.stackedBelow;
      }
      notifyListeners();
    }
    debugPrint('[Translation] rehydrated $hits/${lines.length} lines from cache');
    return hits;
  }
}
