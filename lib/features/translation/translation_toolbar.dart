// ignore_for_file: use_build_context_synchronously, deprecated_member_use
// lib/features/translation/translation_toolbar.dart
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:in4up_ai/in4up_ai.dart';
import 'package:provider/provider.dart';

import '../../core/language/app_language.dart';
import '../../providers/text_provider.dart';
import '../../screens/read_mode/services/playback_controller.dart';
import 'engines/deeplx_endpoint.dart';
import 'engines/deeplx_engine.dart';
import 'engines/hymt_engine.dart';
import 'engines/mlkit_engine.dart';
import 'glossary/glossary_sheet.dart';
import 'mlkit_pack_catalog.dart';
import 'mlkit_pack_downloads.dart';
import 'translation_display_mode.dart';
import 'translation_language_picker.dart';
import 'translation_service.dart';

/// SHELL-GEAR-001: seam log điểm nhấn gear "Cài đặt engine dịch" (ứng viên
/// gear #2 trong card — gear #1 là drawer "Giao diện shell" ở main_shell).
/// `Listener` là raw pointer listener — KHÔNG tham gia gesture arena, KHÔNG
/// đổi hành vi nút (tap mở sheet, giữ hiện tooltip như cũ). Logcat
/// `grep SHELL-GEAR-001` cho biết owner đang giữ đúng gear nào và bao lâu
/// (down→up ≥ 500ms = long-press) để đối chứng hypothesis orphaned Ink
/// trước khi cân nhắc thay InkWell bằng highlight tự vẽ.
void _shellGearPointerLog(String phase) {
  if (kDebugMode) {
    debugPrint('[SHELL-GEAR-001] translation-toolbar-gear: pointer-$phase');
  }
}

class TranslationToolbar extends StatelessWidget {
  final Color primaryColor;

  const TranslationToolbar({
    super.key,
    this.primaryColor = const Color(0xFF6C63FF),
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TextProvider>(
      builder: (context, textProvider, _) {
        final isTranslating = textProvider.isTranslating;
        final hasTranslations = textProvider.translatedLineCount > 0;
        final displayMode = textProvider.translationDisplayMode;
        final progress = textProvider.translationProgress;
        final sourceLanguage = textProvider.detectedSourceLanguage;
        final targetLanguage = textProvider.translationTargetLanguage;
        final sameLanguage = textProvider.translationPairUsesSameLanguage;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            border: Border(
              bottom: BorderSide(
                color: primaryColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final translateButton = _TranslateButton(
                    isTranslating: isTranslating,
                    hasTranslations: hasTranslations,
                    pipelineStale: textProvider.translationPipelineStale,
                    primaryColor: primaryColor,
                    progress: progress,
                    totalLines: textProvider.lines.length,
                    translatedLines: textProvider.translatedLineCount,
                    requiresLanguageChoice: sameLanguage,
                    onTap: () async {
                      if (isTranslating) {
                        textProvider.cancelTranslation();
                      } else if (sameLanguage) {
                        await _selectTargetLanguage(context, textProvider);
                      } else {
                        await textProvider.translateAll(
                          forceRetranslate:
                              textProvider.translationPipelineStale,
                        );
                      }
                    },
                    onLongPress: () =>
                        _showTranslationOptions(context, textProvider),
                  );
                  final languageButton = TranslationLanguagePickerButton(
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    accentColor: primaryColor,
                    onSelected: (language) =>
                        _applyTargetLanguage(context, textProvider, language),
                  );
                  final settingsButton = Listener(
                    // SHELL-GEAR-001: raw pointer log — không đổi gesture.
                    onPointerDown: (_) => _shellGearPointerLog('down'),
                    onPointerUp: (_) => _shellGearPointerLog('up'),
                    onPointerCancel: (_) => _shellGearPointerLog('cancel'),
                    child: IconButton(
                      onPressed: () =>
                          _showServerSettings(context, textProvider),
                      icon: const Icon(Icons.settings_outlined, size: 16),
                      color: Colors.grey[500],
                      tooltip: context.uiText('Cài đặt engine dịch'),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  );
                  final blurButton = IconButton(
                    tooltip: context.uiText('Làm mờ bản dịch'),
                    isSelected: textProvider.blurTranslations,
                    onPressed: displayMode == TranslationDisplayMode.hidden
                        ? null
                        : () => textProvider.setBlurTranslations(
                            !textProvider.blurTranslations),
                    icon: Icon(textProvider.blurTranslations
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    color: textProvider.blurTranslations ? primaryColor : Colors.grey,
                    visualDensity: VisualDensity.compact,
                  );
                  final layoutSelector = _LayoutSelector(
                    displayMode: displayMode,
                    primaryColor: primaryColor,
                    onChanged: textProvider.setTranslationDisplayMode,
                  );

                  if (constraints.maxWidth < 560) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            translateButton,
                            const SizedBox(width: 8),
                            languageButton,
                            const Spacer(),
                            settingsButton,
                          ],
                        ),
                        if (hasTranslations) ...[
                          const SizedBox(height: 7),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [layoutSelector, blurButton],
                            ),
                          ),
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      translateButton,
                      const SizedBox(width: 8),
                      languageButton,
                      if (hasTranslations) ...[
                        const Spacer(),
                        layoutSelector,
                        blurButton,
                      ] else
                        const Spacer(),
                      const SizedBox(width: 4),
                      settingsButton,
                    ],
                  );
                },
              ),
              if (isTranslating) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      minHeight: 2),
                ),
                // HYMT-002: báo rõ đang dùng Hy-MT OFFLINE (có thể chậm) —
                // kết thúc luôn ở success/error hữu hạn (isTranslating=false
                // khi xong; mọi timeout của engine đều hữu hạn).
                ValueListenableBuilder<String?>(
                  valueListenable: textProvider.translationEngineNotifier,
                  builder: (context, engineName, _) {
                    if (engineName == null || !engineName.contains('Hy-MT')) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        context.uiText(
                            'Đang dịch bằng Hy-MT offline, có thể chậm'),
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ],
              if (textProvider.translationError != null) ...[
                const SizedBox(height: 4),
                Text(
                  context.uiText('Lỗi: ${textProvider.translationError}'),
                  style: const TextStyle(fontSize: 10, color: Colors.redAccent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectTargetLanguage(
    BuildContext context,
    TextProvider textProvider,
  ) async {
    final selected = await showTranslationLanguagePicker(
      context,
      sourceLanguage: textProvider.detectedSourceLanguage,
      currentTarget: textProvider.translationTargetLanguage,
      accentColor: primaryColor,
    );
    if (selected != null && context.mounted) {
      await _applyTargetLanguage(context, textProvider, selected);
    }
  }

  Future<void> _applyTargetLanguage(
    BuildContext context,
    TextProvider textProvider,
    AppLanguage language,
  ) async {
    final playback = context.read<PlaybackController>();
    if (playback.isRunning) {
      playback.stop(fileId: textProvider.currentDocument?.id ?? 'unknown');
    }
    await textProvider.stopSpeaking();
    final changed = await textProvider.setTranslationTargetLanguage(
      language.translationCode,
      retranslateExisting: true,
    );
    if (changed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.uiText('${language.flag} Đã đổi bản dịch và giọng đọc sang ${language.nativeName}'),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showTranslationOptions(
      BuildContext context, TextProvider textProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.translate, color: primaryColor),
              title: const Text('Dịch tất cả (bỏ qua đã có)',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                textProvider.translateAll();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text('Dịch lại tất cả',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                textProvider.translateAll(forceRetranslate: true);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Xóa tất cả bản dịch',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                textProvider.clearAllTranslations();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showServerSettings(
    BuildContext context,
    TextProvider textProvider,
  ) {
    // ★ SỬA 1: Tạo instance, không dùng static
    final service = TranslationService();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TranslationEngineSettingsSheet(
        service: service,
        accentColor: primaryColor,
      ),
    ).whenComplete(textProvider.refreshTranslationChrome);
  }
}

/// Sheet "Cài đặt engine dịch": DeepLX URL + gói ML Kit offline (tải khi
/// user bấm — không auto-download) + chế độ chỉ-offline + màn Thuật ngữ.
class TranslationEngineSettingsSheet extends StatefulWidget {
  final TranslationService service;
  final Color accentColor;

  const TranslationEngineSettingsSheet({
    super.key,
    required this.service,
    required this.accentColor,
  });

  @override
  State<TranslationEngineSettingsSheet> createState() =>
      _TranslationEngineSettingsSheetState();
}

class _TranslationEngineSettingsSheetState extends State<TranslationEngineSettingsSheet> {
  late final TextEditingController _urlController =
      TextEditingController(text: widget.service.deeplxUrl ?? '');

  /// PSRC-28: danh sách gói ML Kit = 3 ngôn ngữ phổ biến hiện sẵn + phần còn
  /// lại trong 26 ngôn ngữ của app (mở bằng "Thêm ngôn ngữ").
  late final MlKitPackCatalog _catalog = MlKitPackCatalog(
    supported: MlKitEngine.supportsTranslationCode,
  );

  /// Đã bấm "Thêm ngôn ngữ" chưa. KHÔNG lưu bền: mở lại sheet về trạng thái
  /// gọn (owner: "danh sách thu gọn, mở khi cần").
  bool _showAllLanguages = false;
  bool? _offlineOnly;
  HyMtOfflinePreference _enginePref = HyMtOfflinePreference.auto;
  bool _hymtHas = false;
  /// Lý do cụ thể khi model hiện có KHÔNG dùng được (null = không có vấn đề).
  String? _hymtIssue;
  /// File 2-bit cũ còn chiếm chỗ (~601 MB) và KHÔNG load được — mời xoá.
  bool _hymtLegacy = false;
  bool _hymtBusy = false;
  double _hymtProgress = 0;

  // XLAT-DEEPLX-001: trạng thái nút "Thử kết nối" DeepLX (dịch câu mẫu ngay
  // trong sheet — hết cảnh dán URL xong im lặng rơi về Google Free).
  bool _testingDeeplx = false;
  bool _deeplxTestOk = false;
  String? _deeplxTestMessage;

  // WP3 (API-004): trạng thái engine LLM (provider + routing). Future tạo
  // MỘT lần trong initState (FutureBuilder trong build không tạo lại).
  Future<(AiProviderConfig?, AiRouteMode)>? _llmInfo;

  // XLAT-SCR-005 (owner 24/10) — "engine nào đang THỰC SỰ chạy?".
  // Trước đây màn này chỉ có nút tải model + công tắc; người dùng không có
  // cách nào biết lượt dịch kế tiếp sẽ đi qua engine nào (online? Hy-MT? ML
  // Kit?) nên tưởng tính năng hỏng khi bản dịch chậm/missing model.
  bool _probing = false;
  bool _probeOk = false;
  String? _probeMessage;

  /// PSRC-188: nguồn sự thật của "gói nào đã tải / đang tải" là registry
  /// trong [TranslationService] — KHÔNG phải State này. Nhờ vậy đóng sheet
  /// giữa chừng thì lượt tải vẫn chạy và mở lại thấy đúng trạng thái.
  MlKitPackDownloads get _packs => widget.service.mlkitPacks;

  @override
  void initState() {
    super.initState();
    _packs.addListener(_onPacksChanged);
    _offlineOnly = widget.service.offlineOnly;
    _enginePref = widget.service.offlineEnginePref;
    _llmInfo = _loadLlmInfo();
    _loadModels();
    // AUDIT-1.21.0 #6: URL DeepLX đã lưu từ bản cũ là link bài hướng dẫn ⇒
    // báo ngay khi mở sheet thay vì để user bấm "Thử kết nối" rồi kẹt.
    final rejected = widget.service.deeplxConfigError;
    if (rejected != null) {
      _deeplxTestOk = false;
      _deeplxTestMessage = '❌ $rejected';
    }
  }

  Future<(AiProviderConfig?, AiRouteMode)> _loadLlmInfo() async {
    final llm = widget.service.llmMt;
    if (llm == null) {
      return (null, AiRouteMode.offlineFirst);
    }
    try {
      final provider = await llm.currentProvider();
      return (provider, await llm.routeMode());
    } catch (_) {
      // Đọc cấu hình lỗi → hiển thị "chưa cấu hình" (an toàn, không crash).
      return (null, AiRouteMode.offlineFirst);
    }
  }

  @override
  void dispose() {
    _packs.removeListener(_onPacksChanged);
    _urlController.dispose();
    super.dispose();
  }

  /// Registry đổi trạng thái (kể cả khi lượt tải chạy tiếp sau khi sheet đã
  /// đóng rồi mở lại) ⇒ vẽ lại. Không `setState` khi đã unmount.
  void _onPacksChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadModels() async {
    final hymt = widget.service.hymt;
    if (hymt != null) {
      _hymtHas = await hymt.hasModel;
      _hymtIssue = _hymtHas ? null : await hymt.modelIssue();
      _hymtLegacy = (await hymt.legacyModelFile()) != null;
    }
    // PSRC-188: hỏi registry (sống ngoài sheet) thay vì tự đọc máy rồi lưu
    // vào State. Gói ĐANG TẢI thì registry giữ nguyên `downloading` — mở lại
    // sheet giữa chừng vẫn thấy "Đang tải…" chứ không quay về "Chưa tải".
    if (MlKitEngine.platformSupported) {
      await _packs.refresh(_mlkitBCPCodes());
    }
    if (mounted) setState(() {});
  }

  /// Mã BCP-47 của MỌI ngôn ngữ có thể tải (cả nhóm đang ẩn) — refresh một
  /// lần cho cả danh sách để mở "Thêm ngôn ngữ" là thấy trạng thái đúng ngay.
  List<String> _mlkitBCPCodes() => <String>[
        for (final language in _catalog.all)
          if (MlKitEngine.languageForCode(language.translationCode) != null)
            MlKitEngine.languageForCode(language.translationCode)!.bcpCode,
      ];

  /// PSRC-188 — tải gói KHÔNG còn gắn với vòng đời sheet.
  ///
  /// Toàn bộ việc tải nằm trong [MlKitPackDownloads] (do
  /// [TranslationService] giữ): đóng sheet ⇒ future vẫn chạy, mở lại ⇒ thấy
  /// `downloading` hoặc `ready`. Ở đây chỉ: gọi registry + báo bằng snackbar
  /// NẾU sheet còn mở.
  Future<void> _downloadModel(String code) async {
    final language = MlKitEngine.languageForCode(code);
    if (language == null) return;
    final messenger = ScaffoldMessenger.of(context);
    // Không `await` trong setState: hàng UI đổi màu ngay nhờ listener của
    // registry (bấm xong thấy "Đang tải…" tức thì, kể cả khi chậm 1 nhịp).
    final future = _packs.start(language.bcpCode);
    final status = await future;
    if (!mounted) {
      // Sheet đã đóng: lượt tải vẫn xong (registry đã cập nhật). Không báo
      // snackbar lên một cây widget đã tháo.
      return;
    }
    if (status.isReady) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.uiText('Đã tải gói $code'))),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.uiText('Lỗi tải gói $code')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteModel(String code) async {
    final language = MlKitEngine.languageForCode(code);
    if (language == null) return;
    // PSRC-182: đọc lại trạng thái THẬT sau khi xoá (plugin trả `false`
    // không có nghĩa là gói vẫn còn) — hàng UI luôn khớp với máy. Registry
    // làm việc đó và phát cho mọi nơi đang xem.
    await _packs.removed(
      language.bcpCode,
      (bcpCode) => widget.service.mlkit.deleteModel(bcpCode),
    );
  }

  /// Nhãn ngôn ngữ trong hàng gói: tên bản ngữ ("日本語") là thứ người dùng
  /// nhận ra nhanh nhất, không phụ thuộc locale UI.
  ///
  /// PSRC-28: trước đây hard-code EN/VI/HI; nay lấy từ danh mục 26 ngôn ngữ để
  /// 16 ngôn ngữ mới thêm cũng có nhãn đúng.
  String _modelLabel(String code) {
    final language = AppLanguageCatalog.maybeFromCode(code);
    return language?.nativeName ?? code;
  }

  @override
  Widget build(BuildContext context) {
    final mlkitSupported = MlKitEngine.platformSupported;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText('⚙️ Engine dịch thuật'),
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildLiveEngineStatus(),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: context.uiText('DeepLX Server URL (tùy chọn)'),
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: context.uiText('Để trống → dùng Google Free'),
                hintStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.uiText(
                'Chỉ dán host cũng được — app tự nối /translate (vd: https://xxx.hf.space/translate).',
              ),
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
            // XLAT-DEEPLX-001: thử kết nối + dịch câu mẫu ngay trong sheet.
            Row(
              children: [
                TextButton.icon(
                  onPressed: _testingDeeplx ? null : _testDeeplxConnection,
                  icon: _testingDeeplx
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check, size: 16),
                  label: Text(context.uiText('Thử kết nối DeepLX')),
                ),
              ],
            ),
            if (_deeplxTestMessage != null)
              Text(
                _deeplxTestMessage!,
                style: TextStyle(
                  color: _deeplxTestOk ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 10),
            Text(
              context.uiText(
                'Ngôn ngữ đích được chọn bằng nút lá cờ trên thanh Dịch.',
              ),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 18),
            // ── Gói dịch offline (ML Kit) ──────────────────────────────
            Text(
              context.uiText('Gói dịch offline (ML Kit — Android/iOS)'),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            if (!mlkitSupported)
              Text(
                context.uiText('ML Kit chỉ chạy trên Android/iOS.'),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              )
            else ...[
              // PSRC-28: 3 ngôn ngữ phổ biến hiện sẵn; phần còn lại (tới 19
              // ngôn ngữ ML Kit nằm trong danh mục app) chỉ hiện khi user bấm
              // "Thêm ngôn ngữ" ⇒ danh sách vẫn gọn như bản 1.27.0 nhưng
              // không còn giấu mất 16 ngôn ngữ.
              for (final language in _catalog.primary)
                _modelRow(language.translationCode),
              if (_showAllLanguages)
                for (final language in _catalog.extra)
                  _modelRow(language.translationCode),
              if (_catalog.hasExtra)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _showAllLanguages = !_showAllLanguages),
                    icon: Icon(
                      _showAllLanguages
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _showAllLanguages
                          ? context.uiText('Ẩn bớt ngôn ngữ')
                          : '${context.uiText('Thêm ngôn ngữ')} '
                              '(${_catalog.extra.length})',
                    ),
                  ),
                ),
              Text(
                context.uiText(
                  'Chỉ tải khi bạn bấm — không tự tải lúc mở app.',
                ),
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              context.uiText('Hy-MT 1.5 (GGUF ~1,1 GB, 33 ngôn ngữ)'),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _hymtHas
                  ? context.uiText('Đã có model. Import lại nếu muốn đổi file.')
                  : context.uiText('Tải bản HY-MT1.5-1.8B-GGUF (Q4_K_M, ~1,1 GB) rồi Import, hoặc bấm Tải về. Không tự tải lúc mở app.'),
              style: TextStyle(color: Colors.grey[600], fontSize: 11),
            ),
            // HYMT-003: nêu ĐÚNG lý do model hiện tại không dùng được (quant
            // chưa có kernel / sai kiến trúc / file cắt) — bản 2-bit của
            // AngelSlim cần llama.cpp PR #19357 nên không load được.
            if (_hymtLegacy)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.uiText(
                          'Còn file 2-bit cũ (~601 MB) không dùng được — xoá để lấy lại dung lượng.',
                        ),
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _hymtBusy ? null : _deleteLegacyHymt,
                      child: Text(
                        context.uiText('Xoá'),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_hymtHas && _hymtIssue != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _hymtIssue!,
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tự chọn'),
                  selected: _enginePref == HyMtOfflinePreference.auto,
                  onSelected: (_) {
                    setState(() => _enginePref = HyMtOfflinePreference.auto);
                    widget.service.offlineEnginePref = HyMtOfflinePreference.auto;
                  },
                ),
                ChoiceChip(
                  label: const Text('Hy-MT'),
                  selected: _enginePref == HyMtOfflinePreference.hymt,
                  onSelected: (_) {
                    setState(() => _enginePref = HyMtOfflinePreference.hymt);
                    widget.service.offlineEnginePref = HyMtOfflinePreference.hymt;
                  },
                ),
                ChoiceChip(
                  label: const Text('ML Kit'),
                  selected: _enginePref == HyMtOfflinePreference.mlkit,
                  onSelected: (_) {
                    setState(() => _enginePref = HyMtOfflinePreference.mlkit);
                    widget.service.offlineEnginePref = HyMtOfflinePreference.mlkit;
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_hymtBusy)
              LinearProgressIndicator(
                value: _hymtProgress > 0 ? _hymtProgress : null,
                minHeight: 4,
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _hymtBusy ? null : _importHymt,
                  icon: const Icon(Icons.folder_open, size: 16),
                  label: const Text('Import .gguf'),
                ),
                TextButton.icon(
                  onPressed: _hymtBusy ? null : _downloadHymt,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Tải về'),
                ),
                if (_hymtHas)
                  IconButton(
                    onPressed: _hymtBusy ? null : _deleteHymt,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: Colors.grey,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // ── LLM API (WP3/API-004) ────────────────────────────────
            Text(
              context.uiText('Dịch bằng LLM (Server & API)'),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilder<(AiProviderConfig?, AiRouteMode)>(
              future: _llmInfo,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 16,
                    width: 16,
                    child: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                final info = snapshot.data;
                final provider = info?.$1;
                final mode = info?.$2 ?? AiRouteMode.offlineFirst;
                if (provider == null) {
                  return Text(
                    context.uiText(
                      'Chưa cấu hình — thêm provider trong Cài đặt → Quản lý Model AI → Server & API.',
                    ),
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: widget.accentColor),
                        const SizedBox(width: 4),
                        // Label/model là dữ liệu user nhập — không dịch.
                        Expanded(
                          child: Text(
                            context.uiText('${provider.label} · ${provider.chatModel ?? ''}'),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode == AiRouteMode.onlineFirst
                          ? context.uiText(
                              'Routing Dịch: Ưu tiên online — LLM chạy trước các engine miễn phí.',
                            )
                          : context.uiText(
                              'Routing Dịch: Ưu tiên offline — LLM chạy sau Hy-MT/ML Kit, trước từ điển.',
                            ),
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            // ── Chỉ offline ────────────────────────────────────────────
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.uiText('Chỉ dùng dịch offline'),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: Text(
                context.uiText(
                  'Bỏ qua engine online (Hy-MT / ML Kit + từ điển).',
                ),
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
              value: _offlineOnly ?? false,
              activeColor: widget.accentColor,
              onChanged: (v) {
                setState(() => _offlineOnly = v);
                widget.service.offlineOnly = v;
              },
            ),
            Divider(color: Colors.grey.shade800),
            // ── Glossary ───────────────────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.bookmark_border, color: widget.accentColor),
              title: Text(
                context.uiText('Thuật ngữ dịch (glossary)'),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: Text(
                context.uiText(
                  'Khóa thuật ngữ Phật học/Pali — engine không được đè.',
                ),
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () async {
                await showGlossarySheet(context, accentColor: widget.accentColor);
                if (mounted) setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () {
                    final raw = _urlController.text.trim();
                    final verdict = assessDeepLXEndpoint(raw);
                    // AUDIT-1.21.0 #6: đừng lưu link bài hướng dẫn/forum làm
                    // endpoint. Nói rõ ngay trong sheet (không pop im lặng).
                    if (!verdict.isValid &&
                        verdict.issue !=
                            DeepLXEndpointIssue.notConfigured) {
                      setState(() {
                        _deeplxTestOk = false;
                        // verdict.message đã là English canonical (rule #5),
                        // không cần uiText cho một template chỉ có 1 placeholder.
                        _deeplxTestMessage = '❌ ${verdict.message}';
                      });
                      return;
                    }
                    widget.service.configure(deeplxUrl: raw);
                    Navigator.pop(context);
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: widget.accentColor),
                  child: const Text('Lưu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  /// XLAT-DEEPLX-001: thử kết nối DeepLX với URL đang nhập — dịch câu mẫu
  /// "Hello" → VI và hiện kết quả inline (xanh = OK, đỏ = lỗi kèm lý do).
  Future<void> _testDeeplxConnection() async {
    final raw = _urlController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _deeplxTestOk = false;
        _deeplxTestMessage = context.uiText('Chưa nhập URL DeepLX.');
      });
      return;
    }
    setState(() {
      _testingDeeplx = true;
      _deeplxTestMessage = null;
    });
    // AUDIT-1.21.0 #6: link bài hướng dẫn/forum (vd linux.do/t/topic/…) bị
    // từ chối NGAY ở tầng thuần ⇒ không POST lên HTML, không quay 20s.
    // Mọi ngoại lệ được gom thành một `DeepLXProbeResult` thất bại, rồi cờ
    // `_testingDeeplx` được hạ trong CÙNG setState cuối ⇒ nút "Thử kết nối"
    // KHÔNG BAO GIỜ kẹt ở trạng thái đang thử dù probe ném lỗi bất ngờ.
    DeepLXProbeResult probe;
    try {
      // Engine tự chuẩn hoá URL (host trần → /translate).
      final engine = DeepLXEngine(serverUrl: raw);
      probe = await engine.probe(text: 'Hello', targetLang: 'VI');
    } catch (error) {
      probe = DeepLXProbeResult(ok: false, error: error.toString());
    }
    if (!mounted) return;
    setState(() {
      _deeplxTestOk = probe.ok;
      if (probe.ok) {
        _deeplxTestMessage = context.uiText(
          '✅ DeepLX hoạt động — dịch thử: “${probe.sample ?? ''}” (${probe.responseTime.inMilliseconds} ms)',
        );
      } else if (probe.statusCode != null) {
        _deeplxTestMessage = context.uiText(
          '❌ Lỗi HTTP ${probe.statusCode}: ${_shortError(probe.error)}',
        );
      } else {
        _deeplxTestMessage = context.uiText(
          '❌ Không kết nối được server: ${_shortError(probe.error)} — kiểm tra Space/serve đang chạy (HF Space ngủ sau ~48h không dùng).',
        );
      }
      // Hạ cờ trong CÙNG setState với thông báo: không có nhánh nào (kể cả
      // lỗi format ở trên) có thể bỏ qua và làm nút kẹt "đang thử" mãi.
      _testingDeeplx = false;
    });
  }

  String _shortError(String? text) {
    final value = (text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.isEmpty) return '—';
    return value.length > 160 ? '${value.substring(0, 160)}…' : value;
  }

  /// Dịch thử MỘT câu (bỏ cache) để trả lời chính xác "engine nào đang chạy".
  ///
  /// Vì sao không suy luận từ cấu hình: chuỗi engine có fallback (online lỗi →
  /// Hy-MT → ML Kit → từ điển), nên chỉ có một lượt dịch thật mới biết engine
  /// nào trả lời. Probe KHÔNG ghi "Nhịp điệu học tập" và KHÔNG lưu cache.
  Future<void> _probeEngine() async {
    if (_probing) return;
    setState(() {
      _probing = true;
      _probeMessage = null;
    });
    final stopwatch = Stopwatch()..start();
    try {
      final result = await widget.service.translateText(
        'Good morning, how are you today?',
        sourceLang: 'EN',
        targetLang: widget.service.targetLang,
        skipCache: true,
        recordActivity: false,
      );
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _probing = false;
        _probeOk = result.isSuccess &&
            result.translatedText.trim().isNotEmpty;
        if (_probeOk) {
          final engine = result.engineName.trim();
          _probeMessage = engine.isEmpty
              ? context.uiText('Đã dịch được — không rõ engine')
              : '${context.uiText('Đã dịch bằng')} $engine · '
                  '${stopwatch.elapsedMilliseconds} ms';
        } else {
          final reason = (result.error ?? '').trim();
          _probeMessage = reason.isEmpty
              ? context.uiText('Không engine nào trả được bản dịch')
              : '${context.uiText('Không engine nào trả được bản dịch')}: $reason';
        }
      });
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _probing = false;
        _probeOk = false;
        _probeMessage =
            '${context.uiText('Không engine nào trả được bản dịch')}: $e';
      });
    }
  }

  /// Khối "engine đang hiện hành" — CHỈ đọc trạng thái thật của service.
  Widget _buildLiveEngineStatus() {
    final service = widget.service;
    final online = !service.offlineOnly;
    final routing = service.routingOrder;
    final active = service.activeEngineName?.trim() ?? '';
    final lastUsed = service.lastUsedEngineLabel.trim();
    // PSRC-188: trạng thái gói lấy từ registry ngoài sheet — đóng/mở sheet
    // không làm mất dấu "đang tải".
    // PSRC-28: chỉ đếm 3 ngôn ngữ PHỔ BIẾN trên pill trạng thái — liệt kê cả
    // 19 mã sẽ tràn dòng và không đọc được.
    final mlkitReady = <String>[
      for (final language in _catalog.primary)
        if (_packs.statusOf(_bcpOf(language.translationCode)).isReady)
          language.translationCode,
    ];
    final mlkitDownloading = _catalog.all.any(
      (language) => _packs.statusOf(_bcpOf(language.translationCode)).isDownloading,
    );
    final grey = TextStyle(color: Colors.grey[500], fontSize: 11);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, size: 16, color: widget.accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.uiText('Engine đang hiện hành'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Chip(
                label: Text(
                  online ? context.uiText('Online') : context.uiText('Chỉ offline'),
                  style: const TextStyle(fontSize: 10),
                ),
                visualDensity: VisualDensity.compact,
                backgroundColor:
                    (online ? Colors.green : Colors.orange).withValues(
                  alpha: 0.18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.uiText('Thứ tự ưu tiên'),
            style: grey,
          ),
          Text(
            routing.join(' → '),
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (active.isNotEmpty)
                _StatusPill(
                  text: '${context.uiText('Đang dịch bằng')}: $active',
                  color: Colors.lightBlueAccent,
                ),
              _StatusPill(
                text: lastUsed.isEmpty
                    ? context.uiText('Chưa dịch gì trong phiên này')
                    : '${context.uiText('Lần trước')}: $lastUsed',
                color: Colors.tealAccent,
              ),
              // Model offline: nói RÕ có hay chưa — "không dịch được" phần lớn
              // là do thiếu gói, không phải app hỏng.
              if (service.hymt != null)
                _StatusPill(
                  text: _hymtHas
                      ? 'Hy-MT · ${context.uiText('Đã tải')}'
                      : 'Hy-MT · ${context.uiText('Chưa tải')}',
                  color: Colors.deepPurpleAccent,
                ),
              if (MlKitEngine.platformSupported)
                _StatusPill(
                  text: mlkitDownloading
                      ? 'ML Kit · ${context.uiText('Đang tải ngầm...')}'
                      : mlkitReady.isEmpty
                          ? 'ML Kit · ${context.uiText('Chưa tải')}'
                          : 'ML Kit · ${mlkitReady.join(', ')}',
                  color: Colors.amberAccent,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _probing ? null : _probeEngine,
                icon: _probing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.science_outlined, size: 16),
                label: Text(context.uiText('Kiểm tra engine ngay')),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _probeMessage ??
                      context.uiText(
                        'Dịch thử một câu để biết engine nào thực sự trả lời.',
                      ),
                  style: TextStyle(
                    color: _probeMessage == null
                        ? Colors.grey[600]
                        : (_probeOk ? Colors.greenAccent : Colors.redAccent),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _importHymt() async {
    final hymt = widget.service.hymt;
    if (hymt == null) return;
    setState(() => _hymtBusy = true);
    final err = await hymt.importFromUser();
    if (!mounted) return;
    _hymtHas = await hymt.hasModel;
    _hymtIssue = _hymtHas ? null : await hymt.modelIssue();
    _hymtLegacy = (await hymt.legacyModelFile()) != null;
    if (!mounted) return;
    setState(() => _hymtBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.uiText(err ?? 'Đã import Hy-MT')),
      backgroundColor: err == null ? null : Colors.redAccent,
    ));
  }

  Future<void> _downloadHymt() async {
    final hymt = widget.service.hymt;
    if (hymt == null) return;
    setState(() {
      _hymtBusy = true;
      _hymtProgress = 0;
    });
    final timer = Stream.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _hymtProgress = hymt.downloadProgress);
    }).listen((_) {});
    final err = await hymt.downloadModel();
    await timer.cancel();
    if (!mounted) return;
    _hymtHas = await hymt.hasModel;
    _hymtIssue = _hymtHas ? null : await hymt.modelIssue();
    _hymtLegacy = (await hymt.legacyModelFile()) != null;
    if (!mounted) return;
    setState(() => _hymtBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.uiText(err ?? 'Đã tải Hy-MT')),
      backgroundColor: err == null ? null : Colors.redAccent,
    ));
  }

  Future<void> _deleteLegacyHymt() async {
    final hymt = widget.service.hymt;
    if (hymt == null) return;
    await hymt.deleteLegacyModel();
    if (!mounted) return;
    setState(() => _hymtLegacy = false);
  }

  Future<void> _deleteHymt() async {
    final hymt = widget.service.hymt;
    if (hymt == null) return;
    await hymt.deleteModel();
    if (!mounted) return;
    setState(() {
      _hymtHas = false;
      _hymtIssue = null;
      _hymtLegacy = false;
    });
  }

  /// Mã BCP-47 của ML Kit cho mã ngôn ngữ app ("VI" → "vi").
  String _bcpOf(String code) =>
      MlKitEngine.languageForCode(code)?.bcpCode ?? code.toLowerCase();

  Widget _modelRow(String code) {
    final supported = MlKitEngine.supportsTranslationCode(code);
    // PSRC-188: trạng thái đọc từ registry sống ngoài sheet, không từ State.
    final pack = _packs.statusOf(_bcpOf(code));
    final downloaded = pack.isReady;
    final downloading = pack.isDownloading;
    final failed = pack.hasFailed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: downloading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    downloaded
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 14,
                    color: downloaded ? Colors.green : Colors.grey,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.uiText('${_modelLabel(code)} ($code)'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                Text(
                  !supported
                      ? context.uiText('Chưa hỗ trợ')
                      : downloaded
                          ? context.uiText('Đã tải')
                          : downloading
                              // PSRC-188: nói rõ "vẫn đang chạy" để user
                              // đóng/mở sheet không tưởng là mất tiến trình.
                              ? context.uiText('Đang tải ngầm...')
                              : failed
                                  ? context.uiText('Lỗi tải gói')
                                  : context.uiText('Chưa tải'),
                  // PSRC-182: trạng thái đọc được bằng mắt — gói đã tải
                  // hiện chữ xanh, không còn lẫn với nút "Tải về".
                  style: TextStyle(
                    color: supported && downloaded
                        ? Colors.green
                        : failed
                            ? Colors.redAccent
                            : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // PSRC-182 (owner 2026-11-10): gói ĐÃ TẢI không được hiện nút
          // "Tải về" nữa — trước đây nút luôn hiện, user phân vân không biết
          // gói đã tải xong chưa. Gói đã tải ⇒ chỉ còn dấu ✓ xanh + chữ
          // "Đã tải" (icon + chữ) ở cột trạng thái, và nút xoá gói.
          // Gói CHƯA tải ⇒ nút có BIỂU TƯỢNG tải xuống + chữ "Tải về".
          if (supported && !downloaded)
            TextButton.icon(
              onPressed: downloading ? null : () => _downloadModel(code),
              icon: downloading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, size: 16),
              label: Text(
                downloading
                    ? context.uiText('Đang tải...')
                    : context.uiText('Tải về'),
              ),
            ),
          if (supported && downloaded)
            IconButton(
              onPressed: () => _deleteModel(code),
              icon: const Icon(Icons.delete_outline, size: 16),
              tooltip: context.uiText('Xóa gói'),
              color: Colors.grey,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

class _TranslateButton extends StatelessWidget {
  final bool isTranslating;
  final bool hasTranslations;
  final bool pipelineStale;
  final Color primaryColor;
  final double progress;
  final int totalLines;
  final int translatedLines;
  final bool requiresLanguageChoice;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TranslateButton({
    required this.isTranslating,
    required this.hasTranslations,
    required this.pipelineStale,
    required this.primaryColor,
    required this.progress,
    required this.totalLines,
    required this.translatedLines,
    required this.requiresLanguageChoice,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = hasTranslations && translatedLines >= totalLines;
    final String label;
    final IconData icon;
    final Color color;
    if (isTranslating) {
      label = 'Dừng';
      icon = Icons.stop_circle_outlined;
      color = Colors.orange;
    } else if (requiresLanguageChoice) {
      label = 'Chọn đích';
      icon = Icons.language_rounded;
      color = Colors.amber;
    } else if (pipelineStale) {
      label = 'Dịch lại';
      icon = Icons.refresh;
      color = Colors.orange;
    } else if (isComplete) {
      label = 'Đã dịch';
      icon = Icons.check_circle_outline;
      color = Colors.green;
    } else {
      label = 'Dịch';
      icon = Icons.translate;
      color = primaryColor;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            if (isTranslating)
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      strokeWidth: 2,
                      color: color))
            else
              Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _LayoutSelector extends StatelessWidget {
  final TranslationDisplayMode displayMode;
  final Color primaryColor;
  final ValueChanged<TranslationDisplayMode> onChanged;

  const _LayoutSelector(
      {required this.displayMode,
      required this.primaryColor,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ModeChip(
            icon: Icons.visibility_off_outlined,
            label: 'Ẩn',
            isSelected: displayMode == TranslationDisplayMode.hidden,
            color: primaryColor,
            onTap: () => onChanged(TranslationDisplayMode.hidden)),
        const SizedBox(width: 4),
        _ModeChip(
            icon: Icons.view_agenda_outlined,
            label: 'Dưới',
            isSelected: displayMode == TranslationDisplayMode.stackedBelow,
            color: primaryColor,
            onTap: () => onChanged(TranslationDisplayMode.stackedBelow)),
        const SizedBox(width: 4),
        _ModeChip(
            icon: Icons.view_column_outlined,
            label: 'Cột',
            isSelected: displayMode == TranslationDisplayMode.sideBySide,
            color: primaryColor,
            onTap: () => onChanged(TranslationDisplayMode.sideBySide)),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ModeChip(
      {required this.icon,
      required this.label,
      required this.isSelected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade700),
        ),
        child: Row(
          children: [
            Icon(icon, size: 12, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? color : Colors.grey,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

class TranslationLineDisplay extends StatelessWidget {
  final String originalText;
  final String? translatedText;
  final TranslationDisplayMode displayMode;
  final Widget originalWidget;
  final TextStyle? translationStyle;
  final TextAlign? textAlign;
  final bool blurTranslation;
  final AppLanguage? targetLanguage;

  const TranslationLineDisplay({
    super.key,
    required this.originalText,
    this.translatedText,
    required this.displayMode,
    required this.originalWidget,
    this.translationStyle,
    this.textAlign,
    this.blurTranslation = false,
    this.targetLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final hasTranslation = translatedText != null && translatedText!.isNotEmpty;
    final targetLanguage = this.targetLanguage ?? TranslationService().targetLanguage;

    if (displayMode == TranslationDisplayMode.hidden) return originalWidget;

    if (displayMode == TranslationDisplayMode.stackedBelow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          originalWidget,
          if (hasTranslation) ...[
            const SizedBox(height: 6),
            _TranslationText(
              text: translatedText!,
              blurred: blurTranslation,
              language: targetLanguage,
              style: translationStyle,
              textAlign: textAlign,
            ),
          ],
        ],
      );
    }

    // Side by side
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: originalWidget),
          Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              color: Colors.white10),
          Expanded(
            child: hasTranslation
                ? _TranslationText(
                    text: translatedText!,
                    blurred: blurTranslation,
                    language: targetLanguage,
                    style: translationStyle,
                    textAlign: textAlign,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TranslationText extends StatefulWidget {
  final String text;
  final bool blurred;
  final AppLanguage language;
  final TextStyle? style;
  final TextAlign? textAlign;

  const _TranslationText({
    required this.text,
    this.blurred = false,
    required this.language,
    this.style,
    this.textAlign,
  });

  @override
  State<_TranslationText> createState() => _TranslationTextState();
}

class _TranslationTextState extends State<_TranslationText> {
  bool _revealed = false;

  @override
  void didUpdateWidget(covariant _TranslationText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.blurred != widget.blurred) {
      _revealed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = widget.language.translationCode == 'AR';
    final hidden = widget.blurred && !_revealed;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.035)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.language.flag, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.text,
              textDirection: isRtl ? TextDirection.rtl : null,
              textAlign: isRtl ? TextAlign.right : widget.textAlign,
              style: hidden
                  ? (widget.style ?? const TextStyle(fontSize: 13)).copyWith(
                      color: const Color(0x33FFFFFF),
                      shadows: const [Shadow(color: Colors.white70, blurRadius: 7),
                        Shadow(color: Colors.white70, blurRadius: 7)],
                    )
                  : widget.style ??
                  TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
    if (!widget.blurred) return content;
    return Semantics(
      button: true,
      label: context.uiText(hidden
          ? 'Bấm để hiện bản dịch.' : 'Bấm để làm mờ bản dịch.'),
      child: InkWell(
        onTap: () => setState(() => _revealed = !_revealed),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            hidden ? ExcludeSemantics(child: content) : content,
            Text(context.uiText(hidden
                ? 'Bấm để hiện bản dịch.' : 'Bấm để làm mờ bản dịch.'),
                style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}


/// Nhãn nhỏ trong khối "Engine đang hiện hành" (trạng thái thật, không phải
/// nút bấm) — tách ra để ba dòng trạng thái không phải lặp code trang trí.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10.5),
      ),
    );
  }
}
