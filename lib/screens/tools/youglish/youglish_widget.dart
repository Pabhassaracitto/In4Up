import 'package:flutter/material.dart';
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
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() {
    String url = _buildYouGlishUrl();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  String _buildYouGlishUrl() {
    String baseUrl = 'https://youglish.com/pronounce/${Uri.encodeComponent(widget.word)}';
    
    if (widget.language == YouGlishLanguage.english && widget.accent != null) {
      baseUrl += '/${widget.language.code}/${widget.accent!.code}';
    } else {
      baseUrl += '/${widget.language.code}';
    }
    
    baseUrl += '?embed=1';
    if (widget.autoPlay) {
      baseUrl += '&autoplay=1';
    }
    
    return baseUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: const Color(0xFF1A1A2E),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(YouGlishWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word != widget.word ||
        oldWidget.language != widget.language ||
        oldWidget.accent != widget.accent) {
      _initializeController();
    }
  }
}
