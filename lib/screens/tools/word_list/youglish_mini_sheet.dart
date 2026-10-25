//
// Mini bottom sheet hiển thị YouGlish trực tiếp từ Word List row
// Mở nhanh, không cần navigate sang màn hình riêng
//
// PRON-001 (ADR-0015 D5): sheet này KHÔNG còn tự dựng WebViewController và
// KHÔNG còn copy `_buildUrl()` — phần WebView + URL đã về `youglish_view.dart`.
// Hai thay đổi có chủ đích, được ghi trong card PRON-001:
//   • ngôn ngữ/accent khởi tạo từ `YouGlishPrefs` (trước: luôn English-US,
//     mỗi điểm vào nhớ riêng);
//   • danh sách ngôn ngữ bỏ cắt `.take(5)` → đủ `YouGlishLanguage.values`,
//     accent đủ 7 mục (trước: hiện 5 ngôn ngữ, 3 accent).
// Giao diện, kích thước DraggableScrollableSheet, header và màu giữ nguyên.

import 'package:flutter/services.dart';
import 'package:in4up/core/language/localized_material.dart';

import '../youglish/youglish_config.dart';
import '../youglish/youglish_prefs.dart';
import '../youglish/youglish_view.dart';

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
                      onPressed: () => setState(() => _reloadToken++),
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
