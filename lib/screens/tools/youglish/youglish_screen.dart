// lib/screens/tools/youglish/youglish_screen.dart
//
// ★ FIX: Thay toàn bộ .withOpacity() → .withValues(alpha:)
// ★ FIX: Không dùng bất kỳ Provider nào → tránh "Provider not found"
//   khi mở từ Navigator.push bên ngoài Provider tree

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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00BCD4), Color(0xFF26C6DA)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.record_voice_over, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('YouGlish', style: TextStyle(fontSize: 16, color: Colors.white)),
                Text('Nghe phát âm chuẩn',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchBox(),
            const SizedBox(height: 16),
            _buildLanguageSelector(),
            const SizedBox(height: 16),
            if (_selectedLanguage == YouGlishLanguage.english) ...[
              _buildAccentSelector(),
            
            if (_selectedLanguage == YouGlishLanguage.english)
              const SizedBox(height: 24),
            ],
            // ★ KEY trick: dùng ValueKey để Flutter rebuild YouGlishWidget
            // khi word/language/accent thay đổi → didUpdateWidget được gọi đúng
            YouGlishWidget(
              key: ValueKey('$_currentWord-${_selectedLanguage.code}'
                  '-${_selectedAccent.code}'),
              word: _currentWord,
              language: _selectedLanguage,
              accent: _selectedLanguage == YouGlishLanguage.english 
                  ? _selectedAccent 
                  : null,
              height: 400,
              autoPlay: true,
            ),
            const SizedBox(height: 16),
            _buildQuickButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        controller: _wordController,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Nhập từ hoặc cụm từ...',
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6C63FF)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward, color: Color(0xFF6C63FF)),
            onPressed: () {
              HapticFeedback.lightImpact();
              final word = _wordController.text.trim();
              if (word.isNotEmpty) {
                setState(() => _currentWord = word);
              }
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        onSubmitted: (value) {
          final word = value.trim();
          if (word.isNotEmpty) {
            setState(() => _currentWord = word);
          }
        },
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.language, size: 16, color: Color(0xFF00BCD4)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Ngôn ngữ',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<YouGlishLanguage>(
            value: _selectedLanguage,
            dropdownColor: const Color(0xFF1A1A2E),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF080B1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: const Color(0xFF00BCD4).withValues(alpha: 0.3),
                ),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            items: YouGlishLanguage.values.map((lang) {
              return DropdownMenuItem(
                value: lang,
                child: Text(lang.displayName),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;
              HapticFeedback.selectionClick();
              setState(() => _selectedLanguage = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccentSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mic, size: 16, color: Color(0xFF4CAF50)),
              ),
              const SizedBox(width: 8),
              const Text(
                'Giọng (chỉ tiếng Anh)',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: YouGlishAccent.values.map((accent) {
              final isSelected = _selectedAccent == accent;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedAccent = accent);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected 
    ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
    : const Color(0xFF080B1A),
                          : const Color(0xFF080B1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF4CAF50)
                            : Colors.white.withValues(alpha: 0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      accent.displayName.split(' ')[0], // "American", "British", "Australian"
                      accent.displayName.split(' ')[0],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[400],
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickButtons() {
    final quickWords = [
      ('hello', YouGlishLanguage.english, YouGlishAccent.us),
      ('water', YouGlishLanguage.english, YouGlishAccent.uk),
      ('bonjour', YouGlishLanguage.french, null),
      ('hola', YouGlishLanguage.spanish, null),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quickWords.map((data) {
        return ElevatedButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() {
              _currentWord = data.$1;
              _selectedLanguage = data.$2;
              if (data.$3 != null) _selectedAccent = data.$3!;
              _wordController.text = data.$1;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A2E),
            foregroundColor: const Color(0xFF6C63FF),
            side: BorderSide(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(data.$1),
        );
      }).toList(),
    );
  }
}
