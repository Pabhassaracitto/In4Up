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
//   File này là entrypoint **RIÊNG cho web**: chỉ dùng các adapter web-safe
//   (browser audio, Firebase Web, local storage, clipboard, proxy HTTP và
//   url_launcher) ⇒ build được mà không kéo theo phần FFI/native.
//
//   ⇒ Workflow `.github/workflows/deploy-web.yml`:
//        flutter build web --release --base-href /In4Up/ -t lib/main_web.dart
//     rồi push kết quả vào nhánh `gh-pages` (GIỮ NGUYÊN file khác — vd
//     wrapper YouTube `yt_embed.html` đang chạy trên Pages).
//
// PHẠM VI WEB CORE:
//   * đọc văn bản dán tay hoặc qua reader proxy;
//   * phát audio URL thông thường bằng browser audio;
//   * dịch qua proxy kiểm soát (direct CORS chỉ bật khi explicitly requested);
//   * lưu draft/từ vựng ở local storage;
//   * Firebase Auth/Firestore là lớp cloud tùy chọn;
//   * sao chép, lưu từ và mở YouTube wrapper cùng origin.
//
// Các tính năng native như FFI, STT offline, PDFium native, background audio,
// filesystem đầy đủ và engine mô hình local vẫn không được kéo vào entrypoint
// web này. Chúng phải có adapter Web riêng trước khi được bật trên browser.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio/just_audio.dart';
import 'package:in4up/core/language/localized_material.dart' hide Text;
import 'package:in4up/features/web_core/web_audio_playback.dart';
import 'package:in4up/features/web_core/web_cloud_service.dart';
import 'package:in4up/features/web_core/web_content_fetcher.dart';
import 'package:in4up/features/web_core/web_local_store.dart';
import 'package:in4up/features/web_core/web_proxy_translation_engine.dart';
import 'package:in4up/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lỗi chạy lúc khởi động (nếu có) — hiện NGAY trên trang thay vì trang
/// trắng, để owner thấy nguyên nhân mà không cần mở DevTools.
final ValueNotifier<String?> _fatalError = ValueNotifier<String?>(null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    _fatalError.value ??= details.exceptionAsString();
    FlutterError.presentError(details);
  };

  final cloud = await WebCloudService.initialize();
  final prefs = await _loadWebPreferences();

  runZonedGuarded(
    () => runApp(In4UpWebApp(cloud: cloud, prefs: prefs)),
    (error, stack) {
      _fatalError.value ??= error.toString();
    },
  );
}

Future<SharedPreferences> _loadWebPreferences() async {
  try {
    return await SharedPreferences.getInstance();
  } catch (error, stack) {
    // Keep the reader usable if browser storage is blocked (for example in a
    // private browsing context). The mock store is intentionally empty and
    // does not pretend that persistence is available.
    _fatalError.value ??= 'Local storage unavailable: $error';
    FlutterError.presentError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return SharedPreferences.getInstance();
  }
}

/// App web In4Up.
class In4UpWebApp extends StatelessWidget {
  const In4UpWebApp({
    super.key,
    required this.cloud,
    required this.prefs,
  });

  final WebCloudService cloud;
  final SharedPreferences prefs;

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
      // TRẮNG: MaterialApp KHÔNG có `home` ⇒ Navigator rỗng ⇒ trắng.
      // Đã fix: thêm `home` + builder hiển thị lỗi khởi động bằng Stack.
      home: WebHomeScreen(cloud: cloud, prefs: prefs),
      builder: (context, child) {
        // Lắng nghe lỗi khởi động (ValueNotifier) ⇒ hiện banner đỏ bên trên.
        return ValueListenableBuilder<String?>(
          valueListenable: _fatalError,
          builder: (ctx, err, _) {
            if (err == null) return child ?? const SizedBox.shrink();
            return Stack(
              children: [
                if (child != null) child,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: const Color(0xFFEF4444),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: SelectableText(
                        err,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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
  const WebHomeScreen({
    super.key,
    required this.cloud,
    required this.prefs,
  });

  final WebCloudService cloud;
  final SharedPreferences prefs;

  @override
  State<WebHomeScreen> createState() => _WebHomeScreenState();
}

class _WebHomeScreenState extends State<WebHomeScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _videoCtrl = TextEditingController();
  final TextEditingController _audioUrlCtrl = TextEditingController();
  final WebContentFetcher _contentFetcher = WebContentFetcher();
  final WebProxyTranslationEngine _engine = WebProxyTranslationEngine();
  final WebAudioPlaybackController _audio = WebAudioPlaybackController();

  late final WebLocalStore _local;
  List<String> _lines = const [];
  Map<int, String> _translations = const {};
  List<String> _savedWords = const [];
  bool _translating = false;
  bool _loading = false;
  bool _audioLoading = false;
  bool _cloudLoading = false;
  String? _error;
  String? _translationError;
  String? _audioError;

  @override
  void initState() {
    super.initState();
    _local = WebLocalStore(widget.prefs);
    _savedWords = _local.savedWords;
    _restoreLocalDraft();
  }

  void _restoreLocalDraft() {
    final draft = _local.draft;
    if (draft.isEmpty) return;
    _textCtrl.text = draft;
    _lines = _splitLines(draft);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _urlCtrl.dispose();
    _videoCtrl.dispose();
    _audioUrlCtrl.dispose();
    _audio.dispose();
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
      _translationError = null;
      _error = null;
    });
    unawaited(_local.saveDraft(text));
    unawaited(_local.addRecentText(text));
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
      final html = await _contentFetcher.fetch(uri);
      if (!mounted) return;
      final text = _htmlToText(html);
      if (text.trim().isEmpty) {
        _setError(context.uiText('Chưa có nội dung'));
        return;
      }
      setState(() {
        _lines = _splitLines(text);
        _translations = const {};
        _translationError = null;
      });
      _textCtrl.text = text;
      unawaited(_local.saveDraft(text));
      unawaited(_local.addRecentText(text));
    } catch (e) {
      // CORS/proxy/mạng — nói rõ thay vì nuốt lỗi.
      if (mounted) {
        _setError('${context.uiText('Không tải được trang')}: $e');
      }
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

  // ── Dịch qua proxy kiểm soát sang tiếng Việt ─────────────────────────
  Future<void> _translateAll() async {
    if (_lines.isEmpty || _translating) return;
    setState(() {
      _translating = true;
      _translationError = null;
    });
    final out = <int, String>{};
    String? firstError;

    for (var i = 0; i < _lines.length; i++) {
      try {
        final result = await _engine.translate(
          text: _lines[i],
          targetLang: 'vi',
        );
        final t = result.translatedText.trim();
        if (result.isSuccess && t.isNotEmpty) {
          out[i] = t;
        } else {
          firstError ??= result.error;
        }
      } catch (error) {
        firstError ??= '$error';
      }

      if (i % 5 == 0 && mounted) {
        setState(() => _translations = Map.of(out));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }

    if (mounted) {
      setState(() {
        _translations = out;
        _translationError = firstError;
        _translating = false;
      });
    }
  }

  // ── Phát audio thông thường trên browser ───────────────────────────────
  Future<void> _loadAudio() async {
    final raw = _audioUrlCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _audioError = context.uiText('URL audio không hợp lệ'));
      return;
    }

    setState(() {
      _audioLoading = true;
      _audioError = null;
    });
    try {
      await _audio.loadUrl(raw);
      if (mounted) await _audio.player.play();
    } catch (error) {
      if (mounted) {
        setState(() => _audioError = '$error');
      }
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }

  Future<void> _saveWord(String word) async {
    final normalized = word.trim();
    if (normalized.isEmpty) return;

    final next = <String>[normalized, ..._savedWords.where((w) => w != normalized)];
    setState(() => _savedWords = next);
    await _local.saveWords(next);

    if (widget.cloud.isSignedIn) {
      try {
        await widget.cloud.saveVocabularyWord(normalized);
      } catch (error) {
        if (mounted) {
          setState(() => _error = 'Đã lưu local nhưng chưa đồng bộ cloud: $error');
        }
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${context.uiText('Đã lưu từ')}: $normalized'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _cloudLoading = true);
    try {
      await widget.cloud.signInWithGoogle();
      final cloudWords = await widget.cloud.loadVocabularyWords();
      if (cloudWords.isNotEmpty && mounted) {
        final merged = <String>[
          ...cloudWords,
          ..._savedWords.where((word) => !cloudWords.contains(word)),
        ];
        setState(() => _savedWords = merged);
        await _local.saveWords(merged);
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _cloudLoading = false);
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
            _accountCard(context),
            const SizedBox(height: 12),
            _sourceCard(context),
            const SizedBox(height: 12),
            _audioCard(context),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _errorBox(context, _error!),
            ],
            if (_translationError != null) ...[
              const SizedBox(height: 12),
              _errorBox(context, _translationError!),
            ],
            if (hasContent) ...[
              const SizedBox(height: 16),
              _readerCard(context),
            ],
            if (_savedWords.isNotEmpty) ...[
              const SizedBox(height: 16),
              _savedWordsCard(context),
            ],
            const SizedBox(height: 24),
            _youtubeCard(context),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.cloud,
      builder: (context, _) {
        final user = widget.cloud.user;
        final cloudError = widget.cloud.initializationError;
        return Card(
          color: const Color(0xFF111827),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  user == null ? Icons.cloud_off_outlined : Icons.cloud_done,
                  color: user == null
                      ? Colors.white54
                      : const Color(0xFF81C784),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        !widget.cloud.isConfigured
                            ? context.uiText('Cloud sync chưa cấu hình')
                            : user == null
                                ? context.uiText(
                                    'Đăng nhập để đồng bộ từ vựng',
                                  )
                                : (user.email ??
                                    user.displayName ??
                                    'Đã đăng nhập'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (cloudError != null)
                        Text(
                          cloudError,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFCC80),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.cloud.isConfigured && user == null)
                  FilledButton.tonal(
                    onPressed: _cloudLoading ? null : _signInWithGoogle,
                    child: _cloudLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.uiText('Đăng nhập')),
                  ),
                if (user != null)
                  IconButton(
                    tooltip: context.uiText('Đăng xuất'),
                    onPressed: widget.cloud.signOut,
                    icon: const Icon(Icons.logout),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _audioCard(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText('Phát audio trên trình duyệt'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _audioUrlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: context.uiText('Dán URL audio trực tiếp'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _audioLoading ? null : _loadAudio,
                  child: _audioLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.uiText('Mở')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<PlayerState>(
              stream: _audio.player.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return Row(
                  children: [
                    IconButton(
                      tooltip: playing
                          ? context.uiText('Tạm dừng')
                          : context.uiText('Phát'),
                      onPressed: _audio.player.processingState ==
                              ProcessingState.idle
                          ? null
                          : () => playing
                              ? _audio.player.pause()
                              : _audio.player.play(),
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    ),
                    Expanded(
                      child: StreamBuilder<Duration>(
                        stream: _audio.player.positionStream,
                        builder: (context, positionSnapshot) {
                          final position = positionSnapshot.data ?? Duration.zero;
                          return StreamBuilder<Duration?>(
                            stream: _audio.player.durationStream,
                            builder: (context, durationSnapshot) {
                              final duration = durationSnapshot.data ?? Duration.zero;
                              final max = duration.inMilliseconds.toDouble();
                              final value = max <= 0
                                  ? 0.0
                                  : position.inMilliseconds
                                      .clamp(0, duration.inMilliseconds)
                                      .toDouble();
                              return Slider(
                                min: 0,
                                max: max <= 0 ? 1 : max,
                                value: value,
                                onChanged: max <= 0
                                    ? null
                                    : (next) => _audio.player.seek(
                                          Duration(milliseconds: next.round()),
                                        ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: context.uiText('Dừng'),
                      onPressed: () => _audio.player.stop(),
                      icon: const Icon(Icons.stop),
                    ),
                  ],
                );
              },
            ),
            if (_audioError != null)
              Text(
                _audioError!,
                style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Widget _savedWordsCard(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.uiText('Từ đã lưu trên Web'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final word in _savedWords)
                  InputChip(
                    label: Text(word),
                    onDeleted: () {
                      final next = _savedWords.where((w) => w != word).toList();
                      setState(() => _savedWords = next);
                      unawaited(_local.saveWords(next));
                    },
                  ),
              ],
            ),
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
            const SizedBox(height: 8),
            Text(
              _contentFetcher.usesProxy
                  ? context.uiText('Web Reader đang dùng proxy kiểm soát')
                  : _contentFetcher.isConfigured
                      ? context.uiText('Web Reader direct CORS chỉ dành cho dev')
                      : context.uiText(
                          'Web Reader cần cấu hình IN4UP_WEB_PROXY_BASE_URL',
                        ),
              style: TextStyle(
                color: _contentFetcher.usesProxy
                    ? const Color(0xFF81C784)
                    : _contentFetcher.isConfigured
                        ? const Color(0xFFFFCC80)
                        : Colors.white54,
                fontSize: 11,
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
          FilledButton.tonal(
            onPressed: () {
              unawaited(_saveWord(word));
              Navigator.of(dialogCtx).pop();
            },
            child: Text(context.uiText('Lưu từ')),
          ),
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
