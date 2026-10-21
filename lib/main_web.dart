// lib/main_web.dart
//
// ENTRYPOINT WEB của In4Up — bản web **tối giản nhưng thật** (web-safe).
//
// VÌ SAO CÓ FILE NÀY (bối cảnh — IN4-109 / WEB-BUILD-001):
//   `flutter build web` compile ENTRYPOINT (mặc định `lib/main.dart`) cho web.
//   App chính dùng **native**: FFI (whisper / sherpa / UltraTimeStretch) + đọc
//   ghi file ⇒ `dart:ffi` / `dart:io` — hai thư viện **KHÔNG tồn tại trên web**.
//   ⇒ build web đỏ với:
//      "Error: Dart library 'dart:ffi' is not available on this platform."
//   (63 file reachable từ `lib/main.dart` dùng 2 thư viện này.)
//
//   File này là entrypoint **RIÊNG cho web**: chỉ dùng những gì web-safe
//   (http, clipboard, engine dịch Google-free, url_launcher) ⇒ build được và
//   KHÔNG kéo theo bất kỳ phần native nào.
//
//   ⇒ Workflow `.github/workflows/deploy-web.yml`:
//        flutter build web --release --base-href /In4Up/ -t lib/main_web.dart
//     rồi push kết quả vào nhánh `gh-pages` (GIỮ NGUYÊN file khác — vd
//     wrapper YouTube `yt_embed.html` đang chạy trên Pages).
//
// PHẠM VI (nói thẳng để không gây hiểu nhầm):
//   Đây là **bản web rút gọn**: đọc văn bản (dán tay / dán URL), dịch Google
//   free sang tiếng Việt, sao chép từ, mở trình phát YouTube nhúng.
//   Toàn bộ tính năng native (TTS offline, STT whisper, kho từ vựng, thư viện,
//   YouTube trình phát đầy đủ, tipitaka…) **vẫn nằm ở app mobile/desktop** —
//   bản đó vẫn build & phát hành bình thường.
//
// Lưu ý CORS: gọi `http.get(url)` từ trình duyệt bị CORS chặn với phần lớn
// trang ⇒ hiển thị lỗi rõ ràng cho user (không nuốt lỗi).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:in4up/core/language/localized_material.dart' hide Text;
import 'package:in4up/features/translation/engines/google_free_engine.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lỗi chạy lúc khởi động (nếu có) — hiện NGAY trên trang thay vì trang
/// trắng, để owner thấy nguyên nhân mà không cần mở DevTools.
String? _fatalError;

void main() {
  FlutterError.onError = (details) {
    _fatalError ??= details.exceptionAsString();
    FlutterError.presentError(details);
  };
  runZonedGuarded(
    () => runApp(const In4UpWebApp()),
    (error, stack) {
      _fatalError ??= error.toString();
    },
  );
}

/// App web In4Up.
class In4UpWebApp extends StatelessWidget {
  const In4UpWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'In4Up',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale != null) {
          for (final locale in supportedLocales) {
            if (locale.languageCode == deviceLocale.languageCode) {
              return locale;
            }
          }
        }
        return const Locale('en', '');
      },
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _theme(),
      builder: (context, child) {
        final err = _fatalError;
        if (err == null) return child ?? const SizedBox.shrink();
        // Trang trắng là triệu chứng khó chịu nhất ⇒ hiện lỗi luôn.
        return Column(
          children: [
            Expanded(child: child ?? const SizedBox.shrink()),
            Material(
              color: const Color(0xFFEF4444),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  err,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  ThemeData _theme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C63FF),
        brightness: Brightness.dark,
        surface: const Color(0xFF080B1A),
        surfaceTint: const Color(0xFF6C63FF).withValues(alpha: 0.1),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: Color(0xFF1A1A2E),
      ),
    );
  }
}

/// Màn chính: nhập nội dung → đọc (+ dịch).
class WebHomeScreen extends StatefulWidget {
  const WebHomeScreen({super.key});

  @override
  State<WebHomeScreen> createState() => _WebHomeScreenState();
}

class _WebHomeScreenState extends State<WebHomeScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _videoCtrl = TextEditingController();
  final GoogleFreeEngine _engine = GoogleFreeEngine();

  List<String> _lines = const [];
  Map<int, String> _translations = const {};
  bool _translating = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _textCtrl.dispose();
    _urlCtrl.dispose();
    _videoCtrl.dispose();
    super.dispose();
  }

  void _setError(String? message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  // ── Đọc văn bản đã dán ────────────────────────────────────────────────
  void _readPasted() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      _setError(context.uiText('Chưa có nội dung'));
      return;
    }
    setState(() {
      _lines = _splitLines(text);
      _translations = const {};
      _error = null;
    });
  }

  /// Tách văn bản thành dòng (dòng dài vẫn để nguyên — UI tự xuống dòng).
  static List<String> _splitLines(String text) {
    return text
        .split(RegExp(r'\r\n|\r|\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  // ── Tải nội dung từ URL ───────────────────────────────────────────────
  Future<void> _loadUrl() async {
    final raw = _urlCtrl.text.trim();
    if (raw.isEmpty) {
      _setError(context.uiText('URL không hợp lệ'));
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      _setError(context.uiText('URL không hợp lệ'));
      return;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      _setError(context.uiText('URL không hợp lệ'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.get(
        uri,
        headers: const {'User-Agent': 'Mozilla/5.0 (In4Up web)'},
      );
      if (res.statusCode != 200) {
        _setError(
          '${context.uiText('Không tải được trang')} (HTTP ${res.statusCode})',
        );
        return;
      }
      final text = _htmlToText(res.body);
      if (text.trim().isEmpty) {
        _setError(context.uiText('Chưa có nội dung'));
        return;
      }
      setState(() {
        _lines = _splitLines(text);
        _translations = const {};
      });
      _textCtrl.text = text;
    } catch (e) {
      // CORS / mạng — nói rõ thay vì nuốt lỗi.
      _setError('${context.uiText('Không tải được trang')} (HTTP 0)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Bỏ thẻ HTML + script/style + giải mã entity cơ bản → text thuần.
  static String _htmlToText(String html) {
    var s = html;
    s = s.replaceAll(RegExp(r'(?is)<script.*?</script>'), ' ');
    s = s.replaceAll(RegExp(r'(?is)<style.*?</style>'), ' ');
    s = s.replaceAll(RegExp(r'(?is)<!--.*?-->'), ' ');
    s = s.replaceAll(RegExp(r'(?i)<br\s*/?>'), '\n');
    s = s.replaceAll(RegExp(r'(?i)</(p|div|li|h[1-6]|tr)>'), '\n');
    s = s.replaceAll(RegExp(r'(?s)<[^>]+>'), ' ');
    s = const HtmlUnescape().convert(s);
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n\s*\n+'), '\n');
    return s.trim();
  }

  // ── Dịch Google-free sang tiếng Việt ──────────────────────────────────
  Future<void> _translateAll() async {
    if (_lines.isEmpty || _translating) return;
    setState(() => _translating = true);
    final out = <int, String>{};
    for (var i = 0; i < _lines.length; i++) {
      try {
        final res = await _engine.translate(
          text: _lines[i],
          targetLang: 'vi',
        );
        final t = res.translatedText.trim();
        if (t.isNotEmpty) out[i] = t;
      } catch (_) {
        // Bỏ qua dòng lỗi — vẫn hiện phần đã dịch.
      }
      if (i % 5 == 0) {
        if (mounted) setState(() => _translations = Map.of(out));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    if (mounted) {
      setState(() {
        _translations = out;
        _translating = false;
      });
    }
  }

  // ── Sao chép ───────────────────────────────────────────────────────────
  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${context.uiText('Đã sao chép')}: $text'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ── Mở trình phát YouTube nhúng (wrapper cùng Pages) ──────────────────
  Future<void> _openYouTube() async {
    var id = _videoCtrl.text.trim();
    final uri = Uri.tryParse(id);
    if (uri != null && uri.hasScheme && uri.host.contains('youtu')) {
      id = uri.queryParameters['v'] ?? '';
    }
    if (id.isEmpty) {
      _setError(context.uiText('Video ID hoặc URL YouTube'));
      return;
    }
    // Cùng Pages ⇒ cùng origin ⇒ wrapper `yt_embed.html` vẫn chạy.
    // URL phải TUYỆT ĐỐI (url_launcher trên web không nhận URL tương đối);
    // `Uri.base` = trang hiện tại (web-only, không cần dart:html).
    final base = Uri.base;
    final url = base.replace(
      path: '${base.path}yt_embed.html',
      queryParameters: {'videoId': id},
    );
    final ok = await launchUrl(url, webOnlyWindowName: '_blank');
    if (!ok && mounted) {
      _setError(context.uiText('Không mở được trình phát'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _lines.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('In4Up · Web'),
        actions: [
          if (hasContent)
            IconButton(
              tooltip: context.uiText('Sao chép toàn bộ'),
              icon: const Icon(Icons.copy_all_rounded),
              onPressed: () => _copy(_lines.join('\n')),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _sourceCard(context),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _errorBox(context, _error!),
            ],
            if (hasContent) ...[
              const SizedBox(height: 16),
              _readerCard(context),
            ],
            const SizedBox(height: 24),
            _youtubeCard(context),
          ],
        ),
      ),
    );
  }

  Widget _sourceCard(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText('Dán văn bản để đọc'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textCtrl,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: context.uiText('Dán văn bản để đọc'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _readPasted,
                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                    label: Text(context.uiText('Đọc')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _loadUrl,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download_outlined, size: 18),
                    label: Text(
                      _loading
                          ? context.uiText('Đang tải…')
                          : context.uiText('Tải & đọc'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: context.uiText('Dán URL trang web'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readerCard(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${context.uiText('Dòng')} ${_lines.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _translating || _lines.isEmpty
                      ? null
                      : _translateAll,
                  icon: _translating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.translate, size: 16),
                  label: Text(context.uiText('Bản dịch')),
                ),
              ],
            ),
            const Divider(height: 18),
            for (var i = 0; i < _lines.length; i++)
              _lineBlock(context, i),
          ],
        ),
      ),
    );
  }

  Widget _lineBlock(BuildContext context, int index) {
    final words = _lines[index].split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final translation = _translations[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in words)
                GestureDetector(
                  onTap: () => _copy(w),
                  onLongPress: () => _showWordInfo(context, w),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      w,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          if (translation != null && translation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              translation,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showWordInfo(BuildContext context, String word) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(word),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText('Sao chép'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 8),
            SelectableText(word),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _copy(word);
              Navigator.of(dialogCtx).pop();
            },
            child: Text(context.uiText('Sao chép')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(context.uiText('Đóng')),
          ),
        ],
      ),
    );
  }

  Widget _youtubeCard(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText('Trình phát YouTube'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _videoCtrl,
              decoration: InputDecoration(
                hintText: context.uiText('Video ID hoặc URL YouTube'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openYouTube,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: Text(context.uiText('Mở trình phát YouTube')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Giải mã entity HTML cơ bản (không cần package `html`).
class HtmlUnescape {
  const HtmlUnescape();

  String convert(String input) {
    const named = <String, String>{
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&nbsp;': ' ',
      '&hellip;': '…',
      '&mdash;': '—',
      '&ndash;': '–',
    };
    var out = input;
    named.forEach((k, v) => out = out.replaceAll(k, v));
    // Entity số: &#123; / &#x1F600;
    out = out.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) => _codePoint(int.parse(m.group(1)!, radix: 16)),
    );
    out = out.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => _codePoint(int.parse(m.group(1)!)),
    );
    return out;
  }

  String _codePoint(int value) {
    if (value < 0 || value > 0x10FFFF) return '';
    return String.fromCharCode(value);
  }
}
