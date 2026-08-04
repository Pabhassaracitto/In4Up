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

import '../../models/color_mode.dart';
import '../../providers/text_provider.dart';
import 'js/web_reader_js.dart';
import 'web_reader_controller.dart';
import 'widgets/web_reader_home_view.dart';
import 'widgets/web_reader_toolbar.dart';
import 'widgets/web_word_tap_sheet.dart';

class WebReaderScreen extends StatefulWidget {
  final String? initialUrl;

  const WebReaderScreen({super.key, this.initialUrl});

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

  void _onStateChanged() {
    if (!mounted) {
      return;
    }

    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
    if (!isCurrentRoute) return;

    if (_controller.colorMode != _lastColorMode) {
      _lastColorMode = _controller.colorMode;
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
        'in2upChannel',
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
        'in2upChannel',
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

    if (_controller.colorMode != ColorMode.none) await _applyHighlight();
    await _updateFab();
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

    if (_controller.colorMode != ColorMode.none) await _applyHighlight();
    await _updateFab();
  }

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'wordTap':
          final word = data['word'] as String? ?? '';
          if (word.isEmpty) return;
          _controller.onWordTapped(word);
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
      }
    } catch (e) {
      debugPrint('WebReaderScreen: JS message parse error: $e');
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

  Future<void> _extractTextToStudio() async {
    if (_controller.state != WebReaderState.ready || _showDashboard) return;

    _showSnack('⏳ Đang trích xuất văn bản...', duration: 1);

    try {
      var raw = await _runJSReturning(WebReaderJS.extractMainTextScript);
      if (raw == null) {
        _showSnack('❌ Không thể extract text từ trang này');
        return;
      }

      var text = raw.toString();
      if (text.startsWith('"') && text.endsWith('"')) {
        text = text.substring(1, text.length - 1);
      }
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
          '✅ Đã load vào Text Studio — ${text.split('\n').length} dòng',
        );
      }
    } catch (e) {
      debugPrint('WebReaderScreen: extract error: $e');
      _showSnack('❌ Lỗi: $e');
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
          tooltip: 'Quay lại',
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
        ],
      ),
      body: Column(
        children: [
          WebReaderToolbar(
            controller: _controller,
            onNavigate: _navigate,
            onExtractText: _extractTextToStudio,
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
            Text(
              'Không thể tải trang',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
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
              : 'Loại từ: N V Adj Adv',
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
          GestureDetector(
            onTap: () {
              _controller.speakText(_selectionText);
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.volume_up, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _showSelectionBar = false),
            child: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}
