//
// Mini bottom sheet hiển thị YouGlish trực tiếp từ Word List row
// Mở nhanh, không cần navigate sang màn hình riêng

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../youglish/youglish_config.dart';

class YouGlishMiniSheet extends StatefulWidget {
  final String word;

  const YouGlishMiniSheet({super.key, required this.word});

  static Future<void> show(BuildContext context, String word) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => YouGlishMiniSheet(word: word),
    );
  }

  @override
  State<YouGlishMiniSheet> createState() => _YouGlishMiniSheetState();
}

class _YouGlishMiniSheetState extends State<YouGlishMiniSheet> {
  YouGlishLanguage _lang = YouGlishLanguage.english;
  YouGlishAccent _accent = YouGlishAccent.us;
  bool _isLoading = true;
  WebViewController? _ctrl;

  static const _accentOptions = [
    YouGlishAccent.us,
    YouGlishAccent.uk,
    YouGlishAccent.aus,
  ];

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1A1A2E))
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
    if (_lang == YouGlishLanguage.english) {
      url += '/${_lang.code}/${_accent.code}';
    } else {
      url += '/${_lang.code}';
    }
    url += '?embed=1&autoplay=1';
    return url;
  }

  void _reload() {
    if (mounted) setState(() => _isLoading = true);
    _ctrl?.loadRequest(Uri.parse(_buildUrl()));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1117),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle (Draggable part)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)],
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.record_voice_over,
                          size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.word,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Reload button
                    IconButton(
                      icon: const Icon(Icons.refresh,
                          size: 18, color: Colors.grey),
                      onPressed: _reload,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    // Copy word
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.word));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã copy'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Icon(Icons.copy_outlined,
                          color: Colors.grey[600], size: 18),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child:
                          Icon(Icons.close, color: Colors.grey[600], size: 20),
                    ),
                  ],
                ),
              ),

              // Lang + Accent selector
              _buildControls(),

              const SizedBox(height: 8),

              // WebView
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        if (_ctrl != null)
                          WebViewWidget(
                            controller: _ctrl!,
                            gestureRecognizers: {
                              Factory<VerticalDragGestureRecognizer>(
                                  () => VerticalDragGestureRecognizer()),
                              Factory<HorizontalDragGestureRecognizer>(
                                  () => HorizontalDragGestureRecognizer()),
                              Factory<ScaleGestureRecognizer>(
                                  () => ScaleGestureRecognizer()),
                              Factory<TapGestureRecognizer>(
                                  () => TapGestureRecognizer()),
                            },
                          ),
                        if (_isLoading)
                          Container(
                            color: const Color(0xFF1A1A2E),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation(
                                        Color(0xFF00BCD4)),
                                    strokeWidth: 2,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Đang tải YouGlish...',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: bottomPad + 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Language chips
          ...YouGlishLanguage.values.take(5).map((lang) {
            final sel = _lang == lang;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() => _lang = lang);
                  _reload();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFF00BCD4)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    lang.displayName.split(' ').first,
                    style: TextStyle(
                      color: sel ? Colors.white : Colors.grey[400],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }),

          // Divider
          if (_lang == YouGlishLanguage.english) ...[
            Container(
                width: 1,
                height: 20,
                color: Colors.white.withValues(alpha: 0.12),
                margin: const EdgeInsets.symmetric(horizontal: 6)),
            // Accent chips
            ..._accentOptions.map((acc) {
              final sel = _accent == acc;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _accent = acc);
                    _reload();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFF4CAF50)
                          : Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      acc.displayName.split(' ').first,
                      style: TextStyle(
                        color: sel ? Colors.white : Colors.grey[400],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
