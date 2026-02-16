// lib/features/DeepLX/text_provider_translation.dart
// ★ SỬA TOÀN BỘ FILE NÀY

import 'dart:async';
import 'package:flutter/foundation.dart';

// ★ XÓA DÒNG CŨ:
// import '../../features/deeplx/deeplx_service.dart';

// ★ THAY BẰNG:
import '../translation/translation_service.dart';

import '../../models/text_item.dart';
import 'translation_display_mode.dart';

mixin TranslationMixin on ChangeNotifier {
  // ── STATE (giữ nguyên) ──
  TranslationDisplayMode _translationDisplayMode =
      TranslationDisplayMode.hidden;
  TranslationDisplayMode get translationDisplayMode => _translationDisplayMode;

  bool _isTranslating = false;
  bool get isTranslating => _isTranslating;

  double _translationProgress = 0.0;
  double get translationProgress => _translationProgress;

  String? _translationError;
  String? get translationError => _translationError;

  // ★ THÊM: Engine đang dùng
  String _currentEngine = '';
  String get currentEngine => _currentEngine;

  int get translatedLineCount => lines
      .where((l) => l.translation != null && l.translation!.isNotEmpty)
      .length;

  List<TextItem> get lines;

  // ── METHODS ──

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
    if (_translationDisplayMode != mode) {
      _translationDisplayMode = mode;
      notifyListeners();
    }
  }

  Future<void> translateLine(int index) async {
    if (index < 0 || index >= lines.length) return;

    final line = lines[index];
    if (line.content.trim().isEmpty) return;

    // ★ ĐỔI: DeepLXService.translateText → TranslationService().translateText
    final result = await TranslationService().translateText(line.content);

    if (result.isSuccess) {
      lines[index] = line.copyWith(translation: result.translatedText);
      _currentEngine = TranslationService().lastUsedEngine;
      notifyListeners();
    }
  }

  Future<void> translateAll({bool forceRetranslate = false}) async {
    if (_isTranslating) return;

    final toTranslate = <int>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.content.trim().isEmpty) continue;
      if (!forceRetranslate &&
          line.translation != null &&
          line.translation!.isNotEmpty) {
        continue;
      }
      toTranslate.add(i);
    }

    if (toTranslate.isEmpty) {
      if (_translationDisplayMode == TranslationDisplayMode.hidden) {
        _translationDisplayMode = TranslationDisplayMode.stackedBelow;
      }
      notifyListeners();
      return;
    }

    _isTranslating = true;
    _translationProgress = 0.0;
    _translationError = null;
    notifyListeners();

    int consecutiveErrors = 0;

    try {
      for (int i = 0; i < toTranslate.length; i++) {
        if (!_isTranslating) break;

        final lineIndex = toTranslate[i];
        final line = lines[lineIndex];

        // ★ ĐỔI: DeepLXService → TranslationService
        final result = await TranslationService().translateText(line.content);

        if (result.isSuccess && result.translatedText.isNotEmpty) {
          lines[lineIndex] = line.copyWith(translation: result.translatedText);
          _currentEngine = TranslationService().lastUsedEngine;
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

        _translationProgress = (i + 1) / toTranslate.length;
        notifyListeners();

        if (i < toTranslate.length - 1) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }

      if (_translationDisplayMode == TranslationDisplayMode.hidden) {
        _translationDisplayMode = TranslationDisplayMode.stackedBelow;
      }
    } catch (e) {
      _translationError = e.toString();
    } finally {
      _isTranslating = false;
      _translationProgress = 1.0;
      notifyListeners();
    }
  }

  void cancelTranslation() {
    _isTranslating = false;
    notifyListeners();
  }

  void clearAllTranslations() {
    for (int i = 0; i < lines.length; i++) {
      lines[i] = lines[i].copyWith(translation: null);
    }
    _translationDisplayMode = TranslationDisplayMode.hidden;
    _currentEngine = '';
    notifyListeners();
  }
}
