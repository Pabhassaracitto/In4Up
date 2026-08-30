// lib/features/learn_by_heart/screens/new_learning_screen.dart

import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';
import '../controllers/learn_by_heart_provider.dart';
import '../models/chunk.dart';
import '../models/learn_by_heart_item.dart';
import '../models/line_timestamp.dart';
import '../services/multilingual_audio_service.dart';
import '../widgets/audio_control_bar.dart';
import '../widgets/bilingual_verse_view.dart';
import '../widgets/elaborative_card.dart';
import 'active_recall_screen.dart';
import 'assessment_screen.dart';
import 'chunking_flow_screen.dart';

class NewLearningScreen extends StatefulWidget {
  final LearnByHeartItem item;

  const NewLearningScreen({super.key, required this.item});

  @override
  State<NewLearningScreen> createState() => _NewLearningScreenState();
}

class _NewLearningScreenState extends State<NewLearningScreen> {
  late final MultilingualAudioService _audioService;
  Chunk? _selectedChunk;

  @override
  void initState() {
    super.initState();
    _audioService = MultilingualAudioService();
    // Đánh dấu bắt đầu học
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LearnByHeartProvider>().startLearning(widget.item);
    });
  }

  @override
  void dispose() {
    _audioService.stop();
    _audioService.dispose();
    super.dispose();
  }

  void _handlePlayPause() {
    if (_audioService.isPlaying) {
      _audioService.stop();
    } else {
      if (_selectedChunk != null) {
        _audioService.playChunk(widget.item, _selectedChunk!);
      } else {
        _audioService.playFullItem(widget.item);
      }
    }
  }

  void _selectChunk(Chunk? chunk) {
    setState(() {
      _selectedChunk = chunk;
    });
    if (chunk != null) {
      _audioService.playChunk(widget.item, chunk);
    } else {
      _audioService.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              item.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: item.isFavorite ? Colors.redAccent : Colors.white70,
            ),
            onPressed: () => context.read<LearnByHeartProvider>().toggleFavorite(item.id),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Elaborative Content Hook Card
                    ElaborativeCard(
                      shortMeaning: item.shortMeaning,
                      keywords: item.keywords,
                      lifeConnection: item.lifeConnection,
                    ),
                    const SizedBox(height: 14),

                    // Chunk selector tabs (if available)
                    if (item.chunkList.isNotEmpty) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Toàn bài'),
                              selected: _selectedChunk == null,
                              selectedColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              labelStyle: TextStyle(
                                color: _selectedChunk == null ? const Color(0xFFB388FF) : Colors.white70,
                                fontSize: 11,
                                fontWeight: _selectedChunk == null ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (_) => _selectChunk(null),
                            ),
                            ...item.chunkList.map((chunk) {
                              final isSelected = _selectedChunk?.index == chunk.index;
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: ChoiceChip(
                                  label: Text(chunk.label),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                                  labelStyle: TextStyle(
                                    color: isSelected ? const Color(0xFFB388FF) : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  onSelected: (_) => _selectChunk(chunk),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Dual Coding Karaoke Audio Player Controller
                    AudioControlBar(
                      audioService: _audioService,
                      onPlayPause: _handlePlayPause,
                    ),
                    const SizedBox(height: 16),

                    // Bilingual Line-by-Line Karaoke Verse Display
                    AnimatedBuilder(
                      animation: _audioService,
                      builder: (context, _) {
                        return BilingualVerseView(
                          lineTimestamps: item.lineTimestamps,
                          activeLine: _audioService.currentLineIndex,
                          languageMode: _audioService.langMode,
                          onLineTap: (lineTs) {
                            _audioService.playSingleLine(lineTs, item);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Learning Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1322),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: Row(
                children: [
                  // Chunking Flow button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _audioService.stop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChunkingFlowScreen(item: item),
                          ),
                        );
                      },
                      icon: const Icon(Icons.alt_route_rounded, size: 18),
                      label: const Text('Học cuốn chiếu'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB388FF),
                        side: const BorderSide(color: Color(0xFF6C63FF)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Active Recall button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _audioService.stop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActiveRecallScreen(item: item),
                          ),
                        );
                      },
                      icon: const Icon(Icons.psychology_rounded, size: 18),
                      label: const Text('Ôn Active Recall'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
