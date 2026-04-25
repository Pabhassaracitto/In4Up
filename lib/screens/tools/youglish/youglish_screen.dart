
// lib/screens/tools/youglish/youglish_screen.dart
//
// ★ UI: Compact toolbar 1 hàng — Search + Language dropdown + Accent dropdown
//   → WebView chiếm tối đa không gian, không cần kéo xuống

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'youglish_config.dart';
import 'youglish_widget.dart';

class YouGlishScreen extends StatefulWidget {
  const YouGlishScreen({Key? key}) : super(key: key);

  @override
  State<YouGlishScreen> createState() => _YouGlishScreenState();
}

class _YouGlishScreenState extends State<YouGlishScreen> {
  final TextEditingController _wordController = TextEditingController(text: 'hello');
  YouGlishLanguage _selectedLanguage = YouGlishLanguage.english;
  YouGlishAccent _selectedAccent = YouGlishAccent.us;
  String _currentWord = 'hello';

  void _search() {
    final word = _wordController.text.trim();
    if (word.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _currentWord = word);
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)],
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.record_voice_over, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('YouGlish',
                style: TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── TOOLBAR 1 HÀNG ─────────────────────────────────
          _buildToolbar(),

          // ── Quick words chips ───────────────────────────────
          _buildQuickChips(),

          // ── WebView: chiếm toàn bộ phần còn lại ────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: YouGlishWidget(
                key: ValueKey(
                    '$_currentWord-${_selectedLanguage.code}-${_selectedAccent.code}'),
                word: _currentWord,
                language: _selectedLanguage,
                accent: _selectedLanguage == YouGlishLanguage.english
                    ? _selectedAccent
                    : null,
                autoPlay: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Toolbar 1 hàng: [Search...] [🌐 Lang ▾] [🎤 Accent ▾] ──
  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          // Search field — chiếm phần lớn
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _wordController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Nhập từ...',
                  hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                  prefixIcon: const Icon(Icons.search,
                      color: Color(0xFF6C63FF), size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward,
                        color: Color(0xFF6C63FF), size: 18),
                    onPressed: _search,
                    padding: EdgeInsets.zero,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF080B1A),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Color(0xFF6C63FF).withValues(alpha: 0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Color(0xFF6C63FF).withValues(alpha: 0.25)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF6C63FF), width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Language dropdown
          _buildDropdown<YouGlishLanguage>(
            value: _selectedLanguage,
            icon: Icons.language,
            color: const Color(0xFF00BCD4),
            items: YouGlishLanguage.values,
            label: (l) => l.displayName,
            onChanged: (v) {
              if (v == null) return;
              HapticFeedback.selectionClick();
              setState(() => _selectedLanguage = v);
            },
          ),

          const SizedBox(width: 8),

          // Accent dropdown — chỉ hiện khi English
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selectedLanguage == YouGlishLanguage.english
                ? _buildDropdown<YouGlishAccent>(
                    key: const ValueKey('accent'),
                    value: _selectedAccent,
                    icon: Icons.mic,
                    color: const Color(0xFF4CAF50),
                    items: YouGlishAccent.values,
                    label: (a) => a.displayName.split(' ')[0],
                    onChanged: (v) {
                      if (v == null) return;
                      HapticFeedback.selectionClick();
                      setState(() => _selectedAccent = v);
                    },
                  )
                : const SizedBox(key: ValueKey('no-accent')),
          ),
        ],
      ),
    );
  }

  // Generic compact dropdown button
  Widget _buildDropdown<T>({
    Key? key,
    required T value,
    required IconData icon,
    required Color color,
    required List<T> items,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      key: key,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF1A1A2E),
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, color: color, size: 18),
          onChanged: onChanged,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    label(item),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Quick chips nhỏ gọn ──────────────────────────────────
  Widget _buildQuickChips() {
    final quickWords = [
      ('hello', YouGlishLanguage.english, YouGlishAccent.us),
      ('water', YouGlishLanguage.english, YouGlishAccent.uk),
      ('bonjour', YouGlishLanguage.french, null),
      ('hola', YouGlishLanguage.spanish, null),
    ];

    return Container(
      color: const Color(0xFF0F0F23),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: quickWords.map((data) {
            final isActive =
                _currentWord == data.$1 && _selectedLanguage == data.$2;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _currentWord = data.$1;
                    _selectedLanguage = data.$2;
                    if (data.$3 != null) _selectedAccent = data.$3!;
                    _wordController.text = data.$1;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Color(0xFF6C63FF).withValues(alpha: 0.25)
                        : const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF6C63FF)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    data.$1,
                    style: TextStyle(
                      color:
                          isActive ? const Color(0xFF9C8FFF) : Colors.grey[400],
                      fontSize: 12,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}