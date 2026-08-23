import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/language/app_language.dart';
import '../../models/text_item.dart';
import '../../services/storage_service.dart';
import '../tts/language_detector.dart';
import 'cache/translation_cache.dart';
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

  List<TextItem> get lines;

  TranslationDisplayMode get translationDisplayMode => _translationDisplayMode;
  bool get isTranslating => _isTranslating;
  double get translationProgress => _translationProgress;
  String? get translationError => _translationError;
  String get currentEngine => _currentEngine;

  AppLanguage get translationTargetLanguage =>
      TranslationService().targetLanguage;

  AppLanguage get detectedSourceLanguage {
    final sample = lines
        .where((line) => line.content.trim().isNotEmpty)
        .take(24)
        .map((line) => line.content)
        .join(' ');
    return LanguageDetector.detectLanguage(sample);
  }

  bool get translationPairUsesSameLanguage =>
      detectedSourceLanguage.translationCode ==
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
    TranslationService().configure(targetLang: code);
  }

  Future<bool> setTranslationTargetLanguage(
    String code, {
    bool retranslateExisting = true,
  }) async {
    final language = AppLanguageCatalog.maybeFromCode(code);
    if (language == null) return false;

    final service = TranslationService();
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

  Future<void> translateLine(int index) async {
    if (index < 0 || index >= lines.length) return;
    final line = lines[index];
    if (line.content.trim().isEmpty) return;

    final source = detectedSourceLanguage;
    final target = translationTargetLanguage;
    if (source.translationCode == target.translationCode) {
      _translationError =
          'Ngôn ngữ nguồn và ngôn ngữ đích đang giống nhau.';
      notifyListeners();
      return;
    }

    final lineSource = LanguageDetector.detectLanguage(
      line.content,
      fallback: source,
    );
    final runId = _translationRunId;
    final result = await TranslationService().translateText(
      line.content,
      sourceLang: lineSource.translationCode,
      targetLang: target.translationCode,
    );

    if (runId != _translationRunId || index >= lines.length) return;
    if (TranslationService().targetLang != target.translationCode) return;

    if (result.isSuccess && result.translatedText.trim().isNotEmpty) {
      lines[index] = line.copyWith(
        translation: result.translatedText,
        sourceLanguageCode: result.detectedLang ?? lineSource.translationCode,
        translationLanguageCode: target.translationCode,
      );
      _currentEngine = TranslationService().lastUsedEngine;
      _translationError = null;
    } else {
      _translationError = '${result.engineName}: ${result.error}';
    }
    notifyListeners();
  }

  Future<void> translateAll({bool forceRetranslate = false}) async {
    if (_isTranslating) return;

    final service = TranslationService();
    final source = detectedSourceLanguage;
    final target = translationTargetLanguage;
    if (source.translationCode == target.translationCode) {
      _translationError =
          '${source.flag} ${source.nativeName} đã là ngôn ngữ đích. '
          'Hãy chọn một ngôn ngữ khác.';
      notifyListeners();
      return;
    }

    final targetCode = target.translationCode;
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
      if (!forceRetranslate && hasCurrentTranslation) continue;
      toTranslate.add(index);
    }

    if (toTranslate.isEmpty) {
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
        final lineSource = LanguageDetector.detectLanguage(
          line.content,
          fallback: source,
        );
        final result = await service.translateText(
          line.content,
          sourceLang: lineSource.translationCode,
          targetLang: targetCode,
        );

        if (runId != _translationRunId || service.targetLang != targetCode) {
          break;
        }
        if (lineIndex < lines.length) {
          if (result.isSuccess && result.translatedText.trim().isNotEmpty) {
            lines[lineIndex] = line.copyWith(
              translation: result.translatedText,
              sourceLanguageCode:
                  result.detectedLang ?? lineSource.translationCode,
              translationLanguageCode: targetCode,
            );
            _currentEngine = service.lastUsedEngine;
            consecutiveErrors = 0;
          } else {
            _translationError = '${result.engineName}: ${result.error}';
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
    _translationDisplayMode = TranslationDisplayMode.hidden;
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
      final source = LanguageDetector.detectLanguage(line.content);
      final cached = await cache.get(
        text: line.content,
        sourceLang: source.translationCode,
        targetLang: target,
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
      if (_translationDisplayMode == TranslationDisplayMode.hidden) {
        _translationDisplayMode = TranslationDisplayMode.stackedBelow;
      }
      notifyListeners();
    }
    debugPrint('[Translation] rehydrated $hits/${lines.length} lines from cache');
    return hits;
  }
}
