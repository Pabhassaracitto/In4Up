import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/yt_video.dart';

class YtVideoCard extends StatelessWidget {
  final YtVideo video;
  final bool showPreview;
  final VoidCallback onPreviewToggle;

  const YtVideoCard({
    super.key,
    required this.video,
    required this.showPreview,
    required this.onPreviewToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: video.thumb != null
                ? Image.network(video.thumb!,
                    width: 84, height: 58,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.shortTitle,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(video.channel,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),

          // Preview toggle
          GestureDetector(
            onTap: onPreviewToggle,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: showPreview
                    ? Color(0xFFFF0000).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                showPreview ? Icons.visibility_off : Icons.play_arrow_rounded,
                color: showPreview
                    ? const Color(0xFFFF0000)
                    : Colors.white70,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 84,
        height: 58,
        color: Colors.grey[900],
        child: const Icon(Icons.play_circle_outline,
            color: Colors.grey, size: 28),
      );
}

// ─── Preview WebView ──────────────────────────────────────────

class YtPreviewWebView extends StatefulWidget {
  final String embedUrl;

  const YtPreviewWebView({super.key, required this.embedUrl});

  @override
  State<YtPreviewWebView> createState() => _YtPreviewWebViewState();
}

class _YtPreviewWebViewState extends State<YtPreviewWebView> {
  late final WebViewController _ctrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(widget.embedUrl));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 210,
        child: Stack(
          children: [
            WebViewWidget(controller: _ctrl),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation(Color(0xFFFF0000))),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── History List Item ────────────────────────────────────────

class YtHistoryItem extends StatelessWidget {
  final YtVideo video;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const YtHistoryItem({
    super.key,
    required this.video,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        tileColor: Colors.white.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: video.thumb != null
              ? Image.network(video.thumb!,
                  width: 56, height: 40, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _smallPlaceholder())
              : _smallPlaceholder(),
        ),
        title: Text(video.shortTitle,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(video.channel,
            style: const TextStyle(color: Colors.grey, fontSize: 10)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 16),
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ),
    );
  }

  Widget _smallPlaceholder() => Container(
        width: 56, height: 40,
        color: Colors.grey[900],
        child: const Icon(Icons.play_circle_outline,
            color: Colors.grey, size: 20),
      );
}

// ─── Action Button ────────────────────────────────────────────

class YtActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const YtActionBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
