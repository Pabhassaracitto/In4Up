// lib/features/learn_by_heart/screens/chunking_flow_screen.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/chunking_flow_controller.dart';
import '../controllers/learn_by_heart_provider.dart';
import '../models/fsrs_models.dart';
import '../models/learn_by_heart_item.dart';
import '../models/line_timestamp.dart';
import '../services/cloze_generator.dart';
import '../services/multilingual_audio_service.dart';
import '../widgets/audio_control_bar.dart';
import '../widgets/bilingual_verse_view.dart';
import '../widgets/cloze_interactive_text.dart';
import '../widgets/fsrs_rating_bar.dart';

class ChunkingFlowScreen extends StatefulWidget {
  final LearnByHeartItem item;

  const ChunkingFlowScreen({super.key, required this.item});

  @override
  State<ChunkingFlowScreen> createState() => _ChunkingFlowScreenState();
}

class _ChunkingFlowScreenState extends State<ChunkingFlowScreen> {
  late final ChunkingFlowController _flowController;
  late final MultilingualAudioService _audioService;

  @override
  void initState() {
    super.initState();
    _flowController = ChunkingFlowController(widget.item);
    _audioService = MultilingualAudioService();
  }

  @override
  void dispose() {
    _audioService.stop();
    _audioService.dispose();
    _flowController.dispose();
    super.dispose();
  }

  void _handlePlayChunk(List<int> lineRange) {
    final filteredTimestamps = widget.item.lineTimestamps.where((t) => lineRange.contains(t.line)).toList();
    final partialItem = widget.item.copyWith(lineTimestamps: filteredTimestamps);
    _audioService.playFullItem(partialItem);
  }

  Future<void> _handleFinalRating(FSRSRating rating) async {
    final provider = context.read<LearnByHeartProvider>();
    await provider.submitReview(item: widget.item, rating: rating);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flowController, _audioService]),
      builder: (context, _) {
        final step = _flowController.currentStep;
        final stepIndex = _flowController.currentStepIndex;
        final totalSteps = _flowController.totalSteps;
        final isLastStep = stepIndex == totalSteps - 1;

        return Scaffold(
          backgroundColor: const Color(0xFF080B1A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            title: Column(
              children: [
                const Text(
                  'Học cuốn chiếu (Chunking Flow)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Bước ${stepIndex + 1}/$totalSteps: ${step.title}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Step Progress Bar
                LinearProgressIndicator(
                  value: (stepIndex + 1) / totalSteps,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                  minHeight: 4,
                ),

                // Step Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Step Header Card
                        _buildStepHeaderCard(step),
                        const SizedBox(height: 16),

                        // Main Step Scaffolding UI
                        if (step.type == ChunkStepType.studySingle || step.type == ChunkStepType.mergeReview)
                          _buildStudyStep(step)
                        else if (step.type == ChunkStepType.clozeSingle)
                          _buildClozeStep(step)
                        else if (step.type == ChunkStepType.fullRecall)
                          _buildFullRecallStep(),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Bar
                if (!isLastStep)
                  _buildBottomNavigation(stepIndex)
                else
                  FSRSRatingBar(
                    item: widget.item,
                    onRated: _handleFinalRating,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepHeaderCard(ChunkFlowStep step) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step.type == ChunkStepType.clozeSingle
                  ? Icons.quiz_rounded
                  : step.type == ChunkStepType.mergeReview
                      ? Icons.merge_type_rounded
                      : Icons.headphones_rounded,
              color: const Color(0xFFB388FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  step.description,
                  style: TextStyle(color: Colors.grey[400], fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyStep(ChunkFlowStep step) {
    final relevantTimestamps = widget.item.lineTimestamps.where((t) => step.lineRange.contains(t.line)).toList();

    return Column(
      children: [
        AudioControlBar(
          audioService: _audioService,
          item: widget.item,
          onPlayPause: () {
            if (_audioService.isPlaying) {
              _audioService.stop();
            } else {
              _handlePlayChunk(step.lineRange);
            }
          },
        ),
        const SizedBox(height: 16),
        BilingualVerseView(
          lineTimestamps: relevantTimestamps,
          activeLine: _audioService.currentLineIndex,
          languageMode: _audioService.langMode,
        ),
      ],
    );
  }

  Widget _buildClozeStep(ChunkFlowStep step) {
    final lines = widget.item.memorizeLines;
    final chunkText = step.lineRange
        .where((l) => l - 1 < lines.length)
        .map((l) => lines[l - 1])
        .join('\n');

    final tokens = ClozeGenerator.generate(
      text: chunkText,
      keywords: widget.item.keywords,
      maskRatio: 0.5,
    );

    return Column(
      children: [
        ClozeInteractiveText(
          tokens: tokens,
          fontSize: 17,
        ),
      ],
    );
  }

  Widget _buildFullRecallStep() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, size: 54, color: Color(0xFFFFD54F)),
          const SizedBox(height: 12),
          const Text(
            'Chúc mừng bạn đã hoàn tất ghép bài!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy đọc nhẩm toàn bộ bài một lần cuối và chọn mức độ nhớ để FSRS tự động lên lịch nhắc ôn.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 16),
          BilingualVerseView(
            lineTimestamps: widget.item.lineTimestamps,
            activeLine: _audioService.currentLineIndex,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(int stepIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1322),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          if (stepIndex > 0)
            TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                _audioService.stop();
                _flowController.previousStep();
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Quay lại'),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
            ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _audioService.stop();
              _flowController.nextStep();
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Tiếp theo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C63FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}
