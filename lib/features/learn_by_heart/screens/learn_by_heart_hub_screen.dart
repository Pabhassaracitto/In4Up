// lib/features/learn_by_heart/screens/learn_by_heart_hub_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/learn_by_heart_provider.dart';
import '../i18n/learn_by_heart_l10n.dart';
import '../models/learn_by_heart_item.dart';
import '../models/recitation_category.dart';
import '../models/review_state.dart';
import 'active_recall_screen.dart';
import 'assessment_screen.dart';
import 'chunking_flow_screen.dart';
import 'item_editor_dialog.dart';
import 'new_learning_screen.dart';

class LearnByHeartHubScreen extends StatefulWidget {
  const LearnByHeartHubScreen({super.key});

  @override
  State<LearnByHeartHubScreen> createState() => _LearnByHeartHubScreenState();
}

class _LearnByHeartHubScreenState extends State<LearnByHeartHubScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LearnByHeartProvider>().loadData();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openItemEditor([LearnByHeartItem? item]) async {
    final result = await showDialog<LearnByHeartItem>(
      context: context,
      builder: (_) => ItemEditorDialog(initialItem: item),
    );
    if (result != null && mounted) {
      context.read<LearnByHeartProvider>().saveItem(result);
    }
  }

  void _startDailyReviewSession(LearnByHeartProvider provider) {
    final due = provider.dueItems;
    if (due.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tuyệt vời! Bạn đã hoàn thành toàn bộ bài ôn tập hôm nay.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveRecallScreen(item: due.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = LearnByHeartL10n.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF080B1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_rounded, color: Color(0xFF4CAF50), size: 22),
            const SizedBox(width: 8),
            Text(
              l10n.moduleTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4CAF50)),
            tooltip: 'Thêm bài kinh mới',
            onPressed: () => _openItemEditor(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            color: const Color(0xFF1E293B),
            onSelected: (val) {
              if (val == 'reset') {
                _confirmResetDefaults();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, size: 18, color: Colors.orangeAccent),
                    SizedBox(width: 8),
                    Text('Khôi phục mẫu gốc', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<LearnByHeartProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            );
          }

          final filteredItems = provider.filteredItems;

          return RefreshIndicator(
            onRefresh: provider.loadData,
            color: const Color(0xFF4CAF50),
            backgroundColor: const Color(0xFF1E293B),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. Top Dashboard Stats & Quick SRS Action
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _buildHeroStatsCard(provider, l10n),
                  ),
                ),

                // 2. Search & Category Filter Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSearchBar(provider, l10n),
                        const SizedBox(height: 12),
                        _buildCategoryChips(provider, l10n),
                        const SizedBox(height: 8),
                        _buildStateFilterChips(provider, l10n),
                      ],
                    ),
                  ),
                ),

                // 3. Items List
                if (filteredItems.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = filteredItems[index];
                          return _buildItemCard(item, provider);
                        },
                        childCount: filteredItems.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openItemEditor(),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm bài mới', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeroStatsCard(LearnByHeartProvider provider, LearnByHeartL10n l10n) {
    final dueCount = provider.dueCount;
    final streak = provider.streak;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3A8A).withValues(alpha: 0.6),
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFB74D), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      l10n.streakText(streak),
                      style: const TextStyle(
                        color: Color(0xFFFFE082),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _MiniStatPill(
                label: l10n.mastered,
                value: '${provider.masteredCount}',
                color: const Color(0xFF81C784),
              ),
              const SizedBox(width: 6),
              _MiniStatPill(
                label: l10n.totalCount,
                value: '${provider.totalCount}',
                color: const Color(0xFF90CAF9),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dueCount > 0 ? '$dueCount ${l10n.dueToday}' : l10n.allDoneToday,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dueCount > 0
                          ? 'Dựa trên thuật toán FSRS & chu kỳ quên tự nhiên.'
                          : 'Bạn đang duy trì thói quen ghi nhớ rất tốt!',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _startDailyReviewSession(provider),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(dueCount > 0 ? l10n.reviewNow : l10n.practice),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(LearnByHeartProvider provider, LearnByHeartL10n l10n) {
    return TextField(
      controller: _searchCtrl,
      onChanged: provider.setSearchQuery,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: l10n.searchHint,
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 20),
        suffixIcon: _searchCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  provider.setSearchQuery('');
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4CAF50)),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(LearnByHeartProvider provider, LearnByHeartL10n l10n) {
    final selectedCat = provider.selectedCategory;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(l10n.allCategories),
            selected: selectedCat == null,
            selectedColor: const Color(0xFF4CAF50).withValues(alpha: 0.25),
            backgroundColor: const Color(0xFF1E293B),
            labelStyle: TextStyle(
              color: selectedCat == null ? const Color(0xFF81C784) : Colors.white70,
              fontSize: 11,
              fontWeight: selectedCat == null ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (_) => provider.setCategory(null),
          ),
          ...RecitationCategory.values.map((cat) {
            final isSel = selectedCat == cat;
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                label: Text(cat.displayName),
                selected: isSel,
                selectedColor: cat.color.withValues(alpha: 0.25),
                backgroundColor: const Color(0xFF1E293B),
                labelStyle: TextStyle(
                  color: isSel ? cat.color : Colors.white70,
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => provider.setCategory(cat),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStateFilterChips(LearnByHeartProvider provider, LearnByHeartL10n l10n) {
    final selectedState = provider.selectedStateFilter;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: Text(l10n.allStates),
            selected: selectedState == null,
            selectedColor: Colors.white.withValues(alpha: 0.15),
            backgroundColor: Colors.transparent,
            labelStyle: TextStyle(
              color: selectedState == null ? Colors.white : Colors.grey[400],
              fontSize: 10.5,
              fontWeight: selectedState == null ? FontWeight.bold : FontWeight.normal,
            ),
            onSelected: (_) => provider.setStateFilter(null),
          ),
          ...ReviewState.values.map((st) {
            final isSel = selectedState == st;
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: FilterChip(
                label: Text(st.displayName),
                selected: isSel,
                selectedColor: st.color.withValues(alpha: 0.2),
                backgroundColor: Colors.transparent,
                labelStyle: TextStyle(
                  color: isSel ? st.color : Colors.grey[400],
                  fontSize: 10.5,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => provider.setStateFilter(st),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildItemCard(LearnByHeartItem item, LearnByHeartProvider provider) {
    final isDue = item.isDue;
    final state = item.reviewState;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDue ? const Color(0xFF4CAF50).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewLearningScreen(item: item),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Category & Status Badge & Actions
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.category.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: item.category.color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      item.category.displayName,
                      style: TextStyle(
                        color: item.category.color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: state.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      state.displayName,
                      style: TextStyle(
                        color: state.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (item.isReadyForAssessment) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_rounded, size: 12, color: Color(0xFFFFD54F)),
                          SizedBox(width: 3),
                          Text(
                            'Sẵn sàng test',
                            style: TextStyle(color: Color(0xFFFFD54F), fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz_rounded, color: Colors.white54, size: 20),
                    color: const Color(0xFF1E293B),
                    onSelected: (act) {
                      switch (act) {
                        case 'review':
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveRecallScreen(item: item)));
                          break;
                        case 'chunk':
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChunkingFlowScreen(item: item)));
                          break;
                        case 'assessment':
                          Navigator.push(context, MaterialPageRoute(builder: (_) => AssessmentScreen(item: item)));
                          break;
                        case 'edit':
                          _openItemEditor(item);
                          break;
                        case 'delete':
                          _confirmDeleteItem(item.id, provider);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'review',
                        child: Text('Ôn Active Recall', style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem(
                        value: 'chunk',
                        child: Text('Học cuốn chiếu', style: TextStyle(color: Colors.white)),
                      ),
                      if (item.isReadyForAssessment)
                        const PopupMenuItem(
                          value: 'assessment',
                          child: Text('Kiểm tra thực chất', style: TextStyle(color: Color(0xFFFFD54F))),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Chỉnh sửa', style: TextStyle(color: Colors.white)),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Xóa bài', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title & Subtitle
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (item.subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),

              // Snippet Preview
              if (item.vietnameseText.isNotEmpty)
                Text(
                  item.vietnameseLines.take(2).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              const SizedBox(height: 10),

              // Bottom Metadata Row: Chunks count, Reps & Due info
              Row(
                children: [
                  Icon(Icons.layers_rounded, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    '${item.chunkList.length} đoạn',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.repeat_rounded, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Đã ôn ${item.totalReviews} lần',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                  const Spacer(),
                  if (isDue)
                    const Text(
                      'Đến hạn ôn',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF81C784),
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else if (item.nextReviewDate != null)
                    Text(
                      'Ôn sau ${_formatDaysUntil(item.nextReviewDate!)}',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey[400]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_rounded, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'Không tìm thấy bài học phù hợp',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Thử thay đổi bộ lọc hoặc thêm bài mới vào danh sách',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _formatDaysUntil(DateTime nextDate) {
    final diff = nextDate.difference(DateTime.now()).inDays;
    if (diff <= 0) return 'hôm nay';
    return '$diff ngày';
  }

  void _confirmDeleteItem(String id, LearnByHeartProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn có chắc muốn xóa bài học này không? Tiến trình ôn tập sẽ bị mất.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteItem(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _confirmResetDefaults() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Khôi phục dữ liệu mẫu', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Hành động này sẽ nạp lại toàn bộ 10 Kệ Pháp Cú và các bài kinh tụng chuẩn mẫu ban đầu. Bạn có muốn tiếp tục không?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<LearnByHeartProvider>().resetToDefaults();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
