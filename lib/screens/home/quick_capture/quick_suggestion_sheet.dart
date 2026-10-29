// lib/screens/home/quick_capture/quick_suggestion_sheet.dart
//
// HOME-QUICK-001 — nút "Gợi ý" của card "Nạp tri thức nhanh".
//
// Luôn lấy MỘT ENTRY THẬT từ WordList (ưu tiên thẻ đến kỳ ôn SRS/FSRS):
// hiện word + IPA + nghĩa, nghe bằng TTS có sẵn, mở sheet tri thức hợp
// nhất, hoặc mở WordList. WordList rỗng → empty state CÓ HƯỚNG DẪN
// (không bịa từ/ảnh giả).

import 'dart:async';
import 'dart:math';

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../../features/tts/tts_service.dart';
import '../../../models/word_entry.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../../widgets/unified_knowledge_sheet.dart';
import '../../tools/word_list/word_list_screen.dart';
import 'quick_capture_sheet.dart';
import 'quick_capture_suggestion.dart';

class QuickSuggestionSheet extends StatefulWidget {
  const QuickSuggestionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const QuickSuggestionSheet(),
    );
  }

  @override
  State<QuickSuggestionSheet> createState() => _QuickSuggestionSheetState();
}

class _QuickSuggestionSheetState extends State<QuickSuggestionSheet> {
  static const Color _accent = Color(0xFF00D1FF);

  final Random _random = Random();
  final TtsService _tts = TtsService();

  QuickSuggestion? _suggestion;
  bool _speaking = false;

  @override
  void dispose() {
    unawaited(_stopSpeech());
    super.dispose();
  }

  void _repick(List<WordEntry> entries) {
    _suggestion = QuickSuggestionPicker.pick(entries: entries, random: _random);
  }

  Future<void> _stopSpeech() async {
    _speaking = false;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> _speak(QuickSuggestion suggestion) async {
    if (_speaking) {
      await _stopSpeech();
      if (mounted) setState(() {});
      return;
    }
    final language = suggestion.entry.language.trim();
    try {
      _tts.configure(language: language.isEmpty ? 'auto' : language);
      _speaking = true;
      if (mounted) setState(() {});
      await _tts.speak(suggestion.word);
    } catch (_) {
      // TTS không khả dụng (thiếu model Piper / engine máy) — im lặng bỏ qua,
      // word/IPA/nghĩa vẫn hiện đủ.
    } finally {
      _speaking = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VocabularyProvider>();
    // Chọn entry THẬT ngay khi WordList có dữ liệu — kể cả khi user vừa lưu
    // từ mới từ sheet "Ghi chú nói" rồi quay lại đây.
    if (_suggestion == null) {
      _repick(provider.allWords);
    }
    final suggestion = _suggestion;

    return FractionallySizedBox(
      heightFactor: 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildHeader(context),
            const SizedBox(height: 16),
            Expanded(
              child: suggestion == null
                  ? _buildEmptyState(context)
                  : _buildSuggestion(context, suggestion),
            ),
            const SizedBox(height: 12),
            _buildFooter(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.auto_awesome, color: _accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.uiText('GỢI Ý TỪ WORDLIST'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.uiText('Ưu tiên thẻ đến kỳ ôn'),
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          tooltip: context.uiText('Đóng'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSuggestion(BuildContext context, QuickSuggestion suggestion) {
    final entry = suggestion.entry;
    final topics = entry.topics.where((t) => t.trim().isNotEmpty).toList();
    final languages = entry.languages.where((l) => l.trim().isNotEmpty).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                suggestion.dueForReview
                    ? context.uiText('Đến kỳ ôn')
                    : context.uiText('Từ WordList'),
                suggestion.dueForReview
                    ? const Color(0xFFFFB74D)
                    : const Color(0xFF81C784),
              ),
              for (final lang in languages) _chip(lang.toUpperCase(), _accent),
              for (final topic in topics) _chip('#$topic', const Color(0xFFB39DDB)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            suggestion.word,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          if (suggestion.hasPhonetic) ...[
            const SizedBox(height: 6),
            Text(
              suggestion.phonetic,
              style: TextStyle(
                color: _accent,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              suggestion.hasMeaning
                  ? suggestion.meaning
                  : context.uiText(
                      'Chưa có nghĩa — bấm "Xem chi tiết" để bổ sung.',
                    ),
              style: TextStyle(
                color: suggestion.hasMeaning ? Colors.white : Colors.grey[500],
                fontSize: 14.5,
                height: 1.5,
              ),
            ),
          ),
          if ((entry.example ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              entry.example!.trim(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _speak(suggestion),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent.withValues(alpha: 0.16),
                  foregroundColor: _accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: _accent.withValues(alpha: 0.3)),
                  ),
                ),
                icon: Icon(_speaking ? Icons.stop : Icons.volume_up, size: 18),
                label: Text(
                  _speaking ? context.uiText('Dừng nghe') : context.uiText('Nghe'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      UnifiedKnowledgeSheet.show(context, word: entry),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(context.uiText('Xem chi tiết')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 44, color: Colors.grey[600]),
          const SizedBox(height: 14),
          Text(
            context.uiText('WordList đang trống'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.uiText(
              'Lưu từ đầu tiên bằng nút "Ghi chú nói", hoặc bôi chọn từ khi Đọc để Gợi ý có dữ liệu thật.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => QuickCaptureSheet.show(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF4848).withValues(alpha: 0.16),
              foregroundColor: const Color(0xFFFF4848),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: const Color(0xFFFF4848).withValues(alpha: 0.3),
                ),
              ),
            ),
            icon: const Icon(Icons.mic, size: 18),
            label: Text(context.uiText('Ghi chú nói')),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, VocabularyProvider provider) {
    final hasEntries = provider.allWords.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: hasEntries
                ? () => setState(() => _repick(provider.allWords))
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF).withValues(alpha: 0.18),
              foregroundColor: const Color(0xFF6C63FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.shuffle, size: 18),
            label: Text(context.uiText('Gợi ý khác')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WordListScreen()),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.list_alt, size: 18),
            label: Text(context.uiText('Mở WordList')),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
