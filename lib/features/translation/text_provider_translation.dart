// ★ FIX: translateAll - throttle notifyListeners để tránh quá nhiều rebuild đồng thời

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/text_item.dart';
import 'translation_display_mode.dart';
import 'translation_service.dart';

mixin TranslationMixin on ChangeNotifier {
  // ── STATE ──
  TranslationDisplayMode _translationDisplayMode =
      TranslationDisplayMode.hidden;
  TranslationDisplayMode get translationDisplayMode => _translationDisplayMode;

  bool _isTranslating = false;
  bool get isTranslating => _isTranslating;

  double _translationProgress = 0.0;
  double get translationProgress => _translationProgress;

  String? _translationError;
  String? get translationError => _translationError;

  String _currentEngine = '';
  String get currentEngine => _currentEngine;

  double _columnRatio = 0.65; // Mặc định 65/35
  double get columnRatio => _columnRatio;

  bool _showWordSpaces = true; // Mặc định có dấu cách
  bool get showWordSpaces => _showWordSpaces;

  int get translatedLineCount => lines
      .where((l) => l.translation != null && l.translation!.isNotEmpty)
      .length;

  List<TextItem> get lines;

  // ── METHODS ──

  void setColumnRatio(double ratio) {
    if (_columnRatio != ratio) {
      _columnRatio = ratio;
      notifyListeners();
    }
  }

  void toggleShowWordSpaces(bool value) {
    if (_showWordSpaces != value) {
      _showWordSpaces = value;
      notifyListeners();
    }
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
    if (_translationDisplayMode != mode) {
      _translationDisplayMode = mode;
      notifyListeners();
    }
  }

  Future<void> translateLine(int index) async {
    if (index < 0 || index >= lines.length) return;

    final line = lines[index];
    if (line.content.trim().isEmpty) return;

    final result = await TranslationService().translateText(line.content);

    if (result.isSuccess) {
      // ★ FIX: Guard index lại sau khi await (lines có thể đã thay đổi)
      if (index < lines.length) {
        lines[index] = line.copyWith(translation: result.translatedText);
        _currentEngine = TranslationService().lastUsedEngine;
        notifyListeners();
      }
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

    // ★ FIX: Throttle — chỉ notify mỗi N dòng thay vì mỗi dòng
    // Tránh hàng chục notifyListeners() liên tiếp gây rebuild toàn bộ ListView
    // Tăng lên 5 hoặc 10 nếu danh sách rất dài để mượt hơn nữa
    const notifyEvery = 5;
    int doneCount = 0;

    try {
      for (int i = 0; i < toTranslate.length; i++) {
        if (!_isTranslating) break;

        final lineIndex = toTranslate[i];

        // ★ FIX: Guard — lines có thể đã thay đổi sau mỗi await
        if (lineIndex >= lines.length) continue;

        final line = lines[lineIndex];
        final result = await TranslationService().translateText(line.content);

        // ★ FIX: Guard lại sau await
        if (lineIndex < lines.length) {
          if (result.isSuccess && result.translatedText.isNotEmpty) {
            lines[lineIndex] =
                line.copyWith(translation: result.translatedText);
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
        }

        doneCount++;
        _translationProgress = doneCount / toTranslate.length;

        // ★ FIX: Throttle notify — không notify mỗi dòng
        final isLastItem = i == toTranslate.length - 1;
        if (isLastItem || doneCount % notifyEvery == 0) {
          notifyListeners();
        }

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
      // ★ FIX: Chỉ notify 1 lần duy nhất khi hoàn tất
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
