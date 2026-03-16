//
// Web browser tích hợp trong VipSound với:
//  - Highlight từ theo CEFR / WordType bằng JavaScript injection
//  - Tap từ → Word detail sheet + lưu vào Memory Garden
//  - Extract text → load vào Text Studio (Read Mode)
//  - TTS đọc selected text
//  - Lịch sử & bookmark

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/color_mode.dart';
import '../../providers/text_provider.dart';
import 'js/web_reader_js.dart';
import 'web_reader_controller.dart';
import 'widgets/web_reader_toolbar.dart';
import 'widgets/web_word_tap_sheet.dart';

class WebReaderScreen extends StatefulWidget {
  /// URL mở khi màn hình khởi tạo (optional)
  final String? initialUrl;

  const WebReaderScreen({super.key, this.initialUrl});

  @override
  State<WebReaderScreen> createState() => _WebReaderScreenState();
}

class _WebReaderScreenState extends State<WebReaderScreen> {
  late final WebReaderController _controller;
  late final WebViewController _webCtrl;

  // Selection action bar
  bool _showSelectionBar = false;
  String _selectionText = '';

  // Snackbar debounce
  DateTime? _lastSnackbar;

  @override
  void initState() {
    super.initState();
    _controller = WebReaderController();
    _controller.addListener(_onStateChanged);

    if (Platform.isWindows) {
      // TODO: Implement webview_windows controller initialization here
    } else {
      _initWebView();
    }
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _initWebView() {
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D1117))

      // ── JavaScript Channel: nhận messages từ trang web ──
      ..addJavaScriptChannel(
        'VipSoundChannel',
        onMessageReceived: _onJsMessage,
      )

      // ── Navigation delegate ───────────────────────────
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          _controller.onPageStarted(url);
          // Reset selection bar
          setState(() {
            _showSelectionBar = false;
            _selectionText = '';
          });
        },
        onProgress: (p) => _controller.onProgress(p),
        onPageFinished: _onPageFinished,
        onWebResourceError: (err) => _controller.onError(err.description),
        onNavigationRequest: (req) {
          // Block popup windows, allow everything else
          return req.isMainFrame
              ? NavigationDecision.navigate
              : NavigationDecision.prevent;
        },
      ));

    // Load initial URL
    final url = widget.initialUrl ??
        WebReaderController.normalizeUrl('https://www.bbc.com/news');
    _webCtrl.loadRequest(Uri.parse(url));
  }

  Future<void> _onPageFinished(String url) async {
    // Lấy title
    final title = await _webCtrl
        .runJavaScriptReturningResult(WebReaderJS.getTitleScript)
        .then((v) => v.toString().replaceAll('"', ''))
        .catchError((_) => '');

    _controller.onPageFinished(url, title);

    // Lấy back/forward state
    final canBack = await _webCtrl.canGoBack().catchError((_) => false);
    final canFwd = await _webCtrl.canGoForward().catchError((_) => false);
    _controller.onNavigationStateChange(
        canGoBack: canBack, canGoForward: canFwd);

    // Setup selection listener
    await _webCtrl
        .runJavaScript(WebReaderJS.setupSelectionListenerScript)
        .catchError((_) {});

    // Áp dụng highlight nếu đang bật
    if (_controller.colorMode != ColorMode.none) {
      await _applyHighlight();
    }

    // Thêm FAB
    await _updateFab();
  }

  // ── JS Message Handler ────────────────────────────────

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'wordTap':
          final word = data['word'] as String? ?? '';
          if (word.isEmpty) return;
          _controller.onWordTapped(word);
          // Hiện word sheet
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
          _controller.onTextSelected(text);
          setState(() {
            _showSelectionBar = true;
            _selectionText = text;
          });
          break;

        case 'fabTap':
          // FAB trên trang web → cycle color mode
          _controller.cycleColorMode();
          _applyHighlight();
          _updateFab();
          break;
      }
    } catch (e) {
      debugPrint('WebReaderScreen: JS message parse error: $e');
    }
  }

  // ── Apply Highlight ───────────────────────────────────

  Future<void> _applyHighlight() async {
    if (_controller.state != WebReaderState.ready) return;
    try {
      final config = _controller.buildHighlightConfig();
      final script = WebReaderJS.buildHighlightScript(config);
      await _webCtrl.runJavaScript(script);
    } catch (e) {
      debugPrint('WebReaderScreen: _applyHighlight error: $e');
    }
  }

  Future<void> _removeHighlight() async {
    try {
      await _webCtrl.runJavaScript(WebReaderJS.removeHighlightScript);
    } catch (_) {}
  }

  Future<void> _updateFab() async {
    try {
      final config = _controller.buildHighlightConfig();
      await _webCtrl.runJavaScript(WebReaderJS.buildFabScript(config));
    } catch (_) {}
  }

  // ── Navigation ────────────────────────────────────────

  Future<void> _navigate(String urlOrCommand) async {
    if (urlOrCommand == '__back__') {
      await _webCtrl.goBack();
    } else if (urlOrCommand == '__forward__') {
      await _webCtrl.goForward();
    } else {
      await _webCtrl.loadRequest(Uri.parse(urlOrCommand));
    }
  }

  // ── Extract Text → Text Studio ────────────────────────

  Future<void> _extractTextToStudio() async {
    if (_controller.state != WebReaderState.ready) return;

    // Show loading
    _showSnack('⏳ Đang trích xuất văn bản...', duration: 1);

    try {
      final raw = await _webCtrl
          .runJavaScriptReturningResult(WebReaderJS.extractMainTextScript);

      var text = raw.toString();

      // JavaScript trả về string có quotes
      if (text.startsWith('"') && text.endsWith('"')) {
        text = text.substring(1, text.length - 1);
      }
      // Unescape JS string
      text = text
          .replaceAll('\\n', '\n')
          .replaceAll('\\t', ' ')
          .replaceAll('\\"', '"')
          .replaceAll("\\'", "'")
          .trim();

      if (text.isEmpty) {
        _showSnack('❌ Không thể extract text từ trang này');
        return;
      }

      if (mounted) {
        context.read<TextProvider>().loadFromString(
              text,
              title: _controller.pageTitle,
            );

        _showSnack(
            '✅ Đã load vào Text Studio — ${text.split('\n').length} dòng');

        // Pop back nếu đây là push screen
        // Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('WebReaderScreen: extract error: $e');
      _showSnack('❌ Lỗi: $e');
    }
  }

  void _showSnack(String msg, {int duration = 3}) {
    final now = DateTime.now();
    if (_lastSnackbar != null && now.difference(_lastSnackbar!).inSeconds < 1)
      return;
    _lastSnackbar = now;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF1A237E),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: duration),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Color Mode toggle + apply ─────────────────────────

  Future<void> _toggleColorMode() async {
    _controller.cycleColorMode();
    if (_controller.colorMode == ColorMode.none) {
      await _removeHighlight();
    } else {
      await _applyHighlight();
    }
    await _updateFab();
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) {
      return const Scaffold(
          body: Center(
              child: Text("Web Reader trên Windows đang được phát triển")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Column(
        children: [
          // ── Top Toolbar ─────────────────────────────────
          WebReaderToolbar(
            controller: _controller,
            onNavigate: _navigate,
            onExtractText: _extractTextToStudio,
          ),

          // ── WebView ─────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _webCtrl),

                // Error overlay
                if (_controller.state == WebReaderState.error)
                  _buildErrorOverlay(),

                // Highlight legend
                if (_controller.isHighlightActive) _buildColorLegend(),
              ],
            ),
          ),

          // ── Selection action bar ─────────────────────────
          if (_showSelectionBar && _selectionText.isNotEmpty)
            _buildSelectionBar(),
        ],
      ),
    );
  }

  // ── Error Overlay ─────────────────────────────────────

  Widget _buildErrorOverlay() {
    return Container(
      color: const Color(0xFF0D1117),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Không thể tải trang',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _webCtrl.reload(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3)),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Color Legend ──────────────────────────────────────

  Widget _buildColorLegend() {
    final items = _controller.colorMode == ColorMode.cefrLevel
        ? [
            ('A1', const Color(0xFF78909C)),
            ('A2', const Color(0xFF42A5F5)),
            ('B1', const Color(0xFF66BB6A)),
            ('B2', const Color(0xFFFFCA28)),
            ('C1', const Color(0xFFFF7043)),
            ('C2', const Color(0xFFEF5350)),
          ]
        : [
            ('Noun', const Color(0xFF42A5F5)),
            ('Verb', const Color(0xFFEF5350)),
            ('Adj', const Color(0xFF66BB6A)),
            ('Adv', const Color(0xFFFFCA28)),
            ('Prep', const Color(0xFFAB47BC)),
          ];

    return Positioned(
      bottom: 8,
      left: 8,
      child: GestureDetector(
        onTap: _toggleColorMode,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.$2,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      item.$1,
                      style: TextStyle(
                          color: item.$2,
                          fontSize: 9,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Selection Bar ────────────────────────────────────

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1A237E),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '"$_selectionText"',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),

          // TTS
          IconButton(
            icon: const Icon(Icons.volume_up, color: Colors.blue, size: 20),
            onPressed: () => _controller.speakText(_selectionText),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),

          // Save to Memory
          IconButton(
            icon: const Icon(Icons.psychology, color: Colors.purple, size: 20),
            onPressed: () {
              _controller.saveWordToMemory(_selectionText);
              setState(() => _showSelectionBar = false);
              _showSnack('✅ Đã lưu vào Vườn Nhớ');
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),

          // Load selection → Text Studio
          IconButton(
            icon: const Icon(Icons.text_fields, color: Colors.green, size: 20),
            onPressed: () {
              if (_selectionText.length > 10) {
                context
                    .read<TextProvider>()
                    .loadFromString(_selectionText, title: 'Web selection');
                setState(() => _showSelectionBar = false);
                _showSnack('✅ Đã load selection vào Text Studio');
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),

          // Close
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 16),
            onPressed: () => setState(() => _showSelectionBar = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}
