//
// lib/screens/tools/youglish/youglish_mini_sheet.dart
//
// Mini bottom sheet hiển thị YouGlish trực tiếp trên một từ — mở nhanh, không
// cần navigate sang màn hình riêng.
//
// PRON-002: file chuyển từ `screens/tools/word_list/` sang `screens/tools/youglish/`
// (`git mv`, giữ lịch sử) vì nó KHÔNG còn là đồ riêng của Word List — mọi surface
// tra từ đều gọi vào đây qua `WordPronunciationRow` (ADR-0015 D5: một lớp WebView
// duy nhất, một sheet duy nhất). Thêm ở PRON-002: watchdog 8 s + bật "nguồn
// không khả dụng" ⇒ banner 3 hành động (TTS / thử lại / mở trình duyệt).
//
// PRON-001 (ADR-0015 D5): sheet này KHÔNG còn tự dựng WebViewController và
// KHÔNG còn copy `_buildUrl()` — phần WebView + URL đã về `youglish_view.dart`.
// Hai thay đổi có chủ đích, được ghi trong card PRON-001:
//   • ngôn ngữ/accent khởi tạo từ `YouGlishPrefs` (trước: luôn English-US,
//     mỗi điểm vào nhớ riêng);
//   • danh sách ngôn ngữ bỏ cắt `.take(5)` → đủ `YouGlishLanguage.values`,
//     accent đủ 7 mục (trước: hiện 5 ngôn ngữ, 3 accent).
// Giao diện, kích thước DraggableScrollableSheet, header và màu giữ nguyên.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../providers/text_provider.dart';
import 'youglish_config.dart';
import 'youglish_prefs.dart';
import 'youglish_view.dart';

class YouGlishMiniSheet extends StatefulWidget {
  const YouGlishMiniSheet({
    super.key,
    required this.word,
    this.language = YouGlishLanguage.english,
    this.accent = YouGlishAccent.us,
  });

  final String word;
  final YouGlishLanguage language;
  final YouGlishAccent accent;

  /// PRON-002: ngân sách chờ trang — quá mức này mà chưa `onPageFinished` thì
  /// sheet coi YouGlish là KHÔNG khả dụng (banner + TTS), không để khung trắng.
  static const Duration loadBudget = Duration(seconds: 8);

  static Future<void> show(BuildContext context, String word) async {
    HapticFeedback.selectionClick();
    // Đọc pref TRƯỚC khi dựng sheet để WebView chỉ nạp 1 lần (không đổi URL
    // ngay sau frame đầu).
    final prefs = await YouGlishPrefs.load();
    if (!context.mounted) return;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => YouGlishMiniSheet(
        word: word,
        language: prefs.language,
        accent: prefs.accent,
      ),
    );
  }

  @override
  State<YouGlishMiniSheet> createState() => _YouGlishMiniSheetState();
}

class _YouGlishMiniSheetState extends State<YouGlishMiniSheet> {
  late YouGlishLanguage _lang = widget.language;
  late YouGlishAccent _accent = widget.accent;

  /// Tăng lên ⇒ `YouGlishView` nạp lại cùng URL (nút reload ở header).
  int _reloadToken = 0;

  // PRON-002 — bậc thoái lui: YouGlish là dịch vụ mạng, nên sheet không được
  // biến thành khung trắng khi trang lỗi hoặc treo quá
  // `YouGlishMiniSheet.loadBudget`. Thay vì tự pop (mất phương hướng giữa luồng
  // đọc), sheet hiện banner 3 hành động và tự phát TTS MỘT lần để người dùng vẫn
  // NGHE được từ. (Chệch có chủ đích so với chữ "close sheet" trong PLAN-038 §2
  // — ghi rõ trong KANBAN PRON-002.)
  Timer? _watchdog;
  bool _unavailable = false;
  bool _loadedOnce = false;
  bool _autoTtsPlayed = false;

  @override
  void initState() {
    super.initState();
    _startWatchdog();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(YouGlishMiniSheet.loadBudget, () {
      if (!mounted || _loadedOnce) return;
      setState(() => _unavailable = true);
      _fallbackToTts();
    });
  }

  void _onLoaded() {
    _watchdog?.cancel();
    if (!mounted) return;
    _loadedOnce = true;
    if (_unavailable) setState(() => _unavailable = false);
  }

  void _onLoadError() {
    if (!mounted || _loadedOnce) return; // lỗi sub-resource sau khi trang đã mở ⇒ bỏ qua
    setState(() => _unavailable = true);
    _fallbackToTts();
  }

  Future<void> _fallbackToTts() async {
    if (_autoTtsPlayed) return;
    _autoTtsPlayed = true;
    if (!mounted) return;
    try {
      final tp = context.read<TextProvider>();
      await tp.speak(widget.word);
    } catch (_) {
      // Ngoài Read Mode (vd Word List) không có TextProvider ⇒ chỉ banner.
    }
  }

  Future<void> _openInBrowser() async {
    final url = YouGlishUrl.build(
      word: widget.word,
      language: _lang,
      accent: _isEnglish ? _accent : null,
      autoplay: false,
    );
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  bool get _isEnglish => _lang == YouGlishLanguage.english;

  /// Ghi xuống `YouGlishPrefs` để các điểm vào khác (tab Đọc ở PRON-002, tool
  /// YouGlish) mở ra đúng ngôn ngữ/accent người dùng vừa chọn.
  Future<void> _persist() async {
    final prefs = await YouGlishPrefs.load();
    await prefs.setLanguage(_lang);
    await prefs.setAccent(_accent);
  }

  void _setLang(YouGlishLanguage value) {
    HapticFeedback.selectionClick();
    if (_lang == value) return;
    setState(() => _lang = value);
    _persist();
  }

  void _setAccent(YouGlishAccent value) {
    HapticFeedback.selectionClick();
    if (_accent == value) return;
    setState(() => _accent = value);
    _persist();
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
                      onPressed: () {
                        setState(() => _reloadToken++);
                        _startWatchdog();
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    // PRON-002: thoát sang trình duyệt khi WebView không như ý
                    IconButton(
                      icon: const Icon(Icons.open_in_new_rounded,
                          size: 18, color: Colors.grey),
                      onPressed: _openInBrowser,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    // Copy word
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.word));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.uiText('Đã copy')),
                            duration: const Duration(seconds: 1),
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
                      child: Icon(Icons.close,
                          color: Colors.grey[600], size: 20),
                    ),
                  ],
                ),
              ),

              // Lang + Accent selector
              _buildControls(),

              if (_unavailable) _buildUnavailableBanner(),

              const SizedBox(height: 8),

              // WebView (YouGlishView — một nguồn sự thật, PRON-001)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: YouGlishView(
                    word: widget.word,
                    language: _lang,
                    accent: _isEnglish ? _accent : null,
                    radius: 12,
                    webBackgroundColor: const Color(0xFF1A1A2E),
                    indicatorColor: const Color(0xFF00BCD4),
                    loadingMessage: 'Đang tải YouGlish...',
                    claimGestures: true,
                    reloadToken: _reloadToken,
                    onLoadError: _onLoadError,
                    onLoaded: _onLoaded,
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

  Widget _buildUnavailableBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB74D).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFB74D).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: Color(0xFFFFB74D)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.uiText('Không mở được YouGlish — đã dùng giọng máy'),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _reloadToken++);
              _startWatchdog();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00BCD4),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(context.uiText('Thử lại')),
          ),
          TextButton(
            onPressed: _openInBrowser,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(context.uiText('Mở trình duyệt')),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Language chips — đủ danh sách (bỏ `.take(5)` — PRON-001)
          ...YouGlishLanguage.values.map((lang) {
            final sel = _lang == lang;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => _setLang(lang),
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

          // Divider + accent chips — chỉ khi English (YouGlish chỉ nhận accent English)
          if (_isEnglish) ...[
            Container(
                width: 1,
                height: 20,
                color: Colors.white.withValues(alpha: 0.12),
                margin: const EdgeInsets.symmetric(horizontal: 6)),
            ...YouGlishAccent.values.map((acc) {
              final sel = _accent == acc;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => _setAccent(acc),
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
