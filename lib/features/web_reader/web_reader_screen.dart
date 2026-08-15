//
// ★ FIX WINDOWS: dùng webview_win_floating (như YouGlishWidget)
//   thay vì placeholder text "đang được phát triển"
// Android: giữ nguyên webview_flutter

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_win_floating/webview_win_floating.dart';

import '../../features/grammar/grammar.dart';
import '../../models/color_mode.dart';
import '../../models/vocab_context.dart';
import '../../providers/text_provider.dart';
import 'js/web_reader_js.dart';
import 'web_reader_controller.dart';
import 'widgets/web_extraction_batch_sheet.dart';
import 'widgets/web_reader_home_view.dart';
import 'widgets/web_reader_toolbar.dart';
import 'widgets/web_word_tap_sheet.dart';
import 'package:in4up/core/language/tr_extension.dart';

class WebReaderScreen extends StatefulWidget {
  final String? initialUrl;
  final String? initialFocusTerm;
  final VocabContext? initialFocusContext;

  const WebReaderScreen({
    super.key,
    this.initialUrl,
    this.initialFocusTerm,
    this.initialFocusContext,
  });

  @override
  State<WebReaderScreen> createState() => _WebReaderScreenState();
}

class _WebReaderScreenState extends State<WebReaderScreen> {
  late final WebReaderController _controller;

  WebViewController? _mobileCtrl;
  WinWebViewController? _winCtrl;

  bool _showSelectionBar = false;
  String _selectionText = '';
  DateTime? _lastSnackbar;
  bool _showDashboard = false;

  @override
  void initState() {
    super.initState();
    _showDashboard = widget.initialUrl == null || widget.initialUrl!.trim().isEmpty;
    _controller = WebReaderController();
    _controller.addListener(_onStateChanged);

    if (Platform.isWindows) {
      _initWindows();
    } else {
      _initMobile();
    }
  }

  ColorMode _lastColorMode = ColorMode.none;
  int _lastHighlightVersion = 0;

  void _onStateChanged() {
    if (!mounted) {
      return;
    }

    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
    if (!isCurrentRoute) return;

    final colorModeChanged = _controller.colorMode != _lastColorMode;
    final highlightChanged =
        _controller.highlightVersion != _lastHighlightVersion;

    if (colorModeChanged || highlightChanged) {
      _lastColorMode = _controller.colorMode;
      _lastHighlightVersion = _controller.highlightVersion;
      if (_controller.colorMode == ColorMode.none) {
        _removeHighlight();
      } else {
        _applyHighlight();
      }
      _updateFab();
    }
  }

  void _initMobile() {
    _mobileCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D1117))
      ..addJavaScriptChannel(
        'in4upChannel',
        onMessageReceived: _onJsMessage,
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          _controller.onPageStarted(url);
          if (mounted) {
            setState(() {
              _showDashboard = false;
              _showSelectionBar = false;
              _selectionText = '';
            });
          }
        },
        onProgress: (p) => _controller.onProgress(p),
        onPageFinished: _onPageFinished,
        onWebResourceError: (err) {
          if (err.isForMainFrame == true) {
            debugPrint('WebReader error: ${err.description}');
          }
        },
        onNavigationRequest: (req) => req.isMainFrame
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ));

    final url = widget.initialUrl == null
        ? ''
        : WebReaderController.normalizeUrl(widget.initialUrl!);
    if (url.isNotEmpty) {
      _mobileCtrl!.loadRequest(Uri.parse(url));
    }
  }

  void _initWindows() {
    _winCtrl = WinWebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D1117))
      ..addJavaScriptChannel(
        'in4upChannel',
        onMessageReceived: _onJsMessage,
      )
      ..setNavigationDelegate(WinNavigationDelegate(
        onPageStarted: (url) {
          _controller.onPageStarted(url);
          if (mounted) {
            setState(() {
              _showDashboard = false;
              _showSelectionBar = false;
              _selectionText = '';
            });
          }
        },
        onProgress: (p) => _controller.onProgress(p),
        onPageFinished: _onPageFinishedWin,
        onWebResourceError: (err) {
          debugPrint('WebReader Windows error: ${err.description}');
        },
        onNavigationRequest: (req) => req.isMainFrame
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ));

    final url = widget.initialUrl == null
        ? ''
        : WebReaderController.normalizeUrl(widget.initialUrl!);
    if (url.isNotEmpty) {
      _winCtrl!.loadRequest(Uri.parse(url));
    }
  }

  Future<void> _navigate(String urlOrCommand) async {
    if (urlOrCommand.isEmpty) {
      if (mounted) {
        setState(() {
          _showDashboard = true;
          _showSelectionBar = false;
          _selectionText = '';
        });
      }
      return;
    }

    if (urlOrCommand == '__back__') {
      await _mobileCtrl?.goBack();
      await _winCtrl?.goBack();
      return;
    }

    if (urlOrCommand == '__forward__') {
      await _mobileCtrl?.goForward();
      await _winCtrl?.goForward();
      return;
    }

    final normalized = WebReaderController.normalizeUrl(urlOrCommand);
    if (normalized.isEmpty) return;

    if (mounted) {
      setState(() {
        _showDashboard = false;
      });
    }

    final uri = Uri.parse(normalized);
    await _mobileCtrl?.loadRequest(uri);
    await _winCtrl?.loadRequest(uri);
  }

  Future<void> _runJS(String script) async {
    try {
      await _mobileCtrl?.runJavaScript(script);
      await _winCtrl?.runJavaScript(script);
    } catch (e) {
      debugPrint('WebReader runJS error: $e');
    }
  }

  Future<dynamic> _runJSReturning(String script) async {
    try {
      if (Platform.isWindows && _winCtrl != null) {
        return await _winCtrl!.runJavaScriptReturningResult(script);
      } else if (_mobileCtrl != null) {
        return await _mobileCtrl!.runJavaScriptReturningResult(script);
      }
    } catch (e) {
      debugPrint('WebReader runJSReturning error: $e');
    }
    return null;
  }

  Future<void> _onPageFinished(String url) async {
    final title = await _mobileCtrl
        ?.runJavaScriptReturningResult(WebReaderJS.getTitleScript)
        .then((v) => v.toString().replaceAll('"', ''))
        .catchError((_) => '');

    _controller.onPageFinished(url, title ?? '');

    final canBack =
        await _mobileCtrl?.canGoBack().catchError((_) => false) ?? false;
    final canFwd =
        await _mobileCtrl?.canGoForward().catchError((_) => false) ?? false;
    _controller.onNavigationStateChange(
        canGoBack: canBack, canGoForward: canFwd);

    await _runJS(WebReaderJS.setupSelectionListenerScript);
    await _runJS(WebReaderJS.setupReadingProgressListenerScript);
    await _restoreReadingProgress(url);

    if (_controller.colorMode != ColorMode.none) await _applyHighlight();
    await _updateFab();
    await _applyFocusCue();
  }

  Future<void> _onPageFinishedWin(String url) async {
    final title = await _winCtrl
        ?.runJavaScriptReturningResult(WebReaderJS.getTitleScript)
        .then((v) => v.toString().replaceAll('"', ''))
        .catchError((_) => '');

    _controller.onPageFinished(url, title ?? '');

    final canBack =
        await _winCtrl?.canGoBack().catchError((_) => false) ?? false;
    final canFwd =
        await _winCtrl?.canGoForward().catchError((_) => false) ?? false;
    _controller.onNavigationStateChange(
        canGoBack: canBack, canGoForward: canFwd);

    await _runJS(WebReaderJS.setupSelectionListenerScript);
    await _runJS(WebReaderJS.setupReadingProgressListenerScript);
    await _restoreReadingProgress(url);

    if (_controller.colorMode != ColorMode.none) await _applyHighlight();
    await _updateFab();
    await _applyFocusCue();
  }

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'wordTap':
          final word = data['word'] as String? ?? '';
          if (word.isEmpty) return;
          _controller.onWordTapped(
            word,
            contextText: (data['contextText'] ?? '').toString(),
            scrollProgress: (data['scrollProgress'] as num?)?.toDouble(),
          );
          if (mounted) {
            WebWordTapSheet.show(
              context,
              word,
              _controller.tappedWord,
              _controller,
            );
          }
          break;

        case 'textSelected':
          final text = data['text'] as String? ?? '';
          if (text.isEmpty) return;
          _controller.onTextSelected(
            text,
            contextText: (data['contextText'] ?? '').toString(),
            scrollProgress: (data['scrollProgress'] as num?)?.toDouble(),
          );
          if (mounted) {
            setState(() {
              _showSelectionBar = true;
              _selectionText = text;
            });
          }
          break;

        case 'fabTap':
          _controller.cycleColorMode();
          _applyHighlight();
          _updateFab();
          break;

        case 'readingProgress':
          final progress = ((data['progress'] as num?) ?? 0).toDouble();
          final preview = (data['preview'] ?? '').toString();
          _controller.updateReadingProgress(
            url: _controller.currentUrl,
            title: _controller.pageTitle,
            progress: progress,
            preview: preview,
          );
          break;
      }
    } catch (e) {
      debugPrint('WebReaderScreen: JS message parse error: $e');
    }
  }

  Future<void> _restoreReadingProgress(String url) async {
    if (_showDashboard) return;
    if (widget.initialFocusContext?.scrollProgressHint != null) return;
    final progress = _controller.progressForUrl(url);
    if (progress <= 0.01) return;
    try {
      await _runJS(WebReaderJS.buildRestoreScrollScript(progress));
    } catch (e) {
      debugPrint('WebReader: _restoreReadingProgress error: $e');
    }
  }

  Future<void> _applyFocusCue() async {
    final term = widget.initialFocusTerm?.trim() ?? '';
    final focusContext = widget.initialFocusContext;
    final hasPreciseContext = focusContext != null &&
        (focusContext.hasPreciseAnchor || focusContext.surroundingText.trim().isNotEmpty);
    if (_showDashboard || (term.isEmpty && !hasPreciseContext)) return;
    try {
      await _runJS(
        WebReaderJS.buildPreciseFocusCueScript(
          term: term,
          anchorText: focusContext?.anchorText,
          surroundingText: focusContext?.surroundingText,
          scrollProgress: focusContext?.scrollProgressHint,
        ),
      );
    } catch (e) {
      debugPrint('WebReader: _applyFocusCue error: $e');
    }
  }

  Future<void> _applyHighlight() async {
    if (_controller.state != WebReaderState.ready || _showDashboard) return;
    try {
      final config = _controller.buildHighlightConfig();
      final script = WebReaderJS.buildHighlightScript(config);
      await _runJS(script);
    } catch (e) {
      debugPrint('WebReader: _applyHighlight error: $e');
    }
  }

  Future<void> _removeHighlight() async {
    try {
      await _runJS(WebReaderJS.removeHighlightScript);
    } catch (_) {}
  }

  Future<void> _updateFab() async {
    if (_showDashboard) return;
    try {
      final config = _controller.buildHighlightConfig();
      await _runJS(WebReaderJS.buildFabScript(config));
    } catch (_) {}
  }

  Future<String?> _extractMainArticleText() async {
    try {
      final raw = await _runJSReturning(WebReaderJS.extractMainTextScript);
      if (raw == null) return null;
      var text = raw.toString();
      if (text.startsWith('"') && text.endsWith('"')) {
        text = text.substring(1, text.length - 1);
      }
      text = text
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\t', ' ')
          .replaceAll(r'\"', '"')
          .replaceAll(r"\'", "'")
          .trim();
      return text.isEmpty ? null : text;
    } catch (e) {
      debugPrint('WebReaderScreen: extract error: $e');
      return null;
    }
  }

  Future<void> _extractTextToStudio() async {
    if (_controller.state != WebReaderState.ready || _showDashboard) return;

    _showSnack(context.tr('⏳ Đang trích xuất văn bản...'), duration: 1);
    final text = await _extractMainArticleText();
    if (text == null || text.isEmpty) {
      _showSnack(context.tr('❌ Không thể extract text từ trang này'));
      return;
    }

    if (mounted) {
      context.read<TextProvider>().loadFromString(
            text,
            title: _controller.pageTitle,
          );
      _showSnack(
        'Content'\n'Content',
      );
    }
  }

  Future<void> _openBatchFromCurrentPage() async {
    if (_controller.state != WebReaderState.ready || _showDashboard) return;
    _showSnack(context.tr('⏳ Đang chuẩn bị batch từ bài hiện tại...'), duration: 1);
    final text = await _extractMainArticleText();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      _showSnack(context.tr('❌ Không thể lấy nội dung bài để tạo batch'));
      return;
    }
    await WebExtractionBatchSheet.show(
      context,
      controller: _controller,
      sourceLabel: _controller.pageTitle.isEmpty
          ? _controller.currentUrl
          : _controller.pageTitle,
      sourceText: text,
      fromSelection: false,
    );
  }

  Future<void> _openBatchFromSelection() async {
    if (_showDashboard) return;
    final selection = _selectionText.trim();
    if (selection.isEmpty) {
      _showSnack(context.tr('Bạn cần bôi chọn một đoạn trước'));
      return;
    }
    await WebExtractionBatchSheet.show(
      context,
      controller: _controller,
      sourceLabel: 'Content',
      sourceText: selection,
      fromSelection: true,
    );
  }

  Future<void> _openGrammarSettings() async {
    await _controller.refreshGrammarPresetLibrary();
    await GrammarQuickSettingsSheet.show(
      context,
      title: context.tr('Web Reader · Từ loại chuyên sâu'),
      settings: _controller.grammarSettings,
      palette: _controller.activeGrammarPalette,
      activePreset: _controller.activeGrammarPreset,
      presets: _controller.availableGrammarPresets,
      onToggleEnabled: (value) => _controller.setGrammarHighlightEnabled(value),
      onSelectPreset: (id) => _controller.applyGrammarPreset(id),
      onSaveCurrentAsPreset: (name, description) =>
          _controller.saveCurrentGrammarPreset(
        name: name,
        description: description,
      ),
      onRestorePreviousPreset: () => _controller.restorePreviousGrammarPreset(),
      onToggleAdvancedMode: (value) => _controller.setGrammarAdvancedControls(value),
      onSelectPalette: (id) => _controller.setGrammarPalette(id),
      onSelectStyle: (style) => _controller.setGrammarHighlightStyle(style),
      onToggleCategory: (category) => _controller.toggleGrammarCategory(category),
      onToggleLegend: (visible) => _controller.setGrammarLegendVisible(visible),
      onShowAllCategories: () => _controller.showAllGrammarCategories(),
    );
    if (_controller.colorMode == ColorMode.wordType) {
      await _applyHighlight();
    }
  }

  Future<void> _saveCurrentPageToCollection() async {
    if (_controller.state != WebReaderState.ready || _showDashboard) return;

    if (!_controller.hasUserCollections) {
      final newCollectionId = await _showCreateCollectionDialog(
        suggestedTitle: 'Content',
      );
      if (newCollectionId == null) return;
      final added = await _controller.addCurrentPageToUserCollection(newCollectionId);
      _showSnack(
        added
            ? 'Create group'
            : 'Content',
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111827),
      builder: (sheetContext) {
        final collections = _controller.userCollections;
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(context.l10n.webReaderSaveToGroup, style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _controller.pageTitle.isEmpty
                    ? _controller.currentUrl
                    : _controller.pageTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[300], height: 1.45),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: collections.length + 1,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x332196F3),
                          child: Icon(Icons.create_new_folder_outlined,
                              color: Colors.white),
                        ),
                        title: const TrText('Tạo nhóm mới rồi lưu luôn', style: TextStyle(color: Colors.white),
                        ),
                        subtitle: TrText('Dùng khi bạn muốn gom bài đang đọc vào một nhóm mới.', style: TextStyle(color: Colors.grey[400]),
                        ),
                        onTap: () async {
                          final collectionId = await _showCreateCollectionDialog();
                          if (collectionId == null) return;
                          final added = await _controller
                              .addCurrentPageToUserCollection(collectionId);
                          if (!mounted) return;
                          Navigator.pop(sheetContext);
                          _showSnack(
                            added
                                ? 'Create group'
                                : 'Content',
                          );
                        },
                      );
                    }

                    final collection = collections[index - 1];
                    final isPinned =
                        _controller.isCollectionPinned(collection.id);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.white12,
                        child: Text(collection.emoji),
                      ),
                      title: Text(
                        collection.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        collection.description.isEmpty
                            ? 'Content'
                            : collection.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      trailing: isPinned
                          ? const Icon(Icons.push_pin,
                              color: Colors.amber, size: 18)
                          : null,
                      onTap: () async {
                        final added = await _controller
                            .addCurrentPageToUserCollection(collection.id);
                        if (!mounted) return;
                        Navigator.pop(sheetContext);
                        _showSnack(
                          added
                              ? '✅ Đã lưu vào nhóm "${collection.title}"'
                              : 'Trang này đã có sẵn trong nhóm "${collection.title}"',
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _showCreateCollectionDialog({String? suggestedTitle}) async {
    final titleCtrl = TextEditingController(text: suggestedTitle ?? '');
    final descCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '📁');

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151B26),
          title: const TrTrText('Tạo nhóm mới'),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dialogInputDecoration(
                    label: context.l10n.webReaderGroupName,
                    hint: context.tr('Ví dụ: Bài đọc hôm nay'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dialogInputDecoration(
                    label: context.l10n.webReaderGroupDesc,
                    hint: context.tr('Ghi chú ngắn cho nhóm này'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emojiCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dialogInputDecoration(
                    label: 'Emoji',
                    hint: context.tr('📁 hoặc 🪷 hoặc 🇬🇧'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const TrTrText('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: TrTrText('Tên nhóm không được để trống')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const TrText(context.l10n.webReaderCreateAndSave),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) return null;

    return _controller.createOrUpdateUserCollection(
      title: titleCtrl.text,
      description: descCtrl.text,
      emoji: emojiCtrl.text,
    );
  }

  InputDecoration _dialogInputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.grey[300]),
      hintStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF64B5F6)),
      ),
    );
  }

  Future<void> _toggleCurrentArticlePin() async {
    final url = _controller.currentUrl.trim();
    if (url.isEmpty || _showDashboard) return;
    final wasPinned = _controller.isArticlePinned(url);
    await _controller.toggleArticlePin(
      url,
      title: _controller.pageTitle,
    );
    _showSnack(
      wasPinned ? 'Content' : 'Content',
    );
  }

  Future<void> _toggleCurrentArticleCompleted() async {
    final url = _controller.currentUrl.trim();
    if (url.isEmpty || _showDashboard) return;
    final wasCompleted = _controller.isArticleCompleted(url);
    if (wasCompleted) {
      await _controller.resetArticleProgress(
        url,
        title: _controller.pageTitle,
      );
      _showSnack(context.tr('Đã chuyển bài hiện tại về trạng thái chưa đọc xong'));
    } else {
      await _controller.markArticleCompleted(
        url,
        title: _controller.pageTitle,
      );
      _showSnack(context.tr('Đã đánh dấu bài hiện tại là đọc xong'));
    }
  }

  Future<void> _editCurrentArticleNote() async {
    final url = _controller.currentUrl.trim();
    if (url.isEmpty || _showDashboard) return;

    final noteCtrl = TextEditingController(text: _controller.articleNote(url));
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151B26),
          title: const TrText(context.l10n.webReaderReadNotes),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _controller.pageTitle.isEmpty
                      ? _controller.currentUrl
                      : _controller.pageTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[300], height: 1.45),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 10,
                  minLines: 6,
                  style: const TextStyle(color: Colors.white),
                  decoration: _dialogInputDecoration(
                    label: context.l10n.webReaderYourNote,
                    hint: context.tr('Tóm tắt bài, insight, câu hay, hoặc kế hoạch ôn lại...'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (_controller.hasArticleNote(url))
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'delete'),
                child: const TrTrText('Xoá ghi chú'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'studio'),
              child: const TrText(context.l10n.webReaderInTextStudio),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'save'),
              child: const TrText(context.l10n.webReaderSaveNoteBtn),
            ),
          ],
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'delete') {
      await _controller.saveArticleNote(url, '', title: _controller.pageTitle);
      _showSnack(context.tr('Đã xoá ghi chú bài hiện tại'));
      return;
    }

    if (action == 'studio') {
      final noteText = noteCtrl.text.trim().isEmpty
          ? _controller.articleNote(url)
          : noteCtrl.text.trim();
      if (noteText.isEmpty) {
        _showSnack(context.tr('Bài này chưa có ghi chú để mở'));
        return;
      }
      context.read<TextProvider>().loadFromString(
            noteText,
            title:
                'Note · ${_controller.pageTitle.isEmpty ? _controller.currentUrl : _controller.pageTitle}',
          );
      _showSnack(context.tr('Đã mở ghi chú trong Text Studio'));
      return;
    }

    await _controller.saveArticleNote(
      url,
      noteCtrl.text,
      title: _controller.pageTitle,
    );
    _showSnack(
      noteCtrl.text.trim().isEmpty
          ? 'Note'
          : 'Note',
    );
  }

  Future<void> _appendSelectionToNote() async {
    final url = _controller.currentUrl.trim();
    final selection = _selectionText.trim();
    if (url.isEmpty || selection.isEmpty || _showDashboard) return;
    await _controller.appendSelectionToArticleNote(
      url,
      selection,
      title: _controller.pageTitle,
      preview: selection,
    );
    _showSnack(context.tr('Đã thêm đoạn chọn vào ghi chú bài đọc'));
  }

  void _saveSelectionToWordList() {
    final selection = _selectionText.trim();
    if (selection.isEmpty || _showDashboard) return;
    final added = _controller.saveSelectionToWordList(selection);
    _showSnack(
      added
          ? 'Add'
          : 'Content',
    );
  }

  void _saveSelectionToMemory() {
    final selection = _selectionText.trim();
    if (selection.isEmpty || _showDashboard) return;
    final saved = _controller.saveSelectionToMemory(selection);
    _showSnack(
      saved
          ? 'Memory Garden'
          : 'Memory Garden',
    );
  }

  void _openSelectionInTextStudio() {
    final selection = _selectionText.trim();
    if (selection.isEmpty) return;
    context.read<TextProvider>().loadFromString(
          selection,
          title:
              'Content',
        );
    _showSnack(context.tr('Đã mở đoạn chọn trong Text Studio'));
  }

  void _handlePageAction(String value) {
    switch (value) {
      case 'pinArticle':
        _toggleCurrentArticlePin();
        break;
      case 'toggleCompleted':
        _toggleCurrentArticleCompleted();
        break;
      case 'editNote':
        _editCurrentArticleNote();
        break;
      case 'batchPage':
        _openBatchFromCurrentPage();
        break;
      case 'saveToCollection':
        _saveCurrentPageToCollection();
        break;
      case 'extractText':
        _extractTextToStudio();
        break;
    }
  }

  void _showSnack(String msg, {int duration = 3}) {
    final now = DateTime.now();
    if (_lastSnackbar != null && now.difference(_lastSnackbar!).inSeconds < 1) {
      return;
    }
    _lastSnackbar = now;
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1A237E),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: duration),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
          tooltip: context.l10n.webReaderGoBack,
        ),
        titleSpacing: 0,
        title: !_showDashboard && _controller.state == WebReaderState.loading
            ? LinearProgressIndicator(
                value: _controller.loadingProgress < 1.0
                    ? _controller.loadingProgress
                    : null,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF2196F3)),
                minHeight: 2,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey, size: 20),
            onPressed: _showDashboard || _controller.currentUrl.isEmpty
                ? null
                : () {
                    final url = _controller.currentUrl;
                    if (url.isNotEmpty) {
                      _navigate(url);
                    }
                  },
          ),
          if (!_showDashboard && _controller.currentUrl.isNotEmpty)
            PopupMenuButton<String>(
              color: const Color(0xFF151B26),
              tooltip: context.tr('Tác vụ bài đọc'),
              onSelected: _handlePageAction,
              itemBuilder: (context) {
                final isPinned =
                    _controller.isArticlePinned(_controller.currentUrl);
                final isCompleted =
                    _controller.isArticleCompleted(_controller.currentUrl);
                return [
                  PopupMenuItem(
                    value: 'pinArticle',
                    child: Text(isPinned ? 'Content' : 'Content'),
                  ),
                  PopupMenuItem(
                    value: 'toggleCompleted',
                    child: Text(
                      isCompleted
                          ? 'Done'
                          : 'Done',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'editNote',
                    child: Text(
                      _controller.hasArticleNote(_controller.currentUrl)
                          ? 'Note'
                          : 'Note',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'batchPage',
                    child: TrTrText('Tạo batch WordList từ bài này'),
                  ),
                  const PopupMenuItem(
                    value: 'saveToCollection',
                    child: TrTrText('Lưu vào nhóm'),
                  ),
                  const PopupMenuItem(
                    value: 'extractText',
                    child: TrText(context.l10n.webReaderInTextStudio),
                  ),
                ];
              },
            ),
        ],
      ),
      body: Column(
        children: [
          WebReaderToolbar(
            controller: _controller,
            onNavigate: _navigate,
            onExtractText: _extractTextToStudio,
            onSavePageToCollection: _saveCurrentPageToCollection,
            onOpenGrammarSettings: _openGrammarSettings,
            showingDashboard: _showDashboard,
          ),
          Expanded(
            child: _showDashboard
                ? WebReaderHomeView(
                    controller: _controller,
                    onNavigate: _navigate,
                  )
                : Stack(
                    children: [
                      Positioned.fill(
                        child: Platform.isWindows
                            ? (_winCtrl != null
                                ? WinWebViewWidget(controller: _winCtrl!)
                                : const SizedBox())
                            : (_mobileCtrl != null
                                ? WebViewWidget(controller: _mobileCtrl!)
                                : const SizedBox()),
                      ),
                      if (_controller.state == WebReaderState.loading)
                        const Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                          ),
                        ),
                      if (_controller.state == WebReaderState.error)
                        _buildErrorOverlay(),
                      if (_controller.isHighlightActive) _buildColorLegend(),
                    ],
                  ),
          ),
          if (_showSelectionBar && _selectionText.isNotEmpty && !_showDashboard)
            _buildSelectionBar(),
        ],
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: const Color(0xFF0D1117),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 52, color: Colors.grey[600]),
            const SizedBox(height: 16),
            TrText('Không thể tải trang', style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const TrText(context.l10n.shadowingRetry),
              onPressed: () {
                final url = _controller.currentUrl;
                if (url.isNotEmpty) _navigate(url);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorLegend() {
    return Positioned(
      bottom: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.87),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _controller.colorMode == ColorMode.cefrLevel
              ? 'CEFR: A1 A2 B1 B2 C1 C2'
              : _controller.colorMode == ColorMode.difficulty
                  ? 'Content'
                  : 'Content',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF1A237E),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '"$_selectionText"',
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _SelectionActionButton(
            icon: Icons.sticky_note_2_outlined,
            tooltip: context.tr('Thêm vào ghi chú bài này'),
            onTap: _appendSelectionToNote,
          ),
          const SizedBox(width: 6),
          _SelectionActionButton(
            icon: Icons.text_snippet_outlined,
            tooltip: context.tr('Mở đoạn chọn trong Text Studio'),
            onTap: _openSelectionInTextStudio,
          ),
          const SizedBox(width: 6),
          _SelectionActionButton(
            icon: Icons.volume_up,
            tooltip: context.tr('Đọc đoạn chọn'),
            onTap: () => _controller.speakText(_selectionText),
          ),
          const SizedBox(width: 6),
          _SelectionMoreButton(
            onSaveToWordList: _saveSelectionToWordList,
            onSaveToMemory: _saveSelectionToMemory,
            onCreateBatch: _openBatchFromSelection,
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              _controller.clearSelection();
              setState(() {
                _showSelectionBar = false;
                _selectionText = '';
              });
            },
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SelectionMoreButton extends StatelessWidget {
  final VoidCallback onSaveToWordList;
  final VoidCallback onSaveToMemory;
  final VoidCallback onCreateBatch;

  const _SelectionMoreButton({
    required this.onSaveToWordList,
    required this.onSaveToMemory,
    required this.onCreateBatch,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.tr('Thao tác học tập'),
      child: PopupMenuButton<String>(
        tooltip: context.tr('Thao tác học tập'),
        color: const Color(0xFF151B26),
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
        ),
        onSelected: (value) {
          switch (value) {
            case 'wordlist':
              onSaveToWordList();
              break;
            case 'memory':
              onSaveToMemory();
              break;
            case 'batch':
              onCreateBatch();
              break;
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'wordlist',
            child: TrTrText('Lưu đoạn chọn vào WordList'),
          ),
          PopupMenuItem(
            value: 'memory',
            child: TrTrText('Lưu đoạn chọn vào Vườn Nhớ'),
          ),
          PopupMenuItem(
            value: 'batch',
            child: TrTrText('Tạo batch WordList từ đoạn chọn'),
          ),
        ],
      ),
    );
  }
}

class _SelectionActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SelectionActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}