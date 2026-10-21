//
// Language Reactor-style video player:
// • Trái: YouTube iframe + subtitle lớn + dịch
// • Phải: Tab VĂN BẢN (transcript song ngữ) | TỪ (word analysis)
// • Click từ → popup nghĩa (động từ, danh từ...)
// • Nút ✓ Known | 📖 Learning
// • Tab TỪ: Known 36 / Learning 3 / Ignored 7, rank filter

import 'dart:async';
import 'dart:convert';
// YT-AUDIT-02 (IN4-98): chế độ "Làm mờ bản dịch" KHÔNG còn dùng
// `dart:ui` (MaskFilter / ImageFilter). Cả hai cách đó đều hỏng trên máy thật
// (xem chú thích tại `_buildTranslationLine`); giờ làm mờ bằng
// `TextStyle.shadows` — thuần Flutter, chạy được trên mọi backend.

import 'package:hive_flutter/hive_flutter.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../features/translation/translation_service.dart';
import '../../models/vocab_context.dart';
import '../../models/word_analysis.dart';
import '../../providers/player_provider.dart';
import '../../providers/text_provider.dart';
import '../../providers/vocabulary_bridge.dart';
import '../../services/syntax_highlighter_service.dart';
import 'models/yt_learning_settings.dart';
import 'models/yt_subtitle.dart';
import 'models/yt_video.dart';
import 'services/yt_downloader.dart';
import 'services/yt_learning_settings_service.dart';
import 'services/yt_sentence_segmenter.dart';
import 'services/yt_service.dart';
import 'widgets/yt_lexa_chat_tab.dart';
import 'widgets/yt_subtitle_settings_sheet.dart';
import 'widgets/yt_word_panel.dart';
import 'youtube_explorer_screen.dart';

// ─── IN4-78 — YouTube báo "Lỗi cấu hình trình phát video, mã 153" ───────
// YouTube (từ ~07/2025) yêu cầu request trang nhúng /embed/ phải có
// **HTTP Referer** hợp lệ ("API Clients that use the YouTube embedded
// player must provide identification through the HTTP Referer request
// header" — YouTube IFrame API docs). WebView của app không tạo đủ
// Referrer cho load top-level → player trả mã 153.
//
// Chain tải (từ chắc chắn nhất):
// 1) **Wrapper GitHub Pages** — `yt_embed.html?videoId=X` trên origin
//    https thật (pabhassaracitto.github.io); iframe /embed/ bên trong
//    tự gửi `Referer: https://pabhassaracitto.github.io…` → YouTube chấp
//    nhận (cách fix được cộng đồng xác minh nhiều nhất, 2025-2026).
//    Wrapper tự chứa IFrame API + kênh YtSync + báo lỗi qua `err:<code>`.
// 2) **Seed → embed trực tiếp** — load trước trang cùng domain
//    youtube-nocookie.com/embed rồi sang /embed/<id> (request mang
//    Referer same-origin). Dùng khi wrapper không tải được.
// 3) **Overlay + "Mở ngoài"** — nếu player vẫn lỗi: nút mở YouTube
//    trong trình duyệt/app hệ thống (luôn hoạt động).
// Hàm top-level để test thuần bắt được.

/// Wrapper static trên GitHub Pages (branch gh-pages của repo In4Up).
/// CẦN: repo Settings → Pages → Deploy from branch: gh-pages / (root).
const String kYtWrapperBaseUrl =
    'https://pabhassaracitto.github.io/In4Up/yt_embed.html';

/// URL wrapper cho 1 video.
String buildYtWrapperUrl(String videoId) =>
    '$kYtWrapperBaseUrl?videoId=$videoId';

/// Trang seed (fallback) — chỉ để tạo Referer cho request /embed/ kế tiếp.
const String kYtEmbedSeedUrl = 'https://www.youtube-nocookie.com/embed';

/// URL trang nhúng YouTube trực tiếp (fallback).
String buildYtEmbedUrl(String videoId) =>
    'https://www.youtube-nocookie.com/embed/$videoId'
    '?enablejsapi=1&cc_load_policy=0&rel=0&playsinline=1'
    '&origin=https://www.youtube-nocookie.com';

/// Parse tin vị trí phát từ kênh YtSync: `t:<seconds>` → giây (null nếu
/// không phải tin thời gian hoặc không parse được).
///
/// YT-AUDIT-11 (IN4-106): tin có thể kèm mốc thời gian để ĐO độ trễ kênh,
/// dạng `t:<seconds>|<jsNowMs>`. Phần sau dấu `|` bị bỏ qua ở hàm này (xem
/// [ytParseSentAt]).
double? ytParseTimeMessage(String message) {
  if (!message.startsWith('t:')) return null;
  final body = message.substring(2);
  final bar = body.indexOf('|');
  return double.tryParse(bar < 0 ? body : body.substring(0, bar));
}

/// Mốc thời gian JS gửi kèm trong tin `t:` (`Date.now()`, epoch ms).
///
/// Dùng để ĐO độ trễ kênh WebView → Flutter — phần của triệu chứng
/// "âm thanh nhanh hơn chữ" mà ta đo được mà KHÔNG cần tín hiệu PCM
/// (VAD đã bị bác: iframe WebView không lấy được PCM).
int? ytParseSentAt(String message) {
  if (!message.startsWith('t:')) return null;
  final bar = message.indexOf('|');
  if (bar < 0) return null;
  return int.tryParse(message.substring(bar + 1).trim());
}

/// body text của trang player đang chứa màn lỗi YouTube (153 hoặc khác)
/// → app hiện overlay tiếng Việt + nút Thử lại/Mở ngoài (chết im lặng).
bool ytLooksLikePlayerError(String bodyText) {
  final t = bodyText.toLowerCase();
  return t.contains('lỗi cấu hình trình phát') ||
      (t.contains('lỗi cấu hình') && t.contains('153')) ||
      t.contains('video player configuration error') ||
      t.contains('player configuration error') ||
      t.contains('youtube player error');
}

// ─── Word knowledge state / phụ đề ───────────────────────
// YT-LR-002: model `WordState`, `LrWord`, `SubtitleLine` đã chuyển sang
// `models/yt_subtitle.dart` để bảng tra từ (`widgets/yt_word_panel.dart`)
// dùng chung mà không tạo import vòng với màn hình này.

// ══════════════════════════════════════════════════════════
//  YT PLAYER SCREEN
// ══════════════════════════════════════════════════════════
class YtPlayerScreen extends StatefulWidget {
  final YtExVideo video;
  final String? audioPath;
  const YtPlayerScreen({super.key, required this.video, this.audioPath});

  @override
  State<YtPlayerScreen> createState() => _YtPlayerScreenState();
}

class _YtPlayerScreenState extends State<YtPlayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late WebViewController _ytCtrl;
  Timer? _timer;
  Timer? _errWatchdog;
  Timer? _loadWatchdog;
  bool _isLoading = true;

  /// (IN4-78) Lỗi trình phát YouTube (mã 153…) — null = không lỗi.
  String? _playerError;

  /// (IN4-78) 0 = wrapper GitHub Pages, 1 = seed→embed trực tiếp.
  int _attempt = 0;
  bool _pageFinished = false;
  bool _gotReady = false;
  bool _embedRequested = false;
  bool _videoReady = false;
  int _errTicks = 0;

  /// IN4-81: thế hệ load hiện trạng — mọi kết quả async của video CŨ bị bỏ
  /// qua khi video đổi (không để lời của video cũ lẫn vào video mới).
  int _loadGeneration = 0;

  /// IN4-81: mốc thời gian mở video (để đo "tới khung hình đầu tiên").
  final DateTime _openedAt = DateTime.now();

  // ── Subtitle state ────────────────────────────────────────
  final List<SubtitleLine> _lines = [];
  int _currentLineIdx = 0;
  double _currentTime = 0;

  /// YT-AUDIT-10 (IN4-102): key gắn **CHỈ** cho dòng transcript đang active
  /// (không tạo key cho hàng nghìn dòng) ⇒ `Scrollable.ensureVisible` cuộn
  /// chính xác tới dòng đang phát bất kể chiều cao các dòng khác nhau.
  final GlobalKey _activeLineKey = GlobalKey();
  // IN4-81: mẫu độ lệch (ms) giữa vị trí phát và mốc bắt đầu dòng vừa chọn,
  // để ĐO chứ không đoán. `drift > 0` ⇒ tiếng nói đi trước lúc chữ đổi.
  final List<int> _syncDrifts = <int>[];

  /// YT-AUDIT-11 (IN4-106): mẫu độ trễ KÊNH WebView → Flutter (ms).
  ///
  /// JS gửi kèm `Date.now()` tại thời điểm đọc `currentTime`; Dart lấy
  /// `DateTime.now()` khi NHẬN ⇒ hiệu = thời gian tin nằm trong hàng đợi.
  /// Đó chính là khoảng "âm thanh đã nói rồi mà chữ vẫn chưa đổi".
  final List<int> _syncLags = <int>[];

  /// Bù trễ TỰ ĐỘNG hiện tại (ms) — lấy từ trung vị [_syncLags].
  int _autoLagMs = 0;

  /// Số mẫu tối thiểu trước khi tin vào kết quả đo (tránh bù theo nhiễu).
  static const int _kMinLagSamples = 8;

  /// Cửa sổ trượt của mẫu đo.
  static const int _kLagWindow = 40;

  /// Không tự bù quá 1,5 s: vượt mức này thường là đồng hồ lệch hoặc thiết bị
  /// quá tải — bù tự động sẽ làm chữ NHẢY LỘN XỘN. Phần còn lại để người dùng
  /// tự chỉnh bằng thanh trượt (nơi có chủ đích).
  static const int _kMaxAutoLagMs = 1500;

  /// Độ trễ kênh đã đo (trung vị), `0` khi chưa đủ mẫu — UI đọc để gợi ý.
  int get measuredLagMs {
    if (_syncLags.length < _kMinLagSamples) return 0;
    final sorted = List<int>.of(_syncLags)..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// Đo độ trễ kênh và cập nhật [_autoLagMs].
  ///
  /// Nuốt mọi mẫu rác: đồng hồ JS/Dart có thể lệch trên một số thiết bị, nên
  /// mẫu âm hoặc > 10 s bị bỏ (10 s không phải độ trễ kênh, là dữ liệu hỏng).
  void _trackChannelLag(int? sentAtMs) {
    if (sentAtMs == null) return;
    final lag = DateTime.now().millisecondsSinceEpoch - sentAtMs;
    if (lag < 0 || lag > 10000) return;
    _syncLags.add(lag);
    if (_syncLags.length > _kLagWindow) _syncLags.removeAt(0);
    if (_syncLags.length < _kMinLagSamples) return;
    final m = measuredLagMs;
    final next = m < 0 ? 0 : (m > _kMaxAutoLagMs ? _kMaxAutoLagMs : m);
    // Chỉ đổi khi lệch đáng kể để chữ không giật từng 100 ms một.
    if ((next - _autoLagMs).abs() < 100) return;
    _autoLagMs = next;
  }

  // ── Word knowledge ────────────────────────────────────────
  final Map<String, WordState> _wordStates = {};
  bool _looping = false;
  static const _kWordBox = 'yt_lr_word_states';

  // ── YT-LR-002: cài đặt học tập (IN4-88) ───────────────────
  /// Cài đặt phụ đề/bố cục/ngưỡng tần suất — lưu toàn cục, áp dụng mọi video.
  YtLearningSettings _settings = const YtLearningSettings();

  /// Chế độ `Làm mờ bản dịch`: người dùng bấm để hiện tạm rồi mờ lại.
  bool _translationRevealed = false;

  /// Từ người dùng vừa mở bảng tra (làm ngữ cảnh cho tab Lexa).
  String? _selectedWord;

  @override
  void initState() {
    super.initState();
    // IN4-77: thêm tab 3 "TẢI" (audio + caption + lịch sử) — tích hợp
    // các tính năng của giao diện tầng 2 vào ngay màn player.
    // YT-LR-002 (IN4-87): thêm tab 4 "LEXA" (AI chat bám ngữ cảnh video).
    _tabCtrl = TabController(length: 4, vsync: this);
    // YT-AUDIT-10 (IN4-102): vừa chuyển sang tab VĂN BẢN ⇒ cuộn ngay tới
    // dòng đang phát (nếu không người dùng phải tự kéo từ đầu danh sách).
    _tabCtrl.addListener(() {
      if (_tabCtrl.index == 0) _followActiveLine();
    });
    _initWebView();
    unawaited(_loadWordStates());
    unawaited(_loadSettings());
    unawaited(_loadRealSubtitles());
    // YT-AUDIT-04 (IN4-103): nạp danh sách ngôn ngữ phụ đề thật của video.
    unawaited(_loadAvailableLangs());
    // YT-AUDIT-07 (IN4-99): ghi lịch sử xem NGAY khi mở player — đây là
    // điểm duy nhất phủ mọi đường vào (search / dán URL / lịch sử / kênh).
    unawaited(_recordHistory());
    _startTimer();
  }

  /// YT-AUDIT-07 (IN4-99) — ghi video đang mở vào `YtHistory`.
  ///
  /// `YtHistory.add()` từng **chỉ** được gọi ở `youtube_sheet.dart` (tầng 1
  /// "Dán URL YouTube…"). Từ IN4-95 nhấn icon YouTube đi thẳng vào tầng 2
  /// (`YoutubeExplorerScreen`) nên luồng mới **không bao giờ ghi lịch sử**.
  /// Ghi ở player ⇒ một chỗ, phủ mọi đường vào.
  ///
  /// Local-first: chỉ chạm Hive trên máy; lỗi bị nuốt để không làm hỏng
  /// việc mở video.
  Future<void> _recordHistory() async {
    try {
      await YtHistory.ensureOpen();
      await YtHistory.add(
        YtVideo(
          id: widget.video.id,
          title: widget.video.title,
          channel: widget.video.channelTitle,
          thumb: widget.video.thumb,
        ),
      );
      // Log ASCII (không dấu) để không bị gate i18n quét như literal UI.
      debugPrint('[in4up-yt] history saved: ${widget.video.id}');
    } catch (e) {
      debugPrint('[in4up-yt] history save failed: $e');
    }
  }

  Future<void> _loadSettings() async {
    await YtLearningSettingsService.ensureOpen();
    if (!mounted) return;
    setState(() => _settings = YtLearningSettingsService.load());
  }

  /// YT-AUDIT-04 (IN4-103): cache danh sách ngôn ngữ phụ đề THẬT của video
  /// (từ `getAvailableLanguages`) — lấy 1 lần, dùng cho ô chọn trong
  /// "Cài đặt phụ đề". Trống ⇒ sheet tự rớt về danh sách mặc định.
  List<({String code, String name})> _availableLangs = const [];

  Future<void> _loadAvailableLangs() async {
    try {
      final langs =
          await YtService.instance.getAvailableLanguages(widget.video.id);
      if (!mounted || langs.isEmpty) return;
      setState(() => _availableLangs = langs);
    } catch (e) {
      debugPrint('[in4up-yt] available langs failed: $e');
    }
  }

  Future<void> _openSubtitleSettings() async {
    final next = await showYtSubtitleSettingsSheet(
      context,
      _settings,
      videoId: widget.video.id,
      availableLangs: _availableLangs,
      // YT-AUDIT-11 (IN4-106): truyền độ trễ kênh ĐÃ ĐO để sheet gợi ý.
      measuredLagMs: measuredLagMs,
    );
    if (next == null) return;
    final langChanged = next.subtitleLang != _settings.subtitleLang ||
        next.targetLang != _settings.targetLang;
    setState(() {
      _settings = next;
      // YT-AUDIT-04 (IN4-103): đổi ngôn ngữ ⇒ xoá phụ đề + bản dịch CŨ ngay
      // trong cùng một rebuild (nếu clear ngoài setState, UI vẫn giữ bản dịch
      // ngôn ngữ cũ cho tới khi tải xong ⇒ người dùng tưởng app không đổi).
      if (langChanged) {
        _lines.clear();
        _currentLineIdx = 0;
      }
    });
    unawaited(YtLearningSettingsService.save(next));
    // Tải lại phụ đề theo ngôn ngữ mới. `_loadRealSubtitles()` tự tăng token
    // thế hệ `_loadGeneration` ⇒ mọi kết quả của lần tải trước bị bỏ qua.
    if (langChanged) unawaited(_loadRealSubtitles());
  }

  void _onFrequencyChanged(double value) {
    final next = _settings.copyWith(frequencyRankThreshold: value);
    setState(() => _settings = next);
    unawaited(YtLearningSettingsService.save(next));
  }

  @override
  void didUpdateWidget(covariant YtPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // IN4-81: đổi video ⇒ huỷ kết quả của video cũ (token thế hệ tăng),
    // xoá lời cũ, nạp lại từ đầu cho video mới.
    if (oldWidget.video.id != widget.video.id) {
      debugPrint(
          '[in4up-yt] đổi video: ${oldWidget.video.id} → ${widget.video.id}');
      _loadGeneration++; // vô hiệu hoá mọi tác vụ async của video cũ
      _lines.clear();
      _currentLineIdx = 0;
      _currentTime = 0;
      // YT-LR-002: đổi video ⇒ xoá trạng thái tạm của video cũ.
      _translationRevealed = false;
      _selectedWord = null;
      _videoReady = false;
      _playerError = null;
      _errTicks = 0;
      _embedRequested = false;
      _attempt = 0;
      _ytCtrl.loadRequest(Uri.parse(buildYtWrapperUrl(widget.video.id)));
      unawaited(_loadRealSubtitles());
      // YT-AUDIT-07 (IN4-99): đổi video trong cùng player ⇒ ghi lịch sử
      // cho video MỚI (initState chỉ chạy một lần).
      unawaited(_recordHistory());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _errWatchdog?.cancel();
    _loadWatchdog?.cancel();
    _dlWatchdog?.cancel();
    _dlSub?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _initWebView() {
    _ytCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            final u = url.toString();
            // (IN4-78) fallback: trang đầu (seed) load xong → điều hướng
            // tới /embed/<id>; request lúc đó tự mang Referer. Chốt theo
            // cờ (không so URL y hệt) để vẫn chạy nếu seed bị redirect.
            if (_attempt == 1 && !_embedRequested) {
              _embedRequested = true;
              debugPrint('[in4up-yt] seed done → load embed (referrer OK)');
              _ytCtrl.loadRequest(Uri.parse(buildYtEmbedUrl(widget.video.id)));
              return;
            }
            _pageFinished = true;
            _loadWatchdog?.cancel();
            // Referrer diagnostics (fallback path): xem trang embed nhận
            // được Referer gì từ bước seed.
            if (u.contains('youtube-nocookie.com/embed/')) {
              _ytCtrl.runJavaScriptReturningResult('document.referrer').then(
                (r) => debugPrint('[in4up-yt] embed referrer: ${r ?? "∅"}'),
              ).catchError((_) {});
            }
            // Wrapper (GitHub Pages) tự chứa IFrame API + YtSync — không
            // cần inject. Trang embed trực tiếp cần inject script cũ.
            if (!u.contains(Uri.parse(kYtWrapperBaseUrl).host)) {
              _injectSyncScript();
            }
            _startErrorWatchdog();
          },
        ),
      )
      ..addJavaScriptChannel(
        'YtSync',
        onMessageReceived: (msg) {
          _handlePlayerMessage(msg.message);
        },
      )
      ..loadRequest(Uri.parse(buildYtWrapperUrl(widget.video.id)));
    _startLoadWatchdog();
  }

  /// (IN4-78) Tin từ wrapper/embed qua kênh YtSync:
  /// `t:<s>` vị trí phát, `ready`, `state:<n>`, `err:<mã>`.
  void _handlePlayerMessage(String m) {
    if (!mounted) return;
    if (m == 'ready') {
      _gotReady = true;
      _loadWatchdog?.cancel();
      if (!_videoReady) {
        _markFirstFrame();
        setState(() => _videoReady = true);
      }
      return;
    }
    final time = ytParseTimeMessage(m);
    if (time != null) {
      if (!_videoReady) {
        _markFirstFrame();
        setState(() => _videoReady = true);
      }
      // YT-AUDIT-11 (IN4-106): truyền cả mốc JS gửi để đo độ trễ kênh.
      _updateTime(time, sentAtMs: ytParseSentAt(m));
      return;
    }
    // Compat: script inject cũ (đường embed trực tiếp) post số TRẺ không
    // có prefix 't:' — vẫn nhận làm vị trí phát.
    final raw = double.tryParse(m);
    if (raw != null) {
      _updateTime(raw);
      return;
    }
    if (m.startsWith('err:')) {
      _onPlayerError(m.substring(4).trim());
    }
  }

  /// (IN4-78) wrapper không load được trong 12s (Pages chưa bật / mạng)
  /// → tự chuyển sang fallback seed→embed.
  void _startLoadWatchdog() {
    _loadWatchdog?.cancel();
    _loadWatchdog = Timer(const Duration(seconds: 12), () {
      if (!mounted) return;
      if (_attempt == 0 && !_pageFinished) {
        debugPrint('[in4up-yt] wrapper timeout → fallback seed→embed');
        _fallbackToDirect();
      }
    });
  }

  /// Mã lỗi KHÔNG liên quan môi trường nhúng (video sai/cấm nhúng) —
  /// fallback cũng vô ích, báo thẳng overlay.
  static const Set<String> _kNoFallbackCodes =
      {'2', '5', '100', '101', '120', '150'};

  /// (IN4-78) fallback: seed → embed trực tiếp (mang Referer same-origin).
  void _fallbackToDirect() {
    _attempt = 1;
    _pageFinished = false;
    _embedRequested = false;
    _videoReady = false;
    _errTicks = 0;
    _ytCtrl.loadRequest(Uri.parse(kYtEmbedSeedUrl));
    _startLoadWatchdog();
  }

  /// (IN4-78) Player báo lỗi (từ wrapper `err:<code>` hoặc watchdog text):
  /// còn attempt thì fallback; hết thì overlay + "Mở ngoài".
  void _onPlayerError(String code) {
    if (!mounted) return;
    debugPrint('[in4up-yt] player error code=$code attempt=$_attempt (IN4-78)');
    if (_attempt == 0 && !_kNoFallbackCodes.contains(code)) {
      _fallbackToDirect();
      return;
    }
    if (_playerError == null) {
      setState(() => _playerError =
          'YouTube từ chối phát video này (lỗi cấu hình trình phát, '
          'mã $code). Bấm Thử lại, hoặc Mở ngoài để xem trong trình duyệt.');
    }
  }

  /// (IN4-78) Theo dõi 3s/lần: nếu trang player hiện màn lỗi → xử lý.
  /// Wrapper tự báo `err:` nên watchdog chủ yếu cho đường embed trực tiếp;
  /// thêm: 15s mà vẫn chưa `ready` (wrapper chết lặng) → fallback.
  void _startErrorWatchdog() {
    _errWatchdog?.cancel();
    _errWatchdog = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      if (_attempt == 0 && !_gotReady) {
        _errTicks++;
        if (_errTicks >= 5) {
          debugPrint('[in4up-yt] wrapper không ready 15s → fallback');
          _fallbackToDirect();
          return;
        }
      }
      try {
        final res = await _ytCtrl.runJavaScriptReturningResult(
            "(function(){ var b = document.body; "
            "return b ? b.innerText.slice(0, 3000) : ''; })();");
        final text = res == null ? '' : res.toString();
        if (text.isNotEmpty && ytLooksLikePlayerError(text)) {
          _onPlayerError('153?');
        }
      } catch (e) {
        // runJavaScript có thể lỗi khi đang chuyển trang — bỏ qua.
      }
    });
  }

  /// (IN4-78) Nút "Thử lại" trên overlay: chạy lại từ đầu (wrapper).
  void _reloadPlayer() {
    debugPrint('[in4up-yt] reload player (IN4-78)');
    _errWatchdog?.cancel();
    _loadWatchdog?.cancel();
    _attempt = 0;
    _pageFinished = false;
    _gotReady = false;
    _embedRequested = false;
    _videoReady = false;
    _errTicks = 0;
    setState(() => _playerError = null);
    _ytCtrl.loadRequest(Uri.parse(buildYtWrapperUrl(widget.video.id)));
    _startLoadWatchdog();
  }

  /// (IN4-78) Nút "Mở ngoài": xem video trong YouTube/trình duyệt hệ thống
  /// — luôn hoạt động (khuyến nghị chính thức cho WebView bị chặn).
  Future<void> _openExternally() async {
    final url = Uri.parse('https://www.youtube.com/watch?v=${widget.video.id}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        debugPrint('[in4up-yt] open externally failed: $e');
      }
    }
  }

  void _injectSyncScript() {
    const js = r'''
      (function() {
        function videoEl() { return document.querySelector('video'); }
        window._in4upSeek = function(s) {
          try { var v = videoEl(); if (v) { v.currentTime = s; return; } } catch (e) {}
          try {
            document.querySelectorAll('iframe').forEach(function(f) {
              f.contentWindow.postMessage(JSON.stringify({
                event: 'command', func: 'seekTo', args: [s, true]
              }), '*');
            });
          } catch (e) {}
        };
        window._in4upPause = function() {
          try { var v = videoEl(); if (v) { v.pause(); return; } } catch (e) {}
          try {
            document.querySelectorAll('iframe').forEach(function(f) {
              f.contentWindow.postMessage(JSON.stringify({
                event: 'command', func: 'pauseVideo', args: []
              }), '*');
            });
          } catch (e) {}
        };
        window._in4upPlay = function() {
          try { var v = videoEl(); if (v) { v.play(); return; } } catch (e) {}
          try {
            document.querySelectorAll('iframe').forEach(function(f) {
              f.contentWindow.postMessage(JSON.stringify({
                event: 'command', func: 'playVideo', args: []
              }), '*');
            });
          } catch (e) {}
        };
        var lastT = null;
        function tick() {
          try {
            var v = videoEl();
            if (!v || !window.YtSync) return;
            var t = String(v.currentTime);
            // YT-AUDIT-11 (IN4-106): gửi kèm Date.now() để Dart đo được
            // độ trễ kênh (tin nằm trong hàng đợi bao lâu).
            var stamp = t + '|' + Date.now();
            if (stamp === lastT) return;   // skip duplicates
            lastT = stamp;
            YtSync.postMessage('t:' + stamp);
          } catch (e) {}
        }
        // IN4-81: PUSH ON EVENT instead of setInterval(250). `timeupdate`
        // fires the moment currentTime changes (sub-frame latency), while
        // setInterval waits for the next tick and adds up to ~250ms of
        // lag -- exactly the "audio runs ahead of the text" symptom.
        // `seeked`/`ratechange`/`play` resync right after seek/speed change.
        function hook(v) {
          v.addEventListener('timeupdate', tick);
          v.addEventListener('seeked', tick);
          v.addEventListener('ratechange', tick);
          v.addEventListener('play', tick);
        }
        var v0 = videoEl();
        if (v0) {
          hook(v0);
        } else {
          // <video> not created yet (IFrame API) -> wait, then attach.
          var tries = 0;
          var iv = setInterval(function() {
            var v = videoEl();
            if (v) { hook(v); clearInterval(iv); }
            else if (++tries > 40) clearInterval(iv);
          }, 250);
        }
        // Fallback when the browser throttles timers in a hidden tab.
        setInterval(tick, 1000);
      })();
    ''';
    _ytCtrl.runJavaScript(js);
  }

  void _updateTime(double time, {int? sentAtMs}) {
    if (!mounted) return;
    // YT-AUDIT-11 (IN4-106): đo độ trễ kênh TRƯỚC — kết quả cộng ngay vào vị
    // trí phát dùng để chọn dòng phụ đề ở bên dưới.
    _trackChannelLag(sentAtMs);
    // _currentTime KHÔNG hiển thị ở UI (chỉ dùng cho seek/lặp) → cập nhật
    // THƯỜNG, không setState. (IN4-78 nghiệm thu 2: trước setState ~2
    // lần/giây cho phần không đổi → churn semantics liên tục, assertion
    // debug `!semantics.parentDataDirty` spam trên máy có accessibility.)
    _currentTime = time;
    if (_looping && _lines.isNotEmpty) {
      final line = _lines[_currentLineIdx.clamp(0, _lines.length - 1)];
      if (time * 1000 >= line.end.inMilliseconds - 60) {
        _seekTo(line.start.inMilliseconds / 1000.0);
        return;
      }
    }
    final ms = (time * 1000).round();
    // YT-AUDIT-11 (IN4-106): vị trí phát THẬT (dùng cho seek/lặp) giữ nguyên;
    // chỉ vị trí dùng để CHỌN DÒNG PHỤ ĐỀ mới được cộng bù trễ. Hai phần:
    //   + audioLeadMs — do người dùng đặt (track phụ đề lệch so với audio;
    //     KHÔNG đo được nếu không có PCM).
    //   + _autoLagMs  — đo được từ kênh WebView → Flutter.
    // Dương = âm thanh nhanh hơn chữ ⇒ chữ đổi SỚM hơn.
    final syncMs = ms + _settings.audioLeadMs.round() + _autoLagMs;
    var idx = _currentLineIdx;
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (syncMs >= l.start.inMilliseconds && syncMs < l.end.inMilliseconds) {
        idx = i;
        break;
      }
      if (syncMs >= l.start.inMilliseconds) idx = i;
    }
    // Chỉ rebuild khi DÒNG PHỤ ĐỀ đổi (phần hiển thị thực sự).
    if (idx != _currentLineIdx) {
      // IN4-81: log TIMESTAMP thực tế để đo độ lệch (audio vs chữ) — KHÔNG
      // dùng offset cố định. Nếu "âm thanh đi trước chữ" thì log này cho
      // biết chọn dòng có đúng không và độ lệch là bao nhiêu.
      final line = _lines[idx];
      final gapBefore = idx > 0
          ? (line.start - _lines[idx - 1].end).inMilliseconds
          : 0;
      // drift = vị trí phát THẬT (chưa bù) TRỪ mốc bắt đầu dòng. Dương & lớn
      // ⇒ chữ đổi TRỄ so với tiếng nói (đúng triệu chứng "âm thanh nhanh hơn
      // chữ"). Giữ 60 mẫu gần nhất để đọc xu hướng trên logcat, KHÔNG tự áp
      // offset.
      //
      // CÓ CHỦ ĐÍCH dùng `ms` (không phải `syncMs`): đây là PHÉP ĐO chẩn đoán,
      // nên phải nói lên LỆCH GỐC, không được bị bù trễ che mất. Khi đã bù
      // đúng, drift ≈ -(lead+lag) — đọc con số đó biết ngay bù còn dư/thiếu
      // bao nhiêu. Dùng `syncMs` thì drift ≈ 0 mãi ⇒ mất tác dụng.
      final drift = ms - line.start.inMilliseconds;
      _syncDrifts.add(drift);
      if (_syncDrifts.length > 60) _syncDrifts.removeAt(0);
      final avg = _syncDrifts.reduce((a, b) => a + b) / _syncDrifts.length;
      debugPrint(
        '[in4up-yt] line $idx '
        'start=${line.start.inMilliseconds}ms end=${line.end.inMilliseconds}ms '
        '| t=${ms}ms | sync=${syncMs}ms '
        '(lead=${_settings.audioLeadMs.round()} lag=$_autoLagMs) '
        '| drift=${drift}ms | driftTB=${avg.toStringAsFixed(0)}ms '
        '| gapBefore=${gapBefore}ms | '
        '${line.text.length > 40 ? "${line.text.substring(0, 40)}…" : line.text}',
      );
      setState(() => _currentLineIdx = idx);
      _followActiveLine();
    }
  }

  /// YT-AUDIT-10 (IN4-102): cuộn tab VĂN BẢN tới dòng đang phát.
  ///
  /// Trước đây `_buildTranscriptTab` là `ListView.builder` trần, không có
  /// `ScrollController` ⇒ không theo dõi gì cả. Chỉ cuộn khi người dùng BẬT
  /// `transcriptAutoFollow` (mặc định) và đang ở đúng tab VĂN BẢN.
  void _followActiveLine() {
    if (!_settings.transcriptAutoFollow) return;
    // Chỉ tab 0 (VĂN BẢN) có danh sách cuộn được.
    if (_tabCtrl.index != 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _activeLineKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35, // dòng active nằm khoảng 1/3 từ trên xuống
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// YT-AUDIT-10 (IN4-102): bật/tắt tự động theo dòng hiện tại.
  void _onAutoFollowChanged(bool value) {
    final next = _settings.copyWith(transcriptAutoFollow: value);
    setState(() => _settings = next);
    unawaited(YtLearningSettingsService.save(next));
    if (value) _followActiveLine();
  }

  void _startTimer() {
    // IN4-81: trang đã ĐẨY `t:` theo sự kiện `timeupdate` (xem
    // `_injectSyncScript`), nên nhịp hỏi từ Dart chỉ còn là dự phòng khi JS
    // trong trang bị chặn → giảm tần suất để đỡ tải WebView.
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _ytCtrl.runJavaScript('''
        (function(){
          var v = document.querySelector('video');
          if (v && window.YtSync) {
            YtSync.postMessage('t:' + String(v.currentTime) + '|' + Date.now());
          }
        })();
      ''');
    });
  }

  Future<void> _loadWordStates() async {
    try {
      if (!Hive.isBoxOpen(_kWordBox)) {
        await Hive.openBox<String>(_kWordBox);
      }
      final raw = Hive.box<String>(_kWordBox).get('map');
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((key, value) {
        final k = key.toString().toLowerCase();
        final label = value.toString();
        if (label == 'known') {
          _wordStates[k] = WordState.known;
        } else if (label == 'learning') {
          _wordStates[k] = WordState.learning;
        } else if (label == 'ignored') {
          _wordStates[k] = WordState.ignored;
        }
      });
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('yt_lr load word states: $e');
    }
  }

  Future<void> _persistWordStates() async {
    try {
      if (!Hive.isBoxOpen(_kWordBox)) {
        await Hive.openBox<String>(_kWordBox);
      }
      final map = <String, String>{};
      _wordStates.forEach((k, v) {
        if (v != WordState.unknown) map[k] = v.name;
      });
      await Hive.box<String>(_kWordBox).put('map', jsonEncode(map));
    } catch (e) {
      debugPrint('yt_lr persist word states: $e');
    }
  }

  Future<void> _loadRealSubtitles() async {
    // IN4-81: ưu tiên VIDEO, lời/dịch KHÔNG được chặn player.
    // Chia 3 pha:
    //  A) lấy phụ đề GỐC (en) → hiện ngay (chưa có dịch);
    //  B) lấy phụ đề đích trên YT → ghép (nhanh, không cần AI);
    //  C) nếu YT không có bản dịch → dịch AI theo LÔ nhỏ, hiện tăng dần.
    // Mọi kết quả của video cũ bị BỎ QUA nếu video đã đổi (token thế hệ).
    final generation = ++_loadGeneration;
    final videoId = widget.video.id;
    final startedAt = DateTime.now();
    setState(() => _isLoading = true);

    // YT-AUDIT-04 (IN4-103): phụ đề gốc lấy theo ngôn ngữ người dùng CHỌN
    // (mặc định `en`), không còn hard-code 'en'. Khai báo ngoài `try` vì được
    // dùng ở cả 3 pha A/B/C bên dưới.
    final subLang = _settings.subtitleLang;

    List<YtCaptionLine>? base;
    try {
      base = await YtService.instance.fetchCaptions(videoId, lang: subLang);
      if (_isStale(generation)) return;
      if (base.isEmpty) {
        debugPrint('[in4up-yt] không có phụ đề gốc cho $videoId');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      // YT-AUDIT-11 (IN4-106): gộp các cue vụn của YouTube thành CÂU HOÀN
      // CHỈNH (dấu đầy đủ + viết hoa đầu câu) TRƯỚC khi dựng dòng và trước
      // khi dịch — dịch nguyên câu cho kết quả tốt hơn hẳn dịch mẩu câu.
      final rawCount = base.length;
      base = YtSentenceSegmenter.segmentCaptions(base);
      debugPrint(
        '[in4up-yt] chia cau: $rawCount cue -> ${base.length} cau',
      );
      _applyCaptionLines(base);
      final tCaptions = DateTime.now()
          .difference(startedAt)
          .inMilliseconds;
      debugPrint(
          '[in4up-yt] TIMING phụ đề đầu tiên: ${tCaptions}ms '
          '(${base.length} dòng)');
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Load subtitles error: $e');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (_isStale(generation)) return;
    // YT-AUDIT-04 (IN4-103): ngôn ngữ đích = override của người dùng (nếu có),
    // ngược lại THEO CÀI ĐẶT HOME. Bản cũ tự đoán `target == 'en' ? 'vi'` một
    // cách im lặng ⇒ người dùng không hề biết app đã đổi ngôn ngữ dịch.
    final resolved = YtLearningSettings.resolveTargetLang(
      subtitleLang: subLang,
      overrideTargetLang: _settings.targetLang,
      homeTargetLang: TranslationService().targetLang,
    );
    final lang2 = resolved.lang;
    if (resolved.fellBack) {
      debugPrint(
        '[in4up-yt] ngon ngu dich trung phu de goc ($subLang) -> '
        'roi ve tieng Viet (ro rang, khong len)',
      );
    }

    // (B) bản dịch có sẵn trên YouTube — nhanh, không cần AI.
    try {
      final localized = await YtService.instance.fetchCaptions(videoId, lang: lang2);
      if (_isStale(generation)) return;
      if (localized.isNotEmpty) {
        final merged = YtService.instance.mergeCaptions(base, localized);
        _applyCaptionLines(merged);
        final tAll = DateTime.now().difference(startedAt).inMilliseconds;
        debugPrint('[in4up-yt] TIMING bản dịch (YT) đầy đủ: ${tAll}ms');
        return;
      }
    } catch (e) {
      debugPrint('⚠️ [in4up-yt] lấy phụ đề $lang2 lỗi: $e');
    }
    if (_isStale(generation)) return;

    // (C) không có bản dịch trên YT → dịch AI TĂNG DẦN theo lô.
    debugPrint('🔄 [in4up-yt] $lang2 không có trên YT → dịch AI tăng dần');
    const chunkSize = 6;
    final total = base.length;

    // YT-LR-002 (fix lệch/mất bản dịch, IN4-81): bộ nhớ dịch **TÍCH LUỸ**.
    // Bản cũ dựng lại `merged` từ `base` (bản gốc CHƯA có dịch) ở mỗi lô rồi
    // chỉ gắn dịch cho 6 dòng của lô đó ⇒ XOÁ SẠCH dịch của các lô trước ⇒
    // cuối cùng chỉ còn 6 dòng CUỐI có bản dịch (triệu chứng owner báo:
    // "ẩn đi nhiều dòng dịch, chỉ còn các dòng dịch cuối").
    final translations = List<String?>.filled(total, null);
    var firstTranslationMs = 0;
    for (var offset = 0; offset < total; offset += chunkSize) {
      if (_isStale(generation)) return;
      final end = (offset + chunkSize) > total ? total : offset + chunkSize;
      final slice = base.sublist(offset, end);
      List<String> translated;
      try {
        translated = await YtService.instance.translateLines(
          slice.map((e) => e.text).toList(),
          // YT-AUDIT-04 (IN4-103): nguồn là ngôn ngữ phụ đề gốc thật, không
          // còn hard-code 'en' (sai khi học tiếng Nhật/Hàn/Trung).
          sourceLang: subLang.startsWith('a.') ? subLang.substring(2) : subLang,
          targetLang: lang2,
        );
      } catch (e) {
        debugPrint('⚠️ [in4up-yt] dịch lô $offset-$end lỗi: $e');
        continue;
      }
      if (_isStale(generation)) return;
      // Ghi THÊM vào bảng tích luỹ (không mất gì đã dịch trước đó).
      for (var i = 0; i < slice.length; i++) {
        final text = i < translated.length ? translated[i].trim() : '';
        translations[offset + i] = text.isEmpty ? null : text;
      }
      // Áp lại TOÀN BỘ danh sách từ bảng tích luỹ.
      final merged = <YtCaptionLine>[
        for (var i = 0; i < total; i++)
          base[i].copyWith(translation: translations[i]),
      ];
      _applyCaptionLines(merged);
      if (firstTranslationMs == 0) {
        firstTranslationMs = DateTime.now().difference(startedAt).inMilliseconds;
        debugPrint(
            '[in4up-yt] TIMING bản dịch đầu tiên: ${firstTranslationMs}ms');
      }
    }
    final tAll = DateTime.now().difference(startedAt).inMilliseconds;
    debugPrint('[in4up-yt] TIMING bản dịch đầy đủ: ${tAll}ms');
  }

  /// Kết quả của lần load cũ (video đã đổi) ⇒ bỏ qua.
  bool _isStale(int generation) => generation != _loadGeneration || !mounted;

  /// IN4-81: đo mốc "khung hình đầu tiên" (lần đầu player báo ready/tick).
  void _markFirstFrame() {
    final ms = DateTime.now().difference(_openedAt).inMilliseconds;
    debugPrint('[in4up-yt] TIMING khung hình đầu tiên: ${ms}ms');
  }

  /// Đưa danh sách phụ đề vào state (giữ nguyên phần dịch đã có).
  /// Track phụ đề "rolling window" (auto-caption của YouTube): mỗi dòng LẶP
  /// lại phần chữ của dòng trước rồi thêm chữ mới
  /// (vd "hello" → "hello world" → "hello world how").
  ///
  /// Với dạng này, hiển thị CẢ cửa sổ khiến chữ luôn **trễ hơn âm
  /// thanh khoảng một dòng** (chữ mới chỉ xuất hiện ở cuối cửa sổ) —
  /// đúng triệu chứng owner báo (IN4-81). Cách sửa KHÔNG dùng offset cố
  /// định: nhận diện theo NỘI DUNG rồi hiển thị đúng phần chữ **đang
  /// được đọc** (phần mới) — dòng nào "đang nói" thì hiện đúng phần đó.
  /// Uỷ quyền cho [YtSentenceSegmenter.isCumulativeTrack] — cùng một tiêu
  /// chí, chỉ còn MỘT bản (tránh hai nơi lệch nhau).
  static bool _isCumulativeCaptionTrack(List<YtCaptionLine> captions) =>
      YtSentenceSegmenter.isCumulativeTrack(captions);

  void _applyCaptionLines(List<YtCaptionLine> captions) {
    if (!mounted) return;
    final cumulative = _isCumulativeCaptionTrack(captions);
    if (cumulative) {
      debugPrint(
        '🔁 [in4up-yt] phụ đề dạng ROLLING WINDOW (${captions.length} dòng) — '
        'hiển thị phần chữ mới theo từng dòng (không dùng offset cố định).',
      );
    }
    setState(() {
      _lines.clear();
      for (var i = 0; i < captions.length; i++) {
        final c = captions[i];
        var display = c.text;
        if (cumulative && i > 0) {
          final prev = captions[i - 1].text.trim();
          final cur = c.text.trim();
          if (cur.length > prev.length && cur.startsWith(prev)) {
            display = cur.substring(prev.length).trim();
          }
        }
        _lines.add(SubtitleLine(
          start: c.start,
          end: c.end,
          text: display.isEmpty ? c.text : display,
          fullText: c.text,
          translation: c.translation,
          words: _parseWords(display.isEmpty ? c.text : display),
        ));
      }
    });
  }

  List<LrWord> _parseWords(String text) {
    final analyzed = SyntaxHighlighterService.analyzeLine(text);
    final words = <LrWord>[];
    var rank = 100;
    for (final w in analyzed) {
      final token = w.originalWord.trim();
      if (token.isEmpty) continue;
      if (w.wordType == WordType.punctuation) continue;
      final lower = token.toLowerCase();
      // YT-AUDIT-08 (IN4-100): map ĐẦY ĐỦ mọi `WordType` thay vì gom phần
      // còn lại vào `'other'` ⇒ bảng tra từ hiện đúng từ loại (đại từ, từ
      // hạn định, số từ, thán từ…). Nhãn tiếng Việt nằm ở `_typeLabel`
      // trong `widgets/yt_word_panel.dart` (call-site của `uiText()`).
      final type = switch (w.wordType) {
        WordType.verb => 'verb',
        WordType.noun => 'noun',
        WordType.adjective => 'adj',
        WordType.adverb => 'adv',
        WordType.preposition => 'prep',
        WordType.conjunction => 'conj',
        WordType.pronoun => 'pron',
        WordType.determiner => 'det',
        WordType.number => 'num',
        WordType.interjection => 'intj',
        WordType.punctuation ||
        WordType.unknown =>
          'other',
      };
      var state = _wordStates[lower] ?? WordState.unknown;
      if (state == WordState.unknown && VocabularyBridge.hasWord(lower)) {
        state = WordState.learning;
      }
      words.add(LrWord(
        text: token,
        type: type,
        langRank: rank,
        state: state,
      ));
      rank += 40;
    }
    return words;
  }

  // ─── Word actions ─────────────────────────────────────────
  void _setWordState(String word, WordState state) {
    final lower = word.toLowerCase();
    setState(() {
      _wordStates[lower] = state;
      for (final line in _lines) {
        for (final w in line.words) {
          if (w.text.toLowerCase() == lower) {
            w.state = state;
          }
        }
      }
    });
    unawaited(_persistWordStates());
    if (state == WordState.learning) {
      final line = _lines.isEmpty
          ? null
          : _lines[_currentLineIdx.clamp(0, _lines.length - 1)];
      VocabularyBridge.addContextual(
        text: word,
        example: line?.text,
        context: VocabContext.fromStory(
          storyTitle: widget.video.title,
          lineIndex: _currentLineIdx,
          surroundingText: line?.text ?? word,
          sourceRef: 'youtube:${widget.video.id}',
          sourceRefType: 'youtube',
          anchorText: word,
          textStartOffset: line?.start.inMilliseconds,
          textEndOffset: line?.end.inMilliseconds,
        ),
        language: 'en',
        topic: 'YouTube',
      );
    }
  }

  int get _knownCount =>
      _wordStates.values.where((s) => s == WordState.known).length;
  int get _learningCount =>
      _wordStates.values.where((s) => s == WordState.learning).length;
  int get _ignoredCount =>
      _wordStates.values.where((s) => s == WordState.ignored).length;

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: isLandscape ? _buildLandscape() : _buildPortrait(),
      ),
    );
  }

  Widget _buildPortrait() {
    return Column(
      children: [
        // Title Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF161B22),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // YT-LR-002 (IN4-88): menu Subtitle Settings.
              IconButton(
                tooltip: context.uiText('Cài đặt phụ đề'),
                icon: const Icon(Icons.subtitles_outlined,
                    color: Colors.white70, size: 20),
                onPressed: _openSubtitleSettings,
              ),
              IconButton(
                tooltip: 'Học trong tab Nghe',
                icon: Icon(
                  Icons.headphones,
                  color: widget.audioPath == null
                      ? Colors.white24
                      : const Color(0xFF4CAF50),
                  size: 20,
                ),
                onPressed: _openInListen,
              ),
            ],
          ),
        ),
        // Video player
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildVideoPlayer(),
        ),
        // Subtitle
        _buildSubtitleArea(),
        // Tabs
        _buildTabBar(),
        Expanded(child: _buildTabContent()),
      ],
    );
  }

  Widget _buildLandscape() {
    return Column(
      children: [
        // Title Bar (Compact)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: const Color(0xFF161B22),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child:
                    const Icon(Icons.arrow_back, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.video.title,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // YT-LR-002 (IN4-88): menu Subtitle Settings (cả ngang lẫn dọc).
              IconButton(
                tooltip: context.uiText('Cài đặt phụ đề'),
                icon: const Icon(Icons.subtitles_outlined,
                    color: Colors.white70, size: 18),
                onPressed: _openSubtitleSettings,
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Left: video + subtitle
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    Expanded(child: _buildVideoPlayer()),
                    _buildSubtitleArea(),
                  ],
                ),
              ),
              // Right: tabs
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildTabBar(),
                    Expanded(child: _buildTabContent()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Video Player ──────────────────────────────────────────
  Widget _buildVideoPlayer() {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _ytCtrl),
        // (IN4-78 nghiệm thu 2) "load từ rất lâu" mà không có tín hiệu —
        // hiện spinner tới khi player ready / phát đầu tiên.
        // IN4-81: KHÔNG che video — chỉ đặt spinner ở GÓC (video phải thấy
        // được ngay, lời/dịch không được chặn player).
        if (!_videoReady && _playerError == null)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white70),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Đang tải…',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        // (IN4-78) Không để màn lỗi YouTube chết im lặng: overlay + Thử lại.
        if (_playerError != null)
          Container(
            color: const Color(0xCC000000),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                const SizedBox(height: 10),
                Text(
                  _playerError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: _reloadPlayer,
                      child: const Text('Thử lại'),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _openExternally,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Mở ngoài'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Subtitle area ─────────────────────────────────────────
  Widget _buildSubtitleArea() {
    if (_isLoading) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_lines.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child:
            const Text('Không có phụ đề', style: TextStyle(color: Colors.grey)),
      );
    }
    final line = _lines[_currentLineIdx.clamp(0, _lines.length - 1)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action buttons row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
            children: [
              _ActionBtn(
                icon: Icons.check,
                label: 'Biết hết',
                color: const Color(0xFF4CAF50),
                onTap: () {
                  for (final w in line.words) {
                    _setWordState(w.text, WordState.known);
                  }
                },
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: Icons.menu_book,
                label: 'Học cả câu',
                color: const Color(0xFF9C27B0),
                onTap: () {
                  for (final w in line.words) {
                    if (w.state == WordState.unknown) {
                      _setWordState(w.text, WordState.learning);
                    }
                  }
                },
              ),
              const SizedBox(width: 8),
              _ActionBtn(
                icon: _looping ? Icons.repeat_on : Icons.repeat,
                label: _looping ? 'Lặp câu' : 'Lặp câu',
                color: _looping
                    ? const Color(0xFFFF9800)
                    : const Color(0xFF607D8B),
                onTap: () {
                  setState(() => _looping = !_looping);
                  if (_looping) {
                    _seekTo(line.start.inMilliseconds / 1000.0);
                  }
                },
              ),
              const Spacer(),
              // Navigation
              Row(children: [
                _navBtn(
                  Icons.replay_10,
                  () => _seekTo(_currentTime - 10),
                ),
                const SizedBox(width: 10),
                _navBtn(
                  Icons.skip_previous,
                  () {
                    if (_currentLineIdx > 0) {
                      _seekTo(_lines[_currentLineIdx - 1].start.inMilliseconds /
                          1000);
                    }
                  },
                ),
                const SizedBox(width: 10),
                _navBtn(
                  Icons.skip_next,
                  () {
                    if (_currentLineIdx < _lines.length - 1) {
                      _seekTo(_lines[_currentLineIdx + 1].start.inMilliseconds /
                          1000);
                    }
                  },
                ),
              ]),
            ],
          ),
          ),
          const SizedBox(height: 12),
          // Colored words subtitle (YT-LR-002: ẩn khi chế độ `Ẩn phụ đề`).
          if (_settings.hidesSubtitle)
            _buildHiddenSubtitleHint()
          else
            Wrap(
              spacing: 5,
              runSpacing: 4,
              children: line.words
                  .map((w) => _WordChip(
                        word: w,
                        onTap: () => _showWordPopup(w),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 10),
          // Translation (YT-LR-002: 4 chế độ — hiện / ẩn / mờ / ẩn cả phụ đề).
          _buildTranslationLine(line),
          // YT-AUDIT-04 (IN4-103): khi ngôn ngữ dịch trùng phụ đề gốc, app
          // rớt về tiếng Việt — phải NÓI RA, không được lén như bản cũ.
          _buildLanguageFallbackNotice(),
        ],
      ),
    );
  }

  /// YT-AUDIT-04 (IN4-103): dòng chú thích NHỎ dưới bản dịch khi ngôn ngữ
  /// đích trùng với phụ đề gốc. Bản cũ tự đổi sang tiếng Việt mà không nói gì
  /// (`target == 'en' ? 'vi' : target`) ⇒ người dùng tưởng app dịch sai.
  Widget _buildLanguageFallbackNotice() {
    final resolved = YtLearningSettings.resolveTargetLang(
      subtitleLang: _settings.subtitleLang,
      overrideTargetLang: _settings.targetLang,
      homeTargetLang: TranslationService().targetLang,
    );
    if (!resolved.fellBack) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        context.uiText(
          'Ngôn ngữ dịch trùng với phụ đề gốc — đang tạm dùng tiếng Việt.',
        ),
        style: const TextStyle(color: Colors.amber, fontSize: 10, height: 1.3),
      ),
    );
  }

  /// YT-LR-002 (IN4-88) — chế độ `Ẩn phụ đề`: giữ chỗ trống cùng chiều cao để
  /// đổi chế độ không làm giật player, và vẫn cho biết cách hiện lại.
  Widget _buildHiddenSubtitleHint() {
    return SizedBox(
      height: 44,
      child: Center(
        child: Text(
          context.uiText('Phụ đề đang ẩn — mở Cài đặt phụ đề để hiện lại.'),
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ),
    );
  }

  /// YT-LR-002 (IN4-88) — phần bản dịch theo 4 chế độ:
  /// `Có bản dịch` (hiện) · `Ẩn bản dịch` (khỏi) · `Làm mờ bản dịch`
  /// (mờ, bấm để hiện tạm rồi mờ lại) · `Ẩn phụ đề` (khỏi cả hai).
  ///
  /// Chế độ "mờ" làm mờ bằng **chính bóng của chữ** (`TextStyle.shadows`),
  /// KHÔNG dùng blur ở lớp composite. Lý do (YT-AUDIT-02 / IN4-98) — cả hai
  /// cách trước đều hỏng, mỗi cách một kiểu:
  ///   • `ImageFiltered(ImageFilter.blur)` ⇒ render **TRỐNG** trên máy thật.
  ///   • `MaskFilter.blur` trên `foreground: Paint()` của chữ ⇒ bị Impeller
  ///     bỏ qua ⇒ chữ hiện bình thường, người dùng "không thấy gì".
  /// `TextStyle.shadows` được Skia lẫn Impeller hỗ trợ đầy đủ: glyph fill để
  /// gần trong suốt rồi vẽ 2 lớp bóng mờ cùng màu ⇒ chữ thành vệt mờ mà
  /// **luôn vẽ ra cái gì đó** (không bao giờ trống).
  Widget _buildTranslationLine(SubtitleLine line) {
    if (!_settings.showsTranslation) return const SizedBox.shrink();
    final text = line.translation;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    final blurred = _settings.blursTranslation && !_translationRevealed;

    final child = Text(
      text,
      style: blurred
          ? const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.4,
              // Alpha thấp ⇒ nét chữ thật gần như tàng hình, chỉ còn lại
              // vệt mờ do 2 lớp bóng vẽ ra.
              color: Color(0x4DFFC107),
              shadows: <Shadow>[
                Shadow(color: Color(0xFFFFC107), blurRadius: 7),
                Shadow(color: Color(0xFFFFC107), blurRadius: 7),
              ],
            )
          : TextStyle(
              color: Colors.amber.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
    );

    if (!_settings.blursTranslation) return child;

    // Chế độ mờ: bấm để hiện tạm, bấm lần nữa để mờ lại.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _translationRevealed = !_translationRevealed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 4),
          Text(
            _translationRevealed
                ? context.uiText('Bấm để làm mờ bản dịch.')
                : context.uiText('Bấm để hiện bản dịch.'),
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: Colors.grey[400], size: 20),
      ),
    );
  }

  void _seekTo(double seconds) {
    if (seconds < 0) seconds = 0;
    _ytCtrl.runJavaScript('window._in4upSeek && window._in4upSeek($seconds);');
  }

  void _pauseVideo() {
    _ytCtrl.runJavaScript('window._in4upPause && window._in4upPause();');
  }

  /// Mở audio ĐÃ TẢI (tab TẢI) trong tab Nghe — dùng chung đường LRC.
  Future<void> _openInListenTab() async {
    final audio = _downloadedAudioPath;
    if (audio == null || audio.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.uiText('Chưa có audio đã tải.')),
        ),
      );
      return;
    }
    await _openAudioInListen(audio);
  }

  Future<void> _openInListen() async {
    final audio = widget.audioPath;
    if (audio == null || audio.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.uiText(
            'Tải audio ở YouTube → tab Audio, rồi mở lại Học video.',
          )),
        ),
      );
      return;
    }
    await _openAudioInListen(audio);
  }

  /// Nạp audio (đã tải hoặc đã có) + LRC phụ đề vào tab Nghe.
  Future<void> _openAudioInListen(String audio) async {
    final asYt = YtVideo(
      id: widget.video.id,
      title: widget.video.title,
      channel: widget.video.channelTitle,
      thumb: widget.video.thumb,
    );
    // LRC dùng VĂN BẢN GỐC của dòng (fullText) — không dùng phần "chữ mới"
    // (khi track là rolling window) để LRC khớp đúng track phụ đề gốc.
    final captions = _lines
        .map((l) => YtCaptionLine(l.start, l.end, l.fullText,
            translation: l.translation))
        .toList();
    final lrcPath = captions.isEmpty
        ? null
        : await YtService.instance.saveLrc(captions, asYt);
    if (!mounted) return;
    await context.read<PlayerProvider>().loadSong(
          path: audio,
          title: widget.video.title,
          artist: widget.video.channelTitle,
          autoPlay: true,
        );
    if (lrcPath != null && mounted) {
      await context.read<TextProvider>().loadTextFile(lrcPath);
    }
    if (mounted) Navigator.pop(context);
  }

  /// YT-LR-002 (IN4-86) — mở bảng `Word Dictionary & Analysis` thay vì sheet
  /// phân tích cũ: có phiên âm, thanh tần suất, 3 nút Known/Learning/Ignored
  /// và tab Giải thích & Ngữ pháp.
  ///
  /// Vẫn **pause video** khi mở (giữ nguyên hành vi cũ) và ghi nhớ từ đang mở
  /// để tab Lexa dùng làm ngữ cảnh.
  void _showWordPopup(LrWord word) {
    _pauseVideo();
    String? contextSentence;
    if (_lines.isNotEmpty && _currentLineIdx < _lines.length) {
      contextSentence = _lines[_currentLineIdx].text;
    }
    setState(() => _selectedWord = word.text);

    showYtWordPanel(
      context,
      word: word,
      sentenceContext: contextSentence,
      settings: _settings,
      onFrequencyChanged: _onFrequencyChanged,
      onStateChanged: (state) => _setWordState(word.text, state),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF161B22),
      child: Row(
        children: [
          // Toggle sidebar arrow
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Icon(Icons.chevron_right, color: Colors.grey[600], size: 18),
          ),
          // Tabs
          Expanded(
            child: TabBar(
              controller: _tabCtrl,
              // YT-LR-002 (IN4-87): 4 tab — cho cuộn ngang trên màn hẹp.
              isScrollable: true,
              indicatorColor: const Color(0xFF9C27B0),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: context.uiText('VĂN BẢN')),
                Tab(text: context.uiText('TỪ')),
                Tab(text: context.uiText('TẢI')),
                Tab(text: context.uiText('LEXA')),
              ],
            ),
          ),
          // Search icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.search, color: Colors.grey[600], size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildTranscriptTab(),
        _buildWordTab(),
        _buildDownloadTab(),
        _buildLexaTab(),
      ],
    );
  }

  /// YT-LR-002 (IN4-87) — tab `Lexa AI Chat`: hỏi đáp về từ vựng / cấu trúc
  /// câu / ngữ pháp của video đang xem. Local-first, không gọi server.
  Widget _buildLexaTab() {
    final sentence = _lines.isEmpty
        ? null
        : _lines[_currentLineIdx.clamp(0, _lines.length - 1)].text;
    return YtLexaChatTab(
      videoTitle: widget.video.title,
      videoId: widget.video.id,
      currentSentence: sentence,
      selectedWord: _selectedWord,
    );
  }

  // ── Tab TẢI (IN4-77): audio + caption + lịch sử ở giao diện tầng 2 ──

  /// Đường dẫn audio đã tải (để mở trong tab Nghe).
  String? _downloadedAudioPath;
  String? _downloadStatus;
  double? _downloadProgress;
  bool _downloading = false;
  // YT-LR-002 (fix tab Tải Audio kẹt "Đang tải…"): giữ subscription để có thể
  // huỷ giữa chừng (`await for` KHÔNG huỷ được từ ngoài) + bộ canh báo kẹt khi
  // quá lâu không nhận thêm byte nào.
  StreamSubscription<YtDownloadEvent>? _dlSub;
  Timer? _dlWatchdog;
  bool _dlStalled = false;

  /// Lịch sử xem (tải lại khi mở tab).
  List<YtVideo> _history = const [];
  bool _historyLoaded = false;

  Future<void> _loadHistory() async {
    await YtHistory.ensureOpen();
    final list = YtHistory.load();
    if (!mounted) return;
    setState(() {
      _history = list;
      _historyLoaded = true;
    });
  }

  /// Tải audio của video hiện tại (yt-dlp/explode) — có progress + nút Dừng.
  ///
  /// YT-LR-002: bản cũ dùng `await for` ⇒ không có cách nào ngắt luồng từ UI,
  /// nên nếu `YoutubeExplode` treo ở bước lấy manifest/stream thì giao diện kẹt
  /// ở "Đang tải…" mãi mãi. Ở đây đổi sang `listen(...)` để giữ
  /// [StreamSubscription], cộng thêm bộ canh 45 giây không có tiến triển →
  /// hiện cảnh báo + nút Dừng.
  Future<void> _downloadAudio() async {
    if (_downloading) return;
    await _dlSub?.cancel();
    _dlWatchdog?.cancel();
    setState(() {
      _downloading = true;
      _dlStalled = false;
      _downloadProgress = 0;
      _downloadStatus = 'Đang chuẩn bị...';
    });
    final video = YtVideo(
      id: widget.video.id,
      title: widget.video.title,
      channel: widget.video.channelTitle,
      thumb: widget.video.thumb,
    );

    var lastProgress = 0.0;
    var stallTicks = 0;
    _dlWatchdog = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || !_downloading) return;
      // Chỉ đếm khi con số % không nhúc nhích (đang chờ mạng/manifest).
      if ((_downloadProgress ?? 0) > lastProgress + 0.001) {
        lastProgress = _downloadProgress ?? 0;
        stallTicks = 0;
        if (_dlStalled && mounted) setState(() => _dlStalled = false);
        return;
      }
      stallTicks++;
      if (stallTicks >= 3 && mounted) {
        setState(() {
          _dlStalled = true;
          _downloadStatus =
              'Không thấy tiến triển trong 45 giây. YouTube có thể đang chặn — bấm Dừng rồi thử lại.';
        });
      }
    });

    _dlSub = YtDownloader.instance.download(video).listen(
      (event) {
        if (!mounted) return;
        if (event is YtDownloadProgress) {
          setState(() {
            _downloadProgress = event.progress;
            if (!_dlStalled) _downloadStatus = event.progressText;
          });
        } else if (event is YtDownloadDone) {
          _stopDownloadWatchdog();
          setState(() {
            _downloading = false;
            _downloadedAudioPath = event.filePath;
            _downloadProgress = 1;
            _downloadStatus = 'Đã tải xong (${event.quality})';
          });
        } else if (event is YtDownloadFailed) {
          _stopDownloadWatchdog();
          setState(() {
            _downloading = false;
            _downloadStatus = 'Tải thất bại: ${event.message}';
          });
        }
      },
      onError: (Object e) {
        _stopDownloadWatchdog();
        if (mounted) {
          setState(() {
            _downloading = false;
            _downloadStatus = 'Lỗi: $e';
          });
        }
      },
      onDone: () {
        // Luồng đóng mà chưa emit Done/Failed (bị huỷ) → chốt trạng thái.
        _stopDownloadWatchdog();
        if (mounted && _downloading) {
          setState(() {
            _downloading = false;
            _downloadStatus ??= 'Đã dừng tải.';
          });
        }
      },
      cancelOnError: false,
    );
  }

  void _stopDownloadWatchdog() {
    _dlWatchdog?.cancel();
    _dlWatchdog = null;
  }

  /// Bấm nút "Dừng": ngắt luồng tải, báo [YtDownloader] dừng ghi file, xoá
  /// subscription và trả giao diện về trạng thái chờ.
  Future<void> _cancelDownloadAudio() async {
    if (!_downloading) return;
    YtDownloader.instance.cancel();
    await _dlSub?.cancel();
    _dlSub = null;
    _stopDownloadWatchdog();
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _dlStalled = false;
      _downloadProgress = null;
      _downloadStatus = 'Đã dừng tải audio.';
    });
    debugPrint('[in4up-yt] audio download stopped by user ${widget.video.id}');
  }

  /// Tải phụ đề (caption) của video hiện tại về máy (file .srt).
  Future<void> _downloadCaptions() async {
    setState(() => _downloadStatus = 'Đang tải phụ đề...');
    try {
      final lines = await YtService.instance
          .fetchCaptions(widget.video.id, lang: 'en');
      if (lines.isEmpty) {
        if (mounted) {
          setState(() => _downloadStatus = 'Video không có phụ đề (en)');
        }
        return;
      }
      final path = await YtService.instance
          .saveLrc(lines, YtVideo(
            id: widget.video.id,
            title: widget.video.title,
            channel: widget.video.channelTitle,
            thumb: widget.video.thumb,
          ));
      if (mounted) {
        setState(() => _downloadStatus =
            'Đã lưu phụ đề (${lines.length} dòng): ${path ?? "?"}');
      }
    } catch (e) {
      if (mounted) setState(() => _downloadStatus = 'Lỗi tải phụ đề: $e');
    }
  }

  Widget _buildDownloadTab() {
    if (!_historyLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Audio ──
        Text(
          context.uiText('Tải audio'),
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _downloading ? null : _downloadAudio,
                icon: const Icon(Icons.download, size: 16),
                label: Text(context.uiText(
                    _downloading ? 'Đang tải...' : 'Tải audio')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _downloading ? null : _downloadCaptions,
                icon: const Icon(Icons.subtitles, size: 16),
                label: Text(context.uiText('Tải phụ đề')),
              ),
            ),
          ],
        ),
        if (_downloading) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: _downloadProgress == null || _downloadProgress == 0
                      ? null
                      : _downloadProgress,
                ),
              ),
              const SizedBox(width: 8),
              // YT-LR-002: nút Dừng — tab Tải trước đây không có cách huỷ.
              SizedBox(
                height: 28,
                child: OutlinedButton.icon(
                  onPressed: _cancelDownloadAudio,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.stop, size: 14),
                  label: Text(context.uiText('Dừng')),
                ),
              ),
            ],
          ),
        ],
        if (_downloadStatus != null) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_dlStalled) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 1, right: 5),
                  child: Icon(Icons.hourglass_disabled,
                      size: 13, color: Colors.orangeAccent),
                ),
              ],
              Expanded(
                // YT-LR-002: đưa qua `uiText` để các chuỗi CỐ ĐỊNH
                // ("Đã dừng tải audio.", "Không thấy tiến triển…") có bản
                // tiếng Anh; chuỗi động (ví dụ "128 / 45.2 MB") không khớp
                // catalog nên được trả nguyên — không đổi hành vi.
                child: Text(
                  context.uiText(_downloadStatus!),
                  style: TextStyle(
                    color: _dlStalled ? Colors.orangeAccent : Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_downloadedAudioPath != null) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _openInListenTab,
            icon: const Icon(Icons.headphones, size: 16),
            label: Text(context.uiText('Mở trong tab Nghe')),
          ),
        ],
        const SizedBox(height: 18),
        // ── Lịch sử ──
        Text(
          context.uiText('Lịch sử xem'),
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_history.isEmpty)
          Text(
            context.uiText('Chưa có lịch sử xem.'),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          )
        else
          ..._history.take(30).map((v) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: v.thumb == null
                    ? const Icon(Icons.play_circle_outline,
                        color: Colors.white38, size: 20)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          v.thumb!,
                          width: 44,
                          height: 26,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.play_circle_outline,
                              color: Colors.white38,
                              size: 20),
                        ),
                      ),
                title: Text(
                  v.shortTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                subtitle: Text(
                  v.channel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => YtPlayerScreen(
                        video: YtExVideo(
                          id: v.id,
                          title: v.title,
                          channelId: '',
                          channelTitle: v.channel,
                          thumb: v.thumb,
                        ),
                      ),
                    ),
                  );
                },
              )),
      ],
    );
  }

  // ── Transcript tab ────────────────────────────────────────
  /// YT-AUDIT-10 (IN4-102): hàng công tắc "Tự động theo dòng hiện tại"
  /// (mặc định BẬT) + danh sách tự cuộn theo dòng đang phát.
  Widget _buildTranscriptTab() {
    final follow = _settings.transcriptAutoFollow;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Icon(
                follow ? Icons.play_arrow : Icons.pan_tool_outlined,
                size: 14,
                color: follow ? const Color(0xFF9C27B0) : Colors.grey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  follow
                      ? context.uiText('Tự động theo dòng hiện tại')
                      : context.uiText('Cuộn tự do'),
                  style: TextStyle(
                    color: follow ? Colors.white70 : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(
                height: 26,
                child: Switch(
                  value: follow,
                  activeColor: const Color(0xFF9C27B0),
                  onChanged: _onAutoFollowChanged,
                ),
              ),
            ],
          ),
        ),
        // YT-AUDIT-11 (IN4-106): căn chỉnh NGAY TẠI tab này — người dùng phải
        // VỪA NGHE VỪA BẤM +/− được. Mở sheet thì không nghe thấy gì để mà chỉnh.
        _buildAudioSyncTuner(),
        Expanded(child: _buildTranscriptList()),
      ],
    );
  }

  /// YT-AUDIT-11 (IN4-106): hàng căn chỉnh âm thanh & chữ (bước 0,1 giây).
  Widget _buildAudioSyncTuner() {
    final lead = _settings.audioLeadMs;
    final head = lead == 0
        ? context.uiText('Đang khớp')
        : (lead > 0
            ? context.uiText('Âm thanh nhanh hơn chữ')
            : context.uiText('Chữ nhanh hơn âm thanh'));
    final secs = _settings.audioLeadSeconds;
    final sign = secs > 0 ? '+' : '';
    final value =
        lead == 0 ? '' : '  $sign${secs.toStringAsFixed(1)}s';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          const Icon(Icons.sync_alt, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$head$value',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          _syncTuneButton(Icons.remove, -1),
          _syncTuneButton(Icons.add, 1),
          if (lead != 0)
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 16,
                color: Colors.grey,
                icon: const Icon(Icons.restart_alt),
                tooltip: context.uiText('Đặt về 0'),
                onPressed: () => _onAudioLeadChanged(0),
              ),
            ),
        ],
      ),
    );
  }

  Widget _syncTuneButton(IconData icon, int dir) {
    return SizedBox(
      width: 30,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        color: Colors.white70,
        icon: Icon(icon),
        tooltip: dir > 0 ? '+' : '-',
        onPressed: () => _onAudioLeadChanged(
          // Chốt về bước 100 ms TRƯỚC rồi mới +/-: nếu không, giá trị đã lưu
          // lẻ (vd 437 từ nút "áp dụng") cộng thêm sẽ thành 537, 637…
          YtLearningSettings.snapAudioLead(_settings.audioLeadMs) +
              dir * YtLearningSettings.kAudioLeadStep,
        ),
      ),
    );
  }

  /// YT-AUDIT-11 (IN4-106): đổi bù trễ thủ công (biên được kẹp trong model).
  void _onAudioLeadChanged(double v) {
    final next = _settings.copyWith(
        audioLeadMs: YtLearningSettings.snapAudioLead(v));
    setState(() => _settings = next);
    unawaited(YtLearningSettingsService.save(next));
  }

  Widget _buildTranscriptList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _lines.length,
      itemBuilder: (_, i) {
        final line = _lines[i];
        final isActive = i == _currentLineIdx;
        return GestureDetector(
          // YT-AUDIT-10: key CHỈ gắn cho dòng active — không phải mỗi dòng
          // một key (transcript có thể dài hàng nghìn dòng).
          key: isActive ? _activeLineKey : null,
          onTap: () {
            setState(() => _currentLineIdx = i);
            _seekTo(line.start.inMilliseconds / 1000.0);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.transparent,
              border: Border(
                  left: BorderSide(
                      color: isActive
                          ? const Color(0xFF9C27B0)
                          : Colors.transparent,
                      width: 2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isActive)
                  Container(
                    margin: const EdgeInsets.only(top: 4, right: 8),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF9C27B0),
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(width: 16),
                // YT-LR-002 (IN4-88): 3 bố cục danh sách phụ đề.
                Expanded(child: _buildTranscriptBody(line)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// YT-LR-002 (IN4-88) — thân một dòng transcript theo bố cục đã chọn:
  /// `simple` (chỉ bản gốc) · `sideBySide` (gốc và dịch cạnh nhau) ·
  /// `stacked` (gốc trên, dịch dưới).
  Widget _buildTranscriptBody(SubtitleLine line) {
    final original = _buildTranscriptWords(line);
    final translation = line.translation;
    final hasTranslation = translation != null && translation.isNotEmpty;

    switch (_settings.subtitleLayout) {
      case YtSubtitleLayout.simple:
        return original;

      case YtSubtitleLayout.sideBySide:
        if (!hasTranslation) return original;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: original),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                translation,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ),
          ],
        );

      case YtSubtitleLayout.stacked:
        if (!hasTranslation) return original;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            original,
            const SizedBox(height: 3),
            Text(
              translation,
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        );
    }
  }

  Widget _buildTranscriptWords(SubtitleLine line) {
    return Wrap(
      spacing: 3,
      runSpacing: 2,
      children: line.words
          .map((w) => GestureDetector(
                onTap: () => _showWordPopup(w),
                child: Text(
                  '${w.text} ',
                  style: TextStyle(
                    color: w.type == 'other' ? Colors.white : w.typeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ))
          .toList(),
    );
  }

  // ── Word tab ──────────────────────────────────────────────
  Widget _buildWordTab() {
    // Collect all unique words from all lines
    final allWords = <String, LrWord>{};
    for (final line in _lines) {
      for (final w in line.words) {
        final key = w.text.toLowerCase();
        allWords.putIfAbsent(key, () => w);
      }
    }

    // Count per word
    final countMap = <String, int>{};
    for (final line in _lines) {
      for (final w in line.words) {
        countMap[w.text.toLowerCase()] =
            (countMap[w.text.toLowerCase()] ?? 0) + 1;
      }
    }

    // Group by rank
    final total = allWords.length;
    final known = _knownCount;
    final learning = _learningCount;
    final ignored = _ignoredCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          _WordStatsRow(
            known: known,
            learning: learning,
            ignored: ignored,
            total: total,
          ),
          const SizedBox(height: 12),

          // Word groups by rank
          _buildWordGroup('1 - 100', allWords, countMap, 1, 100),
          _buildWordGroup('101 - 200', allWords, countMap, 101, 200),
          _buildWordGroup('201 - 300', allWords, countMap, 201, 300),
          _buildWordGroup('301+', allWords, countMap, 301, 999999),
        ],
      ),
    );
  }

  Widget _buildWordGroup(String label, Map<String, LrWord> allWords,
      Map<String, int> countMap, int minRank, int maxRank) {
    final words = allWords.values
        .where((w) => w.langRank >= minRank && w.langRank <= maxRank)
        .toList()
      ..sort((a, b) => countMap[b.text.toLowerCase()]!
          .compareTo(countMap[a.text.toLowerCase()]!));

    if (words.isEmpty) return const SizedBox.shrink();

    // Group by count
    final byCount = <int, List<LrWord>>{};
    for (final w in words) {
      final c = countMap[w.text.toLowerCase()] ?? 1;
      byCount.putIfAbsent(c, () => []).add(w);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(label,
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
        ...byCount.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Count badge
                  Container(
                    width: 30,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${e.key}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: e.value
                          .map((w) => GestureDetector(
                                onTap: () => _showWordPopup(w),
                                child: Text(
                                  w.text.toLowerCase(),
                                  style: TextStyle(
                                    color: w.state == WordState.known
                                        ? const Color(0xFF4CAF50)
                                        : w.state == WordState.learning
                                            ? const Color(0xFF9C27B0)
                                            : w.typeColor,
                                    fontSize: 13,
                                    fontWeight: w.state != WordState.unknown
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    decoration: w.state == WordState.ignored
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  HELPER WIDGETS
// ══════════════════════════════════════════════════════════

class _WordChip extends StatelessWidget {
  final LrWord word;
  final VoidCallback onTap;
  const _WordChip({required this.word, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = word.type == 'other' || word.type == 'prep'
        ? Colors.white
        : word.typeColor;

    return GestureDetector(
      onTap: onTap,
      child: Text(
        '${word.text} ',
        style: TextStyle(
          color: color,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.4,
          decoration:
              word.state == WordState.known ? TextDecoration.underline : null,
          decorationColor: Color(0xFF4CAF50).withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _WordStatsRow extends StatefulWidget {
  final int known, learning, ignored, total;
  const _WordStatsRow(
      {required this.known,
      required this.learning,
      required this.ignored,
      required this.total});

  @override
  State<_WordStatsRow> createState() => _WordStatsRowState();
}

class _WordStatsRowState extends State<_WordStatsRow> {
  String? _tooltip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatChip(
              label: '✓ ${widget.known}',
              color: const Color(0xFF4CAF50),
              bgColor: const Color(0xFF1B5E20),
              onTap: () => setState(
                  () => _tooltip = _tooltip == 'known' ? null : 'known'),
            ),
            const SizedBox(width: 6),
            _StatChip(
              label: '📖 ${widget.learning}',
              color: const Color(0xFF9C27B0),
              bgColor: const Color(0xFF4A148C),
              onTap: () => setState(
                  () => _tooltip = _tooltip == 'learning' ? null : 'learning'),
            ),
            const SizedBox(width: 6),
            _StatChip(
              label: '⊘ ${widget.ignored}',
              color: Colors.grey,
              bgColor: Colors.grey.withValues(alpha: 0.2),
              onTap: () => setState(
                  () => _tooltip = _tooltip == 'ignored' ? null : 'ignored'),
            ),
            const SizedBox(width: 8),
            Text('/ ${widget.total}',
                style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ],
        ),
        if (_tooltip != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _tooltip == 'known'
                  ? 'Known\n(Click to show / hide)'
                  : _tooltip == 'learning'
                      ? 'Learning\n(Click to show / hide)'
                      : 'Ignored\n(Click to show / hide)',
              style: TextStyle(color: Colors.grey[300], fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _StatChip({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
