// lib/screens/tools/youglish/youglish_widget.dart
//
// ★ FIX Windows: dùng webview_win_floating cho Windows
//   (implement cùng interface với webview_flutter, chỉ đổi tên class)
// ★ FIX Android: bỏ `late final` → nullable, didUpdateWidget chỉ loadRequest
// ★ FIX setState: guard `if (mounted)` trong callbacks

import 'dart:io';

import 'package:flutter/material.dart';
// Mobile: webview_flutter
import 'package:webview_flutter/webview_flutter.dart';
// Windows: webview_win_floating (cùng API, chỉ khác tên class)
import 'package:webview_win_floating/webview_win_floating.dart';

import 'youglish_config.dart';

class YouGlishWidget extends StatefulWidget {
  final String word;
  final YouGlishLanguage language;
  final YouGlishAccent? accent;
  final double? height; // null = fill parent
  final bool autoPlay;

  const YouGlishWidget({
    Key? key,
    required this.word,
    this.language = YouGlishLanguage.english,
    this.accent = YouGlishAccent.us,
    this.height, // null = fill parent
    this.autoPlay = true,
  }) : super(key: key);

  @override
  State<YouGlishWidget> createState() => _YouGlishWidgetState();
}

class _YouGlishWidgetState extends State<YouGlishWidget> {
  // ★ FIX: nullable thay vì late final → tránh reassign crash
  WebViewController? _mobileCtrl;
  WinWebViewController? _winCtrl;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _initWindows();
    } else {
      _initMobile();
    }
  }

  // ── Windows ─────────────────────────────────────────────
  void _initWindows() {
    _winCtrl = WinWebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(WinNavigationDelegate(
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

  // ── Mobile (Android / iOS) ───────────────────────────────
  void _initMobile() {
    _mobileCtrl = WebViewController()
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
    final changed = old.word != widget.word ||
        old.language != widget.language ||
        old.accent != widget.accent;
    if (!changed) return;

    // ★ FIX: chỉ load URL mới, KHÔNG tạo controller mới
    if (mounted) setState(() => _isLoading = true);
    final url = Uri.parse(_buildUrl());
    _mobileCtrl?.loadRequest(url);
    _winCtrl?.loadRequest(url);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height, // null → SizedBox fill parent
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF6C63FF).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6C63FF).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Chọn WebView widget theo platform
            if (Platform.isWindows && _winCtrl != null)
              WinWebViewWidget(controller: _winCtrl!)
            else if (_mobileCtrl != null)
              WebViewWidget(controller: _mobileCtrl!)
            else
              const SizedBox.shrink(),

            // Loading overlay
            if (_isLoading)
              Container(
                color: const Color(0xFF1A1A2E),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
