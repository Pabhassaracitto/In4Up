// lib/screens/tools/youglish/youglish_widget.dart
//
// ★ FIX Windows: webview_flutter KHÔNG hỗ trợ Windows
//   → Hiện nút "Mở trong trình duyệt" thay vì crash
//
// ★ FIX Android accent/search crash:
//   Bỏ `late final` → WebViewController? nullable
//   didUpdateWidget chỉ gọi loadRequest(), KHÔNG recreate controller
//
// ★ FIX setState: guard `if (mounted)` trong tất cả callbacks

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'youglish_config.dart';

class YouGlishWidget extends StatefulWidget {
  final String word;
  final YouGlishLanguage language;
  final YouGlishAccent? accent;
  final double height;
  final bool autoPlay;

  const YouGlishWidget({
    Key? key,
    required this.word,
    this.language = YouGlishLanguage.english,
    this.accent = YouGlishAccent.us,
    this.height = 400,
    this.autoPlay = true,
  }) : super(key: key);

  @override
  State<YouGlishWidget> createState() => _YouGlishWidgetState();
}

class _YouGlishWidgetState extends State<YouGlishWidget> {
  // ★ FIX: nullable thay vì late final → tránh reassign crash
  WebViewController? _controller;
  bool _isLoading = true;

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  void initState() {
    super.initState();
    if (!_isDesktop) _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
      ))
      ..loadRequest(Uri.parse(_buildUrl()));
  }

  String _buildUrl() {
    var url =
        'https://youglish.com/pronounce/${Uri.encodeComponent(widget.word)}';
    if (widget.language == YouGlishLanguage.english && widget.accent != null) {
      url += '/${widget.language.code}/${widget.accent!.code}';
    } else {
      url += '/${widget.language.code}';
    }
    url += '?embed=1';
    if (widget.autoPlay) url += '&autoplay=1';
    return url;
  }

  @override
  void didUpdateWidget(YouGlishWidget old) {
    super.didUpdateWidget(old);
    if (_isDesktop) return;
    if (old.word != widget.word ||
        old.language != widget.language ||
        old.accent != widget.accent) {
      // ★ FIX: KHÔNG tạo controller mới — chỉ load URL mới
      if (mounted) setState(() => _isLoading = true);
      _controller?.loadRequest(Uri.parse(_buildUrl()));
    }
  }

  Future<void> _openBrowser() async {
    final uri = Uri.parse(
      'https://youglish.com/pronounce/${Uri.encodeComponent(widget.word)}/${widget.language.code}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) =>
      _isDesktop ? _desktopFallback() : _mobileWebView();

  Widget _desktopFallback() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.open_in_browser,
                size: 48, color: Color(0xFF00BCD4)),
          ),
          const SizedBox(height: 16),
          const Text(
            'WebView không hỗ trợ trên Windows',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '"${widget.word}"',
            style: const TextStyle(
                color: Color(0xFF00BCD4),
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openBrowser,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Mở YouGlish trong trình duyệt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BCD4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileWebView() {
    final ctrl = _controller;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ctrl == null
            ? const Center(
                child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF))))
            : Stack(children: [
                WebViewWidget(controller: ctrl),
                if (_isLoading)
                  Container(
                    color: const Color(0xFF1A1A2E),
                    child: const Center(
                      child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF))),
                    ),
                  ),
              ]),
      ),
    );
  }
}
