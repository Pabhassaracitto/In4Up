// lib/screens/tools/youglish/youglish_view.dart
//
// PRON-001 (ADR-0015 D5) — LỚP DUY NHẤT của app dựng WebView YouGlish.
//
// Trước PRON-001 tồn tại song song:
//   • `youglish_widget.dart`  — tự tạo WebViewController + tự viết `_buildUrl()`
//     (có nhánh Windows `webview_win_floating`)
//   • `word_list/youglish_mini_sheet.dart` (nay là
//     `tools/youglish/youglish_mini_sheet.dart`) — tự tạo WebViewController + COPY
//     `_buildUrl()` (KHÔNG có nhánh Windows, chip ngôn ngữ bị `.take(5)`)
// ⇒ PRON-001 gom cả hai về đây; hai file kia còn là shell gọi `YouGlishView`,
//   để `youglish_screen` và WordList giữ nguyên giao diện + hành vi cũ.
//
// ⚠️ File này import `dart:io` (chọn controller theo nền tảng) ⇒ CẤM import nó vào
//    cây reachable từ `lib/main_web.dart` (build web `deploy-web.yml` sẽ đỏ).
//    Nếu sau này cần YouGlish trên web: làm wrapper `web/youglish_embed.html`
//    theo tiền lệ `web/yt_embed.html` (ADR-0015 D6).
//
// Vài quyết định kỹ thuật đã trả giá bằng bug (giữ nguyên như cũ, đừng "sửa"):
//   • controller là nullable + tạo trong initState — `late final` từng làm crash
//     khi `didUpdateWidget` gán lại (Windows);
//   • `didUpdateWidget` chỉ `loadRequest(url)`, KHÔNG dựng controller mới;
//   • mọi `setState` trong callback WebView phải guard `if (mounted)`.

import 'dart:io';

// `Factory` cho gestureRecognizers (cùng bộ import như youglish_mini_sheet cũ).
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
// localized_material export flutter/material (hide Text) + cho `context.uiText`.
// KHÔNG import thẳng flutter/material: `Text` sẽ xung đột giữa 2 nguồn.
import 'package:in4up/core/language/localized_material.dart';
// Mobile: webview_flutter. Windows: webview_win_floating (cùng API, khác tên class).
import 'package:webview_flutter/webview_flutter.dart';
// PRON-002: `WKWebViewPlatform` + `WKWebViewParams` (inline playback iOS).
// Chỉ dùng trong `YouGlishView` — file này vốn đã nằm NGOÀI cây web.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:webview_win_floating/webview_win_floating.dart';

import 'youglish_config.dart';

class YouGlishView extends StatefulWidget {
  const YouGlishView({
    super.key,
    required this.word,
    this.language = YouGlishLanguage.english,
    this.accent,
    this.autoplay = true,
    this.height,
    this.radius = 16,
    this.webBackgroundColor = Colors.transparent,
    this.indicatorColor = const Color(0xFF6C63FF),
    this.loadingMessage,
    this.claimGestures = false,
    this.reloadToken = 0,
    this.onLoadError,
    this.onLoaded,
  });

  final String word;
  final YouGlishLanguage language;

  /// `null` với ngôn ngữ không phải English — YouGlish chỉ nhận accent ở
  /// English (`YouGlishUrl.build` đã guard).
  final YouGlishAccent? accent;

  /// PRON-001: mặc định `true` = đúng hành vi cũ của 2 điểm vào.
  /// PRON-003 đổi mặc định sang `false` cho toàn app (có chủ đích).
  final bool autoplay;

  /// `null` = chiếm hết khung cha.
  final double? height;

  final double radius;
  final Color webBackgroundColor;
  final Color indicatorColor;

  /// `null` = chỉ có spinner (như `YouGlishWidget` cũ); chuỗi sẽ qua
  /// `context.uiText` khi render (rule #5).
  final String? loadingMessage;

  /// Mini sheet cũ khai 4 `gestureRecognizers` để kéo WebView không bị Draggable
  /// ScrollableSheet cướp — bật `true` khi View nằm trong sheet kéo được.
  final bool claimGestures;

  /// Tăng lên ⇒ nạp lại cùng URL (nút "Tải lại" của mini sheet).
  final int reloadToken;

  /// Hook cho bậc thoái lui (PRON-002: tự hạ về audio từ điển → TTS).
  final VoidCallback? onLoadError;

  /// PRON-002: báo trang đã nạp XONG — dùng để tắt đồng hồ chờ 8 s của
  /// `YouGlishMiniSheet`. Cộng tính, mặc định `null` ⇒ `YouGlishWidget` /
  /// `youglish_screen` giữ nguyên hành vi.
  final VoidCallback? onLoaded;

  @override
  State<YouGlishView> createState() => YouGlishViewState();
}

class YouGlishViewState extends State<YouGlishView> {
  /// Set này là `final` cấp file vì `Factory` không có constructor const.
  static final Set<Factory<OneSequenceGestureRecognizer>> _claimRecognizers = {
    Factory<VerticalDragGestureRecognizer>(
        () => VerticalDragGestureRecognizer()),
    Factory<HorizontalDragGestureRecognizer>(
        () => HorizontalDragGestureRecognizer()),
    Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
    Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
  };

  WebViewController? _mobileCtrl;
  WinWebViewController? _winCtrl;
  bool _isLoading = true;

  String get url => YouGlishUrl.build(
        word: widget.word,
        language: widget.language,
        accent: widget.accent,
        autoplay: widget.autoplay,
      );

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _initWindows();
    } else {
      _initMobile();
    }
  }

  // ── Windows ─────────────────────────────────────────────────────
  void _initWindows() {
    _winCtrl = WinWebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(WinNavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
          widget.onLoaded?.call();
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _isLoading = false);
          widget.onLoadError?.call();
        },
      ))
      ..loadRequest(Uri.parse(url));
  }

  // ── Mobile (Android / iOS) ───────────────────────────────────────
  void _initMobile() {
    // PRON-002 — TRẢ NỢ PRON-001 (iOS inline playback). Khóa media là THAM SỐ
    // KHỞI TẠO, không phải setter: `WebViewController` của webview_flutter 4.x
    // KHÔNG có `setMediaPlaybackRequiresUserGesture` (CI PRON-001 đã báo ERROR
    // vì dòng đó). API dưới đây ĐÃ ĐỐI CHIẾU thẳng vào source đã publish của
    // `webview_flutter_wkwebview 3.25.1`
    // (`lib/src/webkit_webview_controller.dart`):
    //   • class tham số: `WebKitWebViewControllerCreationParams`
    //     (KHÔNG phải `WKWebViewParams` — tên đó thuộc bản 4.x trở lên);
    //   • `allowsInlineMediaPlayback` (bool, mặc định false);
    //   • KHÔNG còn `mediaPlaybackRequiresUserGesture` ở bản này — tương đương
    //     là `mediaTypesRequiringUserAction: <PlaybackMediaTypes>{}` (set rỗng
    //     = audio+video không cần thao tác người dùng trước).
    // Android nhận `PlatformWebViewControllerCreationParams` gốc ⇒ hành vi cũ
    // không đổi. ⚠️ Nếu sau này nâng `webview_flutter_wkwebview` lên 4.x: đổi
    // sang `WKWebViewConfiguration` (khi đó `WKWebViewParams` mới tồn tại).
    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params =
          WebKitWebViewControllerCreationParams.fromPlatformWebViewControllerCreationParams(
        params,
        allowsInlineMediaPlayback: true,
        // autoplay vẫn do YouTube chặn (cần mute) — PRON-003 mới đổi mặc định
        // `youglish.autoplay` thành false một cách có chủ đích.
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    }
    _mobileCtrl = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.webBackgroundColor)
      // ⚠️ iOS media: mọi khóa liên quan PLAYBACK đều nằm ở khối `params` ĐẦU
      // `_initMobile()` (xem comment ở đó) — `WebViewController` không có setter
      // nào cho chúng. Muốn đổi: sửa `WebKitWebViewControllerCreationParams`,
      // và NGHIỆM THU TRÊN IPHONE THẬT (không có bằng chứng nào khác là đủ).
      // Lưu ý: PRON-001 cố tình KHÔNG đổi hành vi iOS của 2 điểm vào cũ
      // (`youglish_widget`, `youglish_screen`); PRON-002 chấp nhận đổi vì đây
      // là lần đầu YouGlish vào luồng đọc — xem ADR-0015 D2 + KANBAN PRON-002.
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _isLoading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _isLoading = false);
          widget.onLoaded?.call();
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _isLoading = false);
          widget.onLoadError?.call();
        },
      ))
      ..loadRequest(Uri.parse(url));
  }

  /// Nạp lại URL hiện tại / URL mới khi từ-ngôn ngữ-accent đổi.
  void reload() {
    if (mounted) setState(() => _isLoading = true);
    final uri = Uri.parse(url);
    _mobileCtrl?.loadRequest(uri);
    _winCtrl?.loadRequest(uri);
  }

  @override
  void didUpdateWidget(YouGlishView old) {
    super.didUpdateWidget(old);
    final changed = old.word != widget.word ||
        old.language != widget.language ||
        old.accent != widget.accent ||
        old.autoplay != widget.autoplay;
    if (!changed && old.reloadToken == widget.reloadToken) return;
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Stack(
          children: [
            if (Platform.isWindows && _winCtrl != null)
              WinWebViewWidget(controller: _winCtrl!)
            else if (_mobileCtrl != null)
              widget.claimGestures
                  // Kéo trong sheet kéo được mà không bị DraggableScrollableSheet
                  // cướp gesture (đúng 4 recognizer mini sheet cũ khai).
                  ? WebViewWidget(
                      controller: _mobileCtrl!,
                      gestureRecognizers: _claimRecognizers,
                    )
                  : WebViewWidget(controller: _mobileCtrl!)
            else
              const SizedBox.shrink(),
            if (_isLoading) _buildLoading(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    final message = widget.loadingMessage;
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: message == null
            ? CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(widget.indicatorColor),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(widget.indicatorColor),
                    strokeWidth: 2,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.uiText(message),
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
      ),
    );
  }
}
