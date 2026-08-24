// lib/features/learn_by_heart/screens/active_recall_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/learn_by_heart_provider.dart';
import '../i18n/learn_by_heart_l10n.dart';
import '../models/fsrs_models.dart';
import '../models/learn_by_heart_item.dart';
import '../services/cloze_generator.dart';
import '../services/multilingual_audio_service.dart';
import '../widgets/chain_recitation_view.dart';
import '../widgets/cloze_interactive_text.dart';
import '../widgets/fsrs_rating_bar.dart';
import '../widgets/voice_recitation_sheet.dart';
import 'assessment_screen.dart';

enum RecallModeType {
  cloze, // Dạng 1: Điền khuyết (Cloze Deletion 4 tầng)
  firstLetterChain, // Dạng 2: Nối xích câu kệ liên hoàn
  meaningToVerse, // Dạng 3: Ý nghĩa → Tự gợi nhớ câu kinh
  audioToVerse, // Dạng 4: Nghe nửa đầu → Tự đọc nửa sau
}

class ActiveRecallScreen extends StatefulWidget {
  final LearnByHeartItem item;

  const ActiveRecallScreen({super.key, required this.item});

  @override
  State<ActiveRecallScreen> createState() => _ActiveRecallScreenState();
}

class _ActiveRecallScreenState extends State<ActiveRecallScreen> {
  late final MultilingualAudioService _audioService;
  RecallModeType _currentMode = RecallModeType.cloze;
  bool _isAnswerRevealed = false;
  late List<ClozeToken> _tokens;
  ClozeLevel _activeClozeLevel = ClozeLevel.firstLetter;

  @override
  void initState() {
    super.initState();
    _audioService = MultilingualAudioService();
    _initTokens();
  }

  void _initTokens() {
    _tokens = ClozeGenerator.generate(
      text: widget.item.vietnameseText,
      keywords: widget.item.keywords,
      maskRatio: 0.4,
    );
  }

  @override
  void dispose() {
    _audioService.stop();
    _audioService.dispose();
    super.dispose();
  }

  void _switchMode(RecallModeType mode) {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMode = mode;
      _isAnswerRevealed = false;
      _audioService.stop();
    });
  }

  Future<void> _playFirstHalfAudio() async {
    final viLines = widget.item.vietnameseLines;
    final halfCount = (viLines.length / 2).ceil();
    final halfLines = viLines.take(halfCount).toList();

    await _audioService.playFullItem(
      widget.item.copyWith(
        vietnameseText: halfLines.join('\n'),
        paliText: widget.item.paliLines.take(halfCount).join('\n'),
      ),
    );
  }

  void _openVoiceRecitation() {
    VoiceRecitationSheet.show(
      context,
      item: widget.item,
      onRated: _handleReviewRating,
    );
  }

  Future<void> _handleReviewRating(FSRSRating rating) async {
    final provider = context.read<LearnByHeartProvider>();
    await provider.submitReview(item: widget.item, rating: rating);

    if (!mounted) return;

    if (widget.item.consecutiveSuccesses + 1 >= 5 && rating != FSRSRating.again) {
      _showAssessmentPrompt();
    } else {
      Navigator.pop(context);
    }
  }

  void _showAssessmentPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD54F), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Thử thách Thuộc Lòng!',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Bạn đã đạt 5 lần ôn tập thành công liên tiếp! Bạn có muốn làm bài Kiểm Tra Thực Chất (Assessment không gợi ý) để nhân đôi độ bền vững không?',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Để sau', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AssessmentScreen(item: widget.item),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Kiểm tra ngay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final l10n = LearnByHeartL10n.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Voice Recall Button
          IconButton(
            icon: const Icon(Icons.mic_rounded, color: Color(0xFF6C63FF)),
            tooltip: l10n.voiceRecallTitle,
            onPressed: _openVoiceRecitation,
          ),
          if (item.isReadyForAssessment)
            IconButton(
              icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFD54F)),
              tooltip: l10n.assessmentTitle,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AssessmentScreen(item: item)),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Selector Bar (Cloze / Nối xích / Ý nghĩa / Audio)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: const Color(0xFF0F172A),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ModeChip(
                      label: l10n.modeCloze,
                      icon: Icons.edit_note_rounded,
                      isSelected: _currentMode == RecallModeType.cloze,
                      onTap: () => _switchMode(RecallModeType.cloze),
                    ),
                    const SizedBox(width: 6),
                    _ModeChip(
                      label: l10n.chainModeTitle.split('(').first.trim(),
                      icon: Icons.link_rounded,
                      isSelected: _currentMode == RecallModeType.firstLetterChain,
                      onTap: () => _switchMode(RecallModeType.firstLetterChain),
                    ),
                    const SizedBox(width: 6),
                    _ModeChip(
                      label: l10n.modeMeaning,
                      icon: Icons.lightbulb_outline_rounded,
                      isSelected: _currentMode == RecallModeType.meaningToVerse,
                      onTap: () => _switchMode(RecallModeType.meaningToVerse),
                    ),
                    const SizedBox(width: 6),
                    _ModeChip(
                      label: l10n.modeAudio,
                      icon: Icons.record_voice_over_rounded,
                      isSelected: _currentMode == RecallModeType.audioToVerse,
                      onTap: () => _switchMode(RecallModeType.audioToVerse),
                    ),
                  ],
                ),
              ),
            ),

            // Main Active Recall Content Area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentMode == RecallModeType.cloze) _buildClozeSection(),
                    if (_currentMode == RecallModeType.firstLetterChain)
                      ChainRecitationView(
                        item: widget.item,
                        onCompleted: () => debugPrint('Chain completed'),
                        onRated: _handleReviewRating,
                      ),
                    if (_currentMode == RecallModeType.meaningToVerse) _buildMeaningSection(l10n),
                    if (_currentMode == RecallModeType.audioToVerse) _buildAudioSection(l10n),
                  ],
                ),
              ),
            ),

            // Bottom SRS Rating Bar
            FSRSRatingBar(
              item: item,
              onRated: _handleReviewRating,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClozeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.item.subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              widget.item.subtitle,
              style: TextStyle(color: Colors.grey[400], fontSize: 13, fontStyle: FontStyle.italic),
            ),
          ),
        ClozeInteractiveText(
          tokens: _tokens,
          initialLevel: _activeClozeLevel,
          onLevelChanged: (level) {
            setState(() => _activeClozeLevel = level);
          },
          fontSize: 17.5,
        ),
      ],
    );
  }

  Widget _buildMeaningSection(LearnByHeartL10n l10n) {
    final item = widget.item;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1E1B4B), const Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: Color(0xFFFFD54F), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n.coreMeaning,
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.shortMeaning.isNotEmpty ? item.shortMeaning : 'Hành động và tâm ý tạo tác quả báo.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (item.lifeConnection.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${l10n.lifeConnection}: ${item.lifeConnection}',
                  style: TextStyle(color: Colors.grey[300], fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            l10n.reciteInHeadPrompt,
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 14),
        if (!_isAnswerRevealed)
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() => _isAnswerRevealed = true);
              },
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('Xem đáp án để đối chiếu'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          )
        else
          _buildFullVerseBox(),
      ],
    );
  }

  Widget _buildAudioSection(LearnByHeartL10n l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              const Icon(Icons.headphones_rounded, size: 40, color: Color(0xFF6C63FF)),
              const SizedBox(height: 10),
              Text(
                l10n.modeAudio,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Lắng nghe câu mở đầu, sau đó tự đọc trọn vẹn phần còn lại',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _playFirstHalfAudio,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Phát nửa câu đầu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!_isAnswerRevealed)
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() => _isAnswerRevealed = true);
              },
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text('Hiện phần còn lại để kiểm tra'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          )
        else
          _buildFullVerseBox(),
      ],
    );
  }

  Widget _buildFullVerseBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 16),
              SizedBox(width: 6),
              Text(
                'TOÀN VĂN ĐỐI CHIẾU',
                style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (widget.item.paliText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              widget.item.paliText,
              style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            widget.item.vietnameseText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6C63FF).withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF6C63FF) : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFFB388FF) : Colors.grey[400],
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
