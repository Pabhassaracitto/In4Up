// lib/screens/memory_mode/memory_mode_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/vocabulary_provider.dart';
import '../tools/word_list/word_list_screen.dart';
import 'controllers/memory_controller.dart';
import 'memory_provider.dart';
import 'widgets/memory_garden_view.dart';
import 'widgets/memory_top_bar.dart';
import 'widgets/memory_bottom_bar.dart';
import 'widgets/flashcard_presenter.dart';
import 'widgets/memory_list_view.dart';

class MemoryModeScreen extends StatelessWidget {
  const MemoryModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dùng .value để lấy controller ĐÃ CÓ sẵn từ MemoryProvider
    return ChangeNotifierProvider.value(
      value: MemoryProvider.controller, // <--- CHÌA KHÓA LÀ ĐÂY
      child: Consumer<MemoryController>(
        builder: (context, controller, _) {
          // Loading
          if (!controller.isLoaded) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  SizedBox(height: 16),
                  Text(
                    'Đang tải vườn nhớ...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Đang ôn tập → Flashcard
          if (controller.isReviewing) {
            return const FlashcardPresenter();
          }

          // Chưa có từ nào
          if (controller.allItems.isEmpty) {
            return _buildEmptyState(context, controller);
          }

          // Giao diện chính
          return Column(
            children: [
              const MemoryTopBar(),
              Expanded(child: _buildContent(controller)),
              const MemoryBottomBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(MemoryController controller) {
    switch (controller.viewMode) {
      case MemoryViewMode.garden:
        return const MemoryGardenView();
      case MemoryViewMode.list:
        return const MemoryListView();
      case MemoryViewMode.flashcard:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.startReview();
        });
        return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildEmptyState(BuildContext context, MemoryController controller) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Color(0xFF4CAF50).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Color(0xFF4CAF50).withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: const Text('🌱', style: TextStyle(fontSize: 64)),
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'Vườn Trí Nhớ',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Lưu từ vựng từ tab Đọc\n'
              'để bắt đầu trồng vườn kiến thức',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Nút chuyển tới worklist để thêm nếu có từ ở worklist, ngược lại hiện nút thêm từ mẫu
            Consumer<VocabularyProvider>(
              builder: (context, vocabProvider, _) {
                final hasWordsInWorklist = vocabProvider.allWords.isNotEmpty;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WordListScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.format_list_bulleted, size: 18, color: Colors.white),
                      label: Text(
                        hasWordsInWorklist ? 'Mở Wordlist để gieo mầm' : 'Mở Wordlist để thêm từ mới',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        controller.addTestWords();
                        HapticFeedback.mediumImpact();
                      },
                      icon: const Icon(Icons.science, size: 18),
                      label: const Text('Thêm từ mẫu để thử'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[400],
                        side: BorderSide(
                          color: Colors.grey[700]!.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            // Guide
            const _GuideCard(
              emoji: '🌰',
              title: 'Hột giống',
              desc: 'Từ mới vừa lưu, cần tưới ngay',
              color: Color(0xFFFF5252),
            ),
            const SizedBox(height: 8),
            const _GuideCard(
              emoji: '🌱',
              title: 'Cây non → 🌺 Hoa',
              desc: 'Ôn tập đều để từ trưởng thành',
              color: Color(0xFF4CAF50),
            ),
            const SizedBox(height: 8),
            const _GuideCard(
              emoji: '🧠',
              title: 'Spaced Repetition',
              desc: 'Ôn đúng lúc sắp quên = nhớ lâu nhất',
              color: Color(0xFF2196F3),
            ),

            const SizedBox(height: 24),

            Text(
              '💡 Long-press từ trong tab Đọc để lưu',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  final Color color;

  const _GuideCard({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
