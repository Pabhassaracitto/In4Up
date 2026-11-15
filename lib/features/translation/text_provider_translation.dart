// ignore_for_file: unintended_html_in_doc_comment
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/language/app_language.dart';
import '../../models/text_item.dart';
import '../../services/storage_service.dart';
import '../tts/language_detector.dart';
import 'cache/translation_cache.dart';
import 'engines/translation_engine.dart';
import 'line_role_swap.dart';
import 'mixed_language_segmenter.dart';
import 'translation_display_mode.dart';
import 'translation_service.dart';
import 'translation_source_choice.dart';

mixin TranslationMixin on ChangeNotifier {
  TranslationDisplayMode _translationDisplayMode =
      TranslationDisplayMode.hidden;
  int _translationDocumentRevision = 0;
  int get translationDocumentRevision => _translationDocumentRevision;
  bool _blurTranslations = false;
  bool get blurTranslations => _blurTranslations;

  void setBlurTranslations(bool value) {
    if (_blurTranslations == value) return;
    _blurTranslations = value;
    final storage = StorageService();
    if (storage.isInitialized) {
      unawaited(storage.saveSetting('read_blur_translations', value));
    }
    notifyListeners();
  }

  void restoreBlurTranslations() {
    final storage = StorageService();
    if (storage.isInitialized) {
      _blurTranslations = storage.getSetting<bool>('read_blur_translations',
              defaultValue: false) ?? false;
    }
  }

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

  /// PSRC-238: chuỗi lỗi «nguồn trùng đích» gần nhất. So `identical` với
  /// [_translationError] ⇒ mọi chỗ xoá / ghi đè lỗi tự động tắt gợi ý, không
  /// phải nhớ hạ thêm một cờ riêng.
  String? _samePairErrorText;

  /// Seam test: nơi lưu ngôn ngữ nguồn đã chọn theo tài liệu. Production để
  /// null (dùng Hive qua `StorageService`).
  @visibleForTesting
  RoleSwapMarkerStore? translationSourceStoreForTest;

  RoleSwapMarkerStore get _translationSources =>
      translationSourceStoreForTest ?? const _HiveTranslationSourceStore();

  /// Seam test cho lane translation: thay singleton bằng instance
  /// `TranslationService.forTest` có engine giả. Production để null.
  @visibleForTesting
  TranslationService? translationServiceForTest;

  TranslationService get _translationService =>
      translationServiceForTest ?? TranslationService();

  List<TextItem> get lines;

  // ==================== PSRC-237 / ADR-0031 — ĐỔI VAI ====================
  //
  // IPA, tô màu loại từ, CEFR, chạm tra từ chỉ chạy trên `content`. Văn bản
  // bản xứ đã dịch sang tiếng Anh thì tiếng Anh nằm ở `translation` ⇒ không
  // công cụ nào với tới. «Đổi vai» hoán đổi hai trường đó cho từng dòng đã
  // dịch; văn bản GỐC được giữ ở dòng dịch và đổi lại được nguyên vẹn.

  /// Thông báo khi một thao tác bị chặn để BẢO VỆ văn bản gốc (đang nằm ở
  /// dòng dịch): đổi ngôn ngữ / dịch lại sẽ ghi đè lên nó.
  static const String roleSwapGuardMessage =
      'Đang đổi vai — hãy đổi lại trước khi đổi ngôn ngữ hoặc dịch lại.';

  LineRoleSwapState? _roleSwap;

  /// Seam test: nơi lưu dấu đổi vai theo tài liệu. Production để null
  /// (dùng Hive qua `StorageService`).
  @visibleForTesting
  RoleSwapMarkerStore? roleSwapMarkerStoreForTest;

  RoleSwapMarkerStore get _roleSwapMarkers =>
      roleSwapMarkerStoreForTest ?? const _HiveRoleSwapMarkerStore();

  /// True khi `content` đang là BẢN DỊCH (máy) và văn bản gốc nằm ở dòng dịch.
  bool get rolesSwapped => _roleSwap != null;

  LineRoleSwapState? get roleSwapState => _roleSwap;

  /// Ngôn ngữ của bản dịch đang được dùng làm văn bản chính (null khi
  /// không đổi vai).
  AppLanguage? get roleSwapPromotedLanguage {
    final swap = _roleSwap;
    return swap == null ? null : AppLanguageCatalog.fromCode(swap.promotedCode);
  }

  /// Khoá tài liệu để lưu dấu đổi vai. `null` = không lưu (văn bản dán tay
  /// không có danh tính bền). `TextProvider` override.
  @protected
  String? get roleSwapDocumentKey => null;

  /// Hook: `content` của nhiều dòng vừa bị thay ⇒ lớp chủ phân tích lại từ
  /// loại, dựng lại toàn văn… Gọi TRƯỚC `notifyListeners`.
  @protected
  void onLineRolesSwapped() {}

  /// Số dòng đổi vai được ngay lúc này.
  int get roleSwappableLineCount => countSwappableLines(
        lines,
        _roleSwap?.originalCode ?? translationTargetLanguage.translationCode,
      );

  /// Có thể bấm «Đổi vai» / «Đổi lại» hay không.
  bool get canSwapRoles {
    if (_isTranslating || lines.isEmpty) return false;
    // Đếm dòng trước (rẻ); chỉ chạy bộ nhận diện ngôn ngữ khi thật sự có
    // bản dịch để đổi.
    if (roleSwappableLineCount == 0) return false;
    return _roleSwap != null || !translationPairUsesSameLanguage;
  }

  /// Đổi vai văn bản ⇄ bản dịch; gọi lần nữa để đổi lại.
  ///
  /// Trả `null` khi không làm gì (đang dịch, chưa có bản dịch, cặp trùng).
  ///
  /// Đi kèm với việc hoán đổi dòng:
  ///   * đích dịch của service đổi theo (chỉ trong bộ nhớ — KHÔNG ghi cài
  ///     đặt chung của app; mở tài liệu khác thì trả lại đích cũ);
  ///   * nguồn dịch được GẮN vào ngôn ngữ vừa đưa lên, để cặp ngôn ngữ
  ///     không phụ thuộc bộ nhận diện trên văn bản dịch máy;
  ///   * dấu đổi vai được lưu theo tài liệu (xem [restoreSavedRoleSwap]).
  LineRoleSwapResult? swapTextAndTranslationRoles() {
    if (_isTranslating || lines.isEmpty) return null;
    final current = _roleSwap;
    final String fromCode;
    final String toCode;
    if (current == null) {
      // Tính nguồn TRƯỚC khi thay dòng: nó được nhận diện từ nội dung.
      fromCode = translationTargetLanguage.translationCode;
      toCode = translationSourceLanguage.translationCode;
    } else {
      fromCode = current.originalCode;
      toCode = current.promotedCode;
    }
    if (fromCode == toCode) return null;

    final result = swapLineRoles(lines, fromCode: fromCode, toCode: toCode);
    if (result.swapped == 0) {
      if (current != null) {
        // Văn bản gốc không còn trong bộ nhớ (vd đã tách dòng lại) ⇒ thôi
        // coi là đang đổi vai, không để nút «Đổi lại» treo vô dụng.
        clearRoleSwapState();
        notifyListeners();
        return result;
      }
      return null;
    }

    // Vô hiệu mọi lượt dịch đơn dòng còn đang bay.
    _translationRunId++;
    for (var index = 0; index < lines.length; index++) {
      lines[index] = result.lines[index];
    }
    _translationService.configure(targetLang: toCode);
    if (current == null) {
      _roleSwap = LineRoleSwapState(
        promotedCode: fromCode,
        originalCode: toCode,
        swappedLines: result.swapped,
        previousPinnedSourceCode: _pinnedTranslationSourceCode,
      );
      _pinnedTranslationSourceCode = fromCode;
      final key = roleSwapDocumentKey;
      if (key != null) _roleSwapMarkers.write(key, _roleSwap!.encode());
    } else {
      _roleSwap = null;
      _pinnedTranslationSourceCode = current.previousPinnedSourceCode;
      final key = roleSwapDocumentKey;
      if (key != null) _roleSwapMarkers.remove(key);
    }
    _translationError = null;
    // Widget dòng dịch khoá theo revision ⇒ dựng lại sạch với nội dung mới.
    _translationDocumentRevision++;
    onLineRolesSwapped();
    notifyListeners();
    return result;
  }

  /// Bỏ trạng thái đổi vai mà KHÔNG hoán đổi dòng (dùng khi nội dung đã bị
  /// thay bằng cách khác, vd «Tách dòng tự động»). Trả đích dịch về như cũ.
  /// Không tự `notifyListeners`.
  @protected
  void clearRoleSwapState() {
    final current = _roleSwap;
    if (current == null) return;
    final key = roleSwapDocumentKey;
    if (key != null) _roleSwapMarkers.remove(key);
    dropRoleSwapState();
    // PSRC-238: vẫn là tài liệu đó ⇒ trả lại nguồn người dùng đã chọn trước
    // khi đổi vai (đổi vai chỉ MƯỢN chỗ gắn nguồn).
    _pinnedTranslationSourceCode = current.previousPinnedSourceCode;
  }

  /// Rời tài liệu đang đổi vai: bỏ trạng thái trong bộ nhớ, trả đích dịch
  /// về như người dùng đã chọn, nhưng GIỮ dấu đã lưu để lần mở lại tài liệu
  /// đó còn tự đổi vai. Không tự `notifyListeners`.
  @protected
  void dropRoleSwapState() {
    final current = _roleSwap;
    if (current == null) return;
    _roleSwap = null;
    _pinnedTranslationSourceCode = null;
    _translationService.configure(targetLang: current.promotedCode);
  }

  /// Mở lại tài liệu từng đổi vai ⇒ tự đổi vai lại. CHỈ làm khi bản dịch ở
  /// ngôn ngữ đã đưa lên có ĐỦ như lúc lưu (không dựng ra tài liệu nửa nọ
  /// nửa kia) và đích dịch hiện tại vẫn là ngôn ngữ đó.
  bool restoreSavedRoleSwap() {
    if (_roleSwap != null || _isTranslating || lines.isEmpty) return false;
    final key = roleSwapDocumentKey;
    if (key == null) return false;
    final saved = LineRoleSwapState.decode(_roleSwapMarkers.read(key));
    if (saved == null) return false;
    if (translationTargetLanguage.translationCode != saved.promotedCode) {
      return false;
    }
    if (countSwappableLines(lines, saved.promotedCode) < saved.swappedLines) {
      return false;
    }
    return swapTextAndTranslationRoles() != null;
  }

  /// Chặn thao tác sẽ ghi đè văn bản gốc khi đang đổi vai. Trả true nếu đã
  /// chặn (và đã báo lý do qua [translationError]).
  bool _blockedByRoleSwap() {
    if (_roleSwap == null) return false;
    _translationError = roleSwapGuardMessage;
    notifyListeners();
    return true;
  }

  TranslationDisplayMode get translationDisplayMode => _translationDisplayMode;
  bool get isTranslating => _isTranslating;
  double get translationProgress => _translationProgress;
  String? get translationError => _translationError;
  String get currentEngine => _currentEngine;

  /// Engine đang chạy (qua TranslationService) — UI hiện đúng nhãn
  /// "Đang dịch bằng Hy-MT offline, có thể chậm" khi Hy-MT đang xử lý
  /// (HYMT-002). `null` = không có engine chạy.
  ValueNotifier<String?> get translationEngineNotifier =>
      TranslationService().activeEngineNotifier;

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
  ///
  /// PSRC-238: lựa chọn được LƯU theo tài liệu (file / cloud) và tự gắn lại
  /// khi mở lại tài liệu đó — xem [restoreSavedTranslationSource]. Văn bản
  /// dán tay không có danh tính bền ⇒ chỉ sống trong phiên.
  Future<bool> setTranslationSourceLanguage(
    String code, {
    bool retranslateExisting = true,
  }) async {
    // PSRC-237: đang đổi vai ⇒ đổi nguồn sẽ xoá dòng dịch = xoá văn bản GỐC.
    if (_blockedByRoleSwap()) return false;
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
    final key = roleSwapDocumentKey;
    if (key != null) {
      if (newCode == null) {
        _translationSources.remove(key);
      } else {
        _translationSources.write(key, newCode);
      }
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

  bool get translationPairUsesSameLanguage =>
      translationSourceLanguage.translationCode ==
      translationTargetLanguage.translationCode;

  // ============ PSRC-238 / ADR-0031 (3b) — CHỌN NGUỒN, TRÁNH CẶP TRÙNG ============

  /// Vừa nạp một tài liệu ⇒ dùng ngôn ngữ nguồn người dùng đã chọn CHO NÓ:
  /// mở lại tài liệu cũ thì gắn lại lựa chọn đã lưu; tài liệu chưa từng chọn
  /// (hoặc văn bản dán tay, không có khoá lưu) thì về «Tự nhận diện» — nguồn
  /// của tài liệu trước không được kéo sang.
  ///
  /// KHÔNG xoá bản dịch và KHÔNG dịch lại (bản dịch đã lưu vốn được tạo với
  /// chính nguồn này). Phải gọi SAU khi lớp chủ biết danh tính tài liệu và
  /// TRƯỚC khi tô lại bản dịch từ cache / khôi phục «Đổi vai» — cả hai đều
  /// đọc nguồn hiệu dụng. Không tự `notifyListeners`; trả true nếu có đổi.
  bool restoreSavedTranslationSource() {
    // Đang đổi vai ⇒ chỗ gắn nguồn đang được mượn; không đụng vào.
    if (_roleSwap != null) return false;
    final key = roleSwapDocumentKey;
    final saved = key == null
        ? null
        : decodeSavedTranslationSource(_translationSources.read(key));
    if (saved == _pinnedTranslationSourceCode) return false;
    _pinnedTranslationSourceCode = saved;
    return true;
  }

  /// Dựng lại các dòng của CÙNG một tài liệu (sửa nội dung, bật / tắt tách
  /// dòng) mà không làm rơi nguồn đã chọn. Cần cho văn bản dán tay: nó không
  /// có khoá lưu nên không khôi phục được bằng [restoreSavedTranslationSource].
  @protected
  void reparseKeepingTranslationSource(void Function() reparse) {
    final swap = _roleSwap;
    final kept = swap == null
        ? _pinnedTranslationSourceCode
        : swap.previousPinnedSourceCode;
    reparse();
    _pinnedTranslationSourceCode = kept;
  }

  /// True khi lượt bấm «Dịch» gần nhất dừng lại vì nguồn trùng đích và cặp
  /// vẫn đang trùng. Giao diện dùng nó để ĐỀ NGHỊ một đích khác thay cho
  /// dòng lỗi đỏ.
  bool get translationBlockedBySamePair {
    final error = _translationError;
    return error != null &&
        identical(error, _samePairErrorText) &&
        translationPairUsesSameLanguage;
  }

  /// Ngôn ngữ đích nên đề nghị khi nguồn trùng đích (không bao giờ trùng
  /// nguồn hiệu dụng). [uiLanguageCode] = ngôn ngữ giao diện của app.
  AppLanguage suggestedTranslationTarget({String? uiLanguageCode}) =>
      suggestTargetAvoidingSource(
        source: translationSourceLanguage,
        uiLanguageCode: uiLanguageCode,
      );

  /// Áp MỘT lần cả nguồn lẫn đích (bảng chọn ngôn ngữ trả về cả hai khi
  /// người dùng vừa đổi nguồn vừa nhận đích được đề nghị).
  ///
  /// [sourceCode] / [targetCode] null = giữ nguyên. Bản dịch cũ bị xoá khi có
  /// thay đổi và chỉ được dịch lại MỘT lượt, sau khi cả hai đã vào chỗ —
  /// không dịch dở với cặp trung gian. Trả true nếu có ít nhất một thay đổi.
  Future<bool> setTranslationLanguagePair({
    String? sourceCode,
    String? targetCode,
    bool retranslateExisting = true,
  }) async {
    // Đang đổi vai ⇒ đổi cặp sẽ xoá dòng dịch = xoá văn bản GỐC.
    if (_blockedByRoleSwap()) return false;
    final hadTranslations = lines.any(
      (line) => line.translation != null && line.translation!.trim().isNotEmpty,
    );
    var changed = false;
    if (sourceCode != null) {
      changed = await setTranslationSourceLanguage(
            sourceCode,
            retranslateExisting: false,
          ) ||
          changed;
    }
    if (targetCode != null) {
      changed = await setTranslationTargetLanguage(
            targetCode,
            retranslateExisting: false,
          ) ||
          changed;
    }
    if (changed &&
        retranslateExisting &&
        hadTranslations &&
        !translationPairUsesSameLanguage) {
      unawaited(translateAll(forceRetranslate: true));
    }
    return changed;
  }

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
    // PSRC-237: đang đổi vai ⇒ đổi đích sẽ xoá dòng dịch = xoá văn bản GỐC.
    if (_blockedByRoleSwap()) return false;
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

  /// XLAT-MIX-001 (audit 1.h) — dòng này có mẩu nào KHÁC ngôn ngữ đích
  /// không? Dùng để không chặn oan tài liệu lẫn lộn Việt–Anh khi ngôn ngữ
  /// nguồn của cả tài liệu bị nhận diện trùng ngôn ngữ đích.
  bool _lineNeedsTranslation(
    String content, {
    required AppLanguage lineSource,
    required AppLanguage target,
    required AppLanguage documentSource,
  }) {
    if (lineSource.translationCode != target.translationCode) return true;
    return containsForeignSegment(
      content,
      target: target,
      fallback: documentSource,
    );
  }

  /// Tài liệu còn ít nhất một dòng đáng dịch sang [target] hay không.
  bool _documentNeedsTranslation(AppLanguage source, AppLanguage target) {
    for (final line in lines) {
      final content = line.content;
      if (content.trim().isEmpty) continue;
      if (_lineNeedsTranslation(
        content,
        lineSource: _lineSourceFor(content, source),
        target: target,
        documentSource: source,
      )) {
        return true;
      }
    }
    return false;
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
        targetLang: targetCode,
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
    // PSRC-237: dịch lại một dòng khi đang đổi vai sẽ ghi đè văn bản gốc.
    if (_blockedByRoleSwap()) return;

    final service = _translationService;
    final source = translationSourceLanguage;
    final target = translationTargetLanguage;
    final lineSource = _lineSourceFor(line.content, source);
    // XLAT-MIX-001: xét NGÔN NGỮ CỦA DÒNG (và các mẩu trong dòng), không
    // xét ngôn ngữ gộp của cả tài liệu — dòng tiếng Anh nằm trong tài liệu
    // tiếng Việt vẫn phải dịch được.
    if (!_lineNeedsTranslation(
      line.content,
      lineSource: lineSource,
      target: target,
      documentSource: source,
    )) {
      _translationError = _samePairErrorText =
          'Ngôn ngữ nguồn và ngôn ngữ đích đang giống nhau.';
      notifyListeners();
      return;
    }
    final runId = _translationRunId;
    TranslationService().activeEngineNotifier.value = null;
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
    // PSRC-237: đang đổi vai ⇒ dòng dịch là văn bản GỐC, không dịch đè lên.
    // «Dịch lại tất cả» (ý định rõ ràng) được báo lý do; lượt dịch nền tự
    // động (phát song ngữ…) thì im lặng bỏ qua.
    if (_roleSwap != null) {
      if (forceRetranslate) _blockedByRoleSwap();
      return;
    }

    final service = _translationService;
    final source = translationSourceLanguage;
    final target = translationTargetLanguage;
    final sameAsTarget = source.translationCode == target.translationCode;
    // XLAT-MIX-001 (audit 1.h): chỉ từ chối khi THẬT SỰ không còn gì để
    // dịch. Tài liệu lẫn lộn Việt–Anh bị gộp mẫu thành "VI" vẫn phải dịch
    // được các dòng/mẩu tiếng Anh sang tiếng Việt.
    if (sameAsTarget && !_documentNeedsTranslation(source, target)) {
      // PSRC-238: vẫn ghi chuỗi lỗi (màn hình khác còn đọc nó), nhưng đánh
      // dấu để thanh dịch đề nghị một đích khác thay vì dừng ở dòng đỏ.
      _translationError = _samePairErrorText =
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
      if (sameAsTarget &&
          !_lineNeedsTranslation(
            line.content,
            lineSource: _lineSourceFor(line.content, source),
            target: target,
            documentSource: source,
          )) {
        // Dòng đã ở ngôn ngữ đích và không lẫn ngoại ngữ — bỏ qua thay vì
        // ghi bản dịch trùng nguyên văn.
        continue;
      }
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
    // HYMT-002: hint engine sạch cho run mới (engine sẽ tự set khi chạy).
    service.activeEngineNotifier.value = null;
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
    TranslationService().activeEngineNotifier.value = null;
    notifyListeners();
  }

  void clearAllTranslations() {
    // PSRC-237: đang đổi vai ⇒ «bản dịch» cần xoá là bản dịch MÁY đang ở
    // `content`. Đổi lại trước, rồi mới xoá — văn bản gốc không bao giờ mất.
    if (_roleSwap != null) {
      _isTranslating = false;
      swapTextAndTranslationRoles();
    }
    _translationRunId++;
    _isTranslating = false;
    // Qua seam `_translationService` (production vẫn là singleton) để hàm
    // này test được mà không dựng engine thật.
    _translationService.activeEngineNotifier.value = null;
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
    _translationDocumentRevision++;
    _translationRunId++;
    _isTranslating = false;
    _translationProgress = 0;
    _translationError = null;
    _currentEngine = '';
    _appliedPipelineTag = null;
    _translationDisplayMode = TranslationDisplayMode.hidden;
    // Nguồn explicit gắn cho tài liệu CŨ không kéo sang tài liệu mới.
    _pinnedTranslationSourceCode = null;
    // PSRC-237: đổi vai chỉ MƯỢN đích dịch cho một tài liệu ⇒ rời tài liệu
    // thì trả đích về như người dùng đã chọn. Dấu đã lưu được giữ nguyên để
    // lần mở lại tài liệu đó còn tự đổi vai.
    dropRoleSwapState();
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
    // PSRC-237: đang đổi vai ⇒ dòng thiếu «bản dịch» là dòng chưa từng dịch;
    // không tô gì lên đó.
    if (_roleSwap != null) return 0;
    final revision = _translationDocumentRevision;
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
    // PSRC-237: tài liệu này lần trước đọc ở dạng đổi vai ⇒ đổi vai lại
    // (chỉ khi vẫn là tài liệu đó và bản dịch đã về đủ).
    if (hits > 0 && revision == _translationDocumentRevision) {
      restoreSavedRoleSwap();
    }
    return hits;
  }
}

/// Lưu dấu đổi vai vào hộp cài đặt Hive (qua `StorageService`). Chưa khởi
/// tạo storage (test, web sớm) ⇒ im lặng bỏ qua.
class _HiveRoleSwapMarkerStore implements RoleSwapMarkerStore {
  const _HiveRoleSwapMarkerStore();

  @override
  String? read(String documentKey) {
    final storage = StorageService();
    if (!storage.isInitialized) return null;
    final raw = storage.getSetting<dynamic>(roleSwapStorageKey(documentKey));
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  @override
  void write(String documentKey, String value) {
    final storage = StorageService();
    if (!storage.isInitialized) return;
    unawaited(storage.saveSetting(roleSwapStorageKey(documentKey), value));
  }

  @override
  void remove(String documentKey) {
    final storage = StorageService();
    if (!storage.isInitialized) return;
    unawaited(storage.saveSetting(roleSwapStorageKey(documentKey), ''));
  }
}

/// PSRC-238: lưu ngôn ngữ nguồn người dùng đã chọn cho từng tài liệu vào hộp
/// cài đặt Hive. Chưa khởi tạo storage (test, web sớm) ⇒ im lặng bỏ qua.
class _HiveTranslationSourceStore implements RoleSwapMarkerStore {
  const _HiveTranslationSourceStore();

  @override
  String? read(String documentKey) {
    final storage = StorageService();
    if (!storage.isInitialized) return null;
    final raw =
        storage.getSetting<dynamic>(translationSourceStorageKey(documentKey));
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  @override
  void write(String documentKey, String value) {
    final storage = StorageService();
    if (!storage.isInitialized) return;
    unawaited(
      storage.saveSetting(translationSourceStorageKey(documentKey), value),
    );
  }

  @override
  void remove(String documentKey) {
    final storage = StorageService();
    if (!storage.isInitialized) return;
    unawaited(
      storage.saveSetting(translationSourceStorageKey(documentKey), ''),
    );
  }
}
