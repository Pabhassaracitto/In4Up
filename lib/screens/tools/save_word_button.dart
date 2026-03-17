// lib/screens/tools/venn_tab.dart
// ═══════════════════════════════════════════════════════════════
//  VIPSOUND INTEGRATION GUIDE
//  File: HOW_TO_INTEGRATE.md (dạng Dart comments)
// ═══════════════════════════════════════════════════════════════

///
/// # HƯỚNG DẪN TÍCH HỢP VÀO VIPSOUND
///
/// ## 1. CẤU TRÚC FILE CẦN TẠO
///
/// Thêm vào project VipSound (giả sử tên package là `vipsound`):
///
/// ```
/// lib/
/// ├── models/
/// │   ├── sm2_algorithm.dart       ← Copy từ mode3
/// │   └── word_entry.dart          ← Copy từ mode3
/// ├── providers/
/// │   └── vocabulary_provider.dart ← Copy từ mode3
/// ├── screens/
/// │   └── tools_screen.dart        ← File mới (đã tạo)
/// │   └── tools/
/// │       ├── stats_tab.dart       ← File mới (đã tạo)
/// │       ├── venn_tab.dart        ← File mới (đã tạo)
/// │       ├── triangle_tab.dart    ← File mới (đã tạo)
/// │       ├── map_tab.dart         ← File mới (đã tạo)
/// │       └── review_tab.dart      ← File mới (đã tạo)
/// └── widgets/
///     ├── skill_triangle.dart      ← Copy từ mode3
///     ├── word_bubble.dart         ← Copy từ mode3
///     └── word_detail_sheet.dart   ← Copy từ mode3
/// ```
///
/// ## 2. PUBSPEC.YAML - Thêm dependencies
///
/// ```yaml
/// dependencies:
///   provider: ^6.1.2
///   shared_preferences: ^2.2.2
///   uuid: ^4.2.1
/// ```
///
/// ## 3. MAIN.DART - Thêm VocabularyProvider
///
/// ```dart
/// // Wrap app với MultiProvider
/// void main() {
///   runApp(
///     MultiProvider(
///       providers: [
///         // ... các providers VipSound hiện có ...
///         ChangeNotifierProvider(
///           create: (_) => VocabularyProvider()..loadData(),
///         ),
///       ],
///       child: const VipSoundApp(),
///     ),
///   );
/// }
/// ```
///
/// ## 4. VIPSOUND MAIN SCREEN - Thêm tab Tools
///
/// ```dart
/// // Trong màn hình chính của VipSound, thêm tab thứ 4 (hoặc tab mới):
///
/// // Nếu dùng BottomNavigationBar:
/// BottomNavigationBar(
///   items: [
///     const BottomNavigationBarItem(icon: Icon(Icons.play_circle), label: 'Read'),
///     const BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Music'),
///     const BottomNavigationBarItem(icon: Icon(Icons.lightbulb), label: 'Meaning'),
///     BottomNavigationBarItem(          // ← THÊM TAB NÀY
///       icon: Icon(Icons.build_outlined),
///       activeIcon: Icon(Icons.build),
///       label: 'Tools',
///     ),
///   ],
/// )
///
/// // Trong IndexedStack:
/// IndexedStack(
///   index: _currentTab,
///   children: [
///     ReadScreen(),
///     MusicScreen(),
///     MeaningScreen(),
///     const ToolsScreen(),  // ← THÊM SCREEN NÀY
///   ],
/// )
/// ```
///
/// ## 5. ĐỒNG BỘ TỪ VỰNG - Kết nối với Read tab
///
/// Khi người dùng "lưu từ" trong Read tab, thêm từ vào VocabularyProvider:
///
/// ```dart
/// // Trong ReadScreen hoặc bất kỳ nơi nào lưu từ:
///
/// void _saveWord(String word, String meaning, {String? phonetic, String? example}) {
///   final vocabProvider = context.read<VocabularyProvider>();
///
///   // Kiểm tra xem từ đã tồn tại chưa
///   if (!vocabProvider.hasWord(word)) {
///     vocabProvider.addWord(WordEntry(
///       id: 'w_${DateTime.now().millisecondsSinceEpoch}',
///       word: word,
///       meaning: meaning,
///       phonetic: phonetic,
///       example: example,
///       // Khi mới lưu, tất cả scores = 0 (chưa học)
///     ));
///
///     // Show feedback
///     ScaffoldMessenger.of(context).showSnackBar(
///       SnackBar(
///         content: Text('Đã lưu "$word" vào Tools'),
///         action: SnackBarAction(
///           label: 'Xem',
///           onPressed: () => _navigateToTools(),
///         ),
///       ),
///     );
///   }
/// }
/// ```
///
/// ## 6. LONG PRESS MENU trong Read tab (ví dụ)
///
/// ```dart
/// // Khi người dùng long-press vào từ trong text:
/// void _onWordLongPress(String word) {
///   showModalBottomSheet(
///     context: context,
///     builder: (_) => Column(
///       mainAxisSize: MainAxisSize.min,
///       children: [
///         ListTile(
///           leading: const Icon(Icons.save_alt),
///           title: Text('Lưu "$word" vào Tools'),
///           onTap: () {
///             Navigator.pop(context);
///             _showSaveWordDialog(word);
///           },
///         ),
///         // ... other options
///       ],
///     ),
///   );
/// }
///
/// void _showSaveWordDialog(String word) {
///   final meaningCtrl = TextEditingController();
///   showDialog(
///     context: context,
///     builder: (_) => AlertDialog(
///       title: Text('Lưu từ: $word'),
///       content: TextField(
///         controller: meaningCtrl,
///         decoration: const InputDecoration(
///           labelText: 'Nghĩa (tiếng Việt)',
///           hintText: 'VD: ngôi nhà',
///         ),
///       ),
///       actions: [
///         TextButton(
///           onPressed: () => Navigator.pop(context),
///           child: const Text('Huỷ'),
///         ),
///         ElevatedButton(
///           onPressed: () {
///             Navigator.pop(context);
///             _saveWord(word, meaningCtrl.text);
///           },
///           child: const Text('Lưu'),
///         ),
///       ],
///     ),
///   );
/// }
/// ```
///
/// ## 7. IMPORT HÀNG LOẠT từ văn bản (Text Import)
///
/// Nếu muốn nhập nhiều từ từ một đoạn văn bản:
///
/// ```dart
/// // Sử dụng method có sẵn trong VocabularyProvider:
/// final vocabProvider = context.read<VocabularyProvider>();
///
/// // Phân tích và nhập tự động (không cần nhập nghĩa)
/// final newWords = vocabProvider.importFromText(textContent);
///
/// // Hoặc phân tích trước, sau đó cho người dùng chọn từ nào cần lưu:
/// final analysis = vocabProvider.analyzeText(textContent);
/// // analysis[word] = null nếu từ chưa có trong vocabulary
/// // analysis[word] = WordEntry nếu đã có
/// ```
///
/// ## 8. SYNC BADGE - Hiển thị số từ cần ôn tập
///
/// ```dart
/// // Trong BottomNavigationBar, hiển thị badge số từ cần ôn:
/// Consumer<VocabularyProvider>(
///   builder: (ctx, prov, _) => Badge.count(
///     count: prov.dueCount,
///     isLabelVisible: prov.dueCount > 0,
///     child: const Icon(Icons.build_outlined),
///   ),
/// )
/// ```
///

// ═══════════════════════════════════════════════════════════════
//  VIPSOUND WORD SAVER WIDGET
//  Widget tái sử dụng để lưu từ từ Read tab
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/word_entry.dart';
import '../../providers/vocabulary_provider.dart';

/// Widget button để lưu từ vào VocabularyProvider
/// Dùng trong Read tab: đặt vào Context Menu khi long-press từ
class SaveWordButton extends StatelessWidget {
  final String word;
  final String? meaning;
  final String? phonetic;
  final String? example;
  final VoidCallback? onSaved;

  const SaveWordButton({
    super.key,
    required this.word,
    this.meaning,
    this.phonetic,
    this.example,
    this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<VocabularyProvider>(
      builder: (context, prov, _) {
        final alreadySaved = prov.hasWord(word);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: alreadySaved
              ? _AlreadySavedChip(word: word, prov: prov)
              : _SaveButton(
                  word: word,
                  meaning: meaning,
                  phonetic: phonetic,
                  example: example,
                  prov: prov,
                  onSaved: onSaved,
                ),
        );
      },
    );
  }
}

class _SaveButton extends StatelessWidget {
  final String word;
  final String? meaning;
  final String? phonetic;
  final String? example;
  final VocabularyProvider prov;
  final VoidCallback? onSaved;

  const _SaveButton({
    required this.word,
    this.meaning,
    this.phonetic,
    this.example,
    required this.prov,
    this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      key: const ValueKey('save'),
      onPressed: () => _save(context),
      icon: const Icon(Icons.bookmark_add_outlined, size: 16),
      label: const Text('Lưu từ'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C63FF).withAlpha(25),
        foregroundColor: const Color(0xFF6C63FF),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _save(BuildContext context) {
    if (meaning != null && meaning!.isNotEmpty) {
      _doSave(context, meaning!);
    } else {
      // Show dialog để nhập nghĩa
      _showMeaningDialog(context);
    }
  }

  void _showMeaningDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bookmark_add, color: Color(0xFF6C63FF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lưu từ: "$word"',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nghĩa tiếng Việt',
            hintText: 'VD: ngôi nhà, đẹp đẽ...',
            prefixIcon: Icon(Icons.translate),
          ),
          onSubmitted: (v) {
            Navigator.pop(context);
            if (v.isNotEmpty) _doSave(context, v);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _doSave(context, ctrl.text.isEmpty ? '' : ctrl.text);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _doSave(BuildContext context, String meaningText) {
    prov.addWord(WordEntry(
      id: 'vs_${DateTime.now().millisecondsSinceEpoch}',
      word: word.toLowerCase().trim(),
      meaning: meaningText,
      phonetic: phonetic,
      example: example,
    ));

    onSaved?.call();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Đã lưu "$word" vào Tools')),
            ],
          ),
          backgroundColor: const Color(0xFF66BB6A),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Xem',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to Tools tab
              // Gọi callback hoặc dùng Navigator
            },
          ),
        ),
      );
    }
  }
}

class _AlreadySavedChip extends StatelessWidget {
  final String word;
  final VocabularyProvider prov;

  const _AlreadySavedChip({required this.word, required this.prov});

  @override
  Widget build(BuildContext context) {
    final entry = prov.findByWord(word);
    if (entry == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _QuickWordInfo(word: entry),
        );
      },
      child: Container(
        key: const ValueKey('saved'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: entry.zone.color.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: entry.zone.color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(entry.zone.icon, size: 14, color: entry.zone.color),
            const SizedBox(width: 4),
            Text(
              entry.zone.label,
              style: TextStyle(
                fontSize: 12,
                color: entry.zone.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${(entry.mastery * 100).toInt()}%',
              style: TextStyle(
                fontSize: 11,
                color: entry.zone.color.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini info sheet khi tap vào từ đã lưu
class _QuickWordInfo extends StatelessWidget {
  final WordEntry word;
  const _QuickWordInfo({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: word.zone.color,
                child: Icon(word.zone.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(word.word,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(word.meaning,
                      style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _skill('Hiểu', word.understand, const Color(0xFF42A5F5)),
              _skill('Nghe', word.listen, const Color(0xFF66BB6A)),
              _skill('Đọc', word.read, const Color(0xFFEF5350)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            word.zone.tip,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _skill(String label, double value, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            value: value,
            color: color,
            backgroundColor: color.withAlpha(40),
            strokeWidth: 5,
          ),
        ),
        const SizedBox(height: 4),
        Text('${(value * 100).toInt()}%',
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
