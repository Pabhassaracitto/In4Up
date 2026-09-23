import 'package:in4up/core/language/localized_material.dart';
import 'package:provider/provider.dart';

import '../../../models/learning_activity.dart';
import '../../../providers/focus_provider.dart';

/// HOME-STREAK-001 — thẻ "Nhịp điệu học tập".
///
/// Hiển thị số liệu THẬT lấy từ [FocusProvider] (nguồn: LearningActivityService):
/// - số liệu hôm nay theo từng loại hoạt động (phút đọc, tài liệu, từ đã lưu,
///   lượt ôn LHB, lượt shadowing, câu đã dịch),
/// - số ngày học liên tiếp (streak),
/// - biểu đồ 7 ngày gần nhất (nhãn là số ngày trong tháng — không cần dịch).
///
/// Không hardcode số liệu và không ghi event trong build(): mọi sự kiện được
/// ghi tại nơi hành động thật xảy ra, xem lib/services/learning_activity_service.dart.
class FocusStreakCard extends StatelessWidget {
  const FocusStreakCard({super.key});

  @override
  Widget build(BuildContext context) {
    final focus = context.watch<FocusProvider>();
    final snapshot = focus.snapshot();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StreakHeader(streak: snapshot.streak),
          const SizedBox(height: 16),
          if (snapshot.activeToday)
            _TodayMetrics(activity: snapshot.today)
          else
            const _EmptyTodayHint(),
          const SizedBox(height: 18),
          _WeekChart(snapshot: snapshot),
        ],
      ),
    );
  }
}

class _StreakHeader extends StatelessWidget {
  const _StreakHeader({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_fire_department,
              color: Color(0xFFFF6B35), size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NHỊP ĐIỆU HỌC TẬP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                context.uiText('$streak ngày liên tiếp'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Số liệu hôm nay — chỉ hiện loại đã có hoạt động (không bày số 0 vô nghĩa).
class _TodayMetrics extends StatelessWidget {
  const _TodayMetrics({required this.activity});

  final LearningDayActivity activity;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final kind in LearningActivityKind.values) {
      final value = activity.countOf(kind);
      if (value <= 0) continue;
      chips.add(
        _MetricChip(
          icon: _iconFor(kind),
          label: _labelFor(context, kind, value),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  static IconData _iconFor(LearningActivityKind kind) {
    switch (kind) {
      case LearningActivityKind.readingMinutes:
        return Icons.timer_outlined;
      case LearningActivityKind.readDocument:
        return Icons.menu_book_outlined;
      case LearningActivityKind.vocabulary:
        return Icons.bookmark_added_outlined;
      case LearningActivityKind.learnByHeart:
        return Icons.psychology_outlined;
      case LearningActivityKind.shadowing:
        return Icons.mic_none_outlined;
      case LearningActivityKind.translation:
        return Icons.translate_outlined;
    }
  }

  /// Nhãn chrome — giữ nguyên dạng nguồn tiếng Việt để `uiText` khớp catalog
  /// (rule #5: locale ≠ vi thì ra English, xem tool/legacy_ui_english_overrides.json).
  static String _labelFor(
    BuildContext context,
    LearningActivityKind kind,
    int value,
  ) {
    switch (kind) {
      case LearningActivityKind.readingMinutes:
        return context.uiText('$value phút đọc');
      case LearningActivityKind.readDocument:
        return context.uiText('$value tài liệu');
      case LearningActivityKind.vocabulary:
        return context.uiText('$value từ');
      case LearningActivityKind.learnByHeart:
        return context.uiText('$value lượt ôn');
      case LearningActivityKind.shadowing:
        return context.uiText('$value lượt shadowing');
      case LearningActivityKind.translation:
        return context.uiText('$value câu đã dịch');
    }
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF00D1FF)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTodayHint extends StatelessWidget {
  const _EmptyTodayHint();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hôm nay chưa có hoạt động học',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Đọc tài liệu hoặc lưu một từ để bắt đầu',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

/// Biểu đồ cột 7 ngày — chiều cao theo tổng hoạt động thật của từng ngày.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.snapshot});

  final LearningStreakSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final days = snapshot.recentDays;
    final maxTotal = snapshot.maxDayTotal;
    final todayKey = snapshot.today.dayKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '7 ngày qua',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              context.uiText('${snapshot.activeDaysInWindow}/7 ngày có học'),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in days)
                Expanded(
                  child: _DayBar(
                    heightFactor: _heightFactor(day, maxTotal),
                    isToday: day.dayKey == todayKey,
                    isActive: day.isActive,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final day in days)
              Expanded(
                child: Text(
                  '${day.dayOfMonth}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: day.dayKey == todayKey
                        ? const Color(0xFFFF6B35)
                        : Colors.grey,
                    fontWeight: day.dayKey == todayKey
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Ngày không học vẫn giữ một vạch mờ để cột không biến mất khỏi biểu đồ.
  static double _heightFactor(LearningDayActivity day, int maxTotal) {
    if (maxTotal <= 0) return 0.08;
    final ratio = day.totalEvents / maxTotal;
    return ratio.clamp(0.08, 1.0);
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.heightFactor,
    required this.isToday,
    required this.isActive,
  });

  final double heightFactor;
  final bool isToday;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isToday
        ? const Color(0xFFFF6B35)
        : Colors.white.withValues(alpha: isActive ? 0.35 : 0.10);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: heightFactor,
          widthFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
