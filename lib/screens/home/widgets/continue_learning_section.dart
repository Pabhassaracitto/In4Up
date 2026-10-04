import 'package:in4up/core/language/localized_material.dart';

/// HOME-CONTINUE-001 — phần trình bày thuần của khu vực "Tiếp tục học".
///
/// File này KHÔNG import provider nào: entry được xây bằng
/// [buildContinueLearningEntries] từ dữ liệu THẬT do widget kết nối
/// (xem continue_learning_card.dart) đọc ra từ các provider hiện có.
/// Không bao giờ tạo dữ liệu giả — không có dữ liệu thì không có entry.

/// Key cho cả khu vực "Tiếp tục học".
const Key continueLearningSectionKey = Key('continue_learning_section');

/// Key cho trạng thái rỗng (chưa có hoạt động đang dở).
const Key continueLearningEmptyKey = Key('continue_learning_empty');

/// Key cho tile "Bài nghe đang dở".
const Key continueListeningTileKey = Key('continue_listening_tile');

/// Key cho tile "Văn bản đang đọc".
const Key continueReadingTileKey = Key('continue_reading_tile');

/// Key cho tile "Từ đến hạn ôn".
const Key continueDueWordsTileKey = Key('continue_due_words_tile');

/// Một mục "tiếp tục học" — bất biến, không giữ state toàn cục.
class ContinueLearningEntry {
  final Key key;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  /// Badge ngắn (vd: số từ đến hạn). Null = không hiển thị badge.
  final String? badge;
  final VoidCallback onTap;

  const ContinueLearningEntry({
    required this.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });
}

/// Xây danh sách entry từ dữ liệu thật. Hàm thuần — dễ test, không chạm
/// provider. Mục nào không có dữ liệu thì KHÔNG xuất hiện (không mock).
///
/// "Workspace gần đây" chưa được đưa vào vì chưa có provider hiện hành nào
/// expose dữ liệu đó cho Home; sẽ bổ sung khi dữ liệu thật tồn tại.
List<ContinueLearningEntry> buildContinueLearningEntries({
  required VoidCallback onResumeListening,
  required VoidCallback onResumeReading,
  required VoidCallback onReviewDue,
  String? listeningTitle,
  String? readingTitle,
  int dueWordCount = 0,
}) {
  final entries = <ContinueLearningEntry>[];

  final listening = listeningTitle?.trim();
  if (listening != null && listening.isNotEmpty) {
    entries.add(ContinueLearningEntry(
      key: continueListeningTileKey,
      icon: Icons.headphones,
      color: const Color(0xFF6C63FF),
      title: 'Bài nghe đang dở',
      subtitle: listening,
      onTap: onResumeListening,
    ));
  }

  final reading = readingTitle?.trim();
  if (reading != null && reading.isNotEmpty) {
    entries.add(ContinueLearningEntry(
      key: continueReadingTileKey,
      icon: Icons.menu_book,
      color: const Color(0xFF2196F3),
      title: 'Văn bản đang đọc',
      subtitle: reading,
      onTap: onResumeReading,
    ));
  }

  if (dueWordCount > 0) {
    entries.add(ContinueLearningEntry(
      key: continueDueWordsTileKey,
      icon: Icons.psychology,
      color: const Color(0xFF4CAF50),
      title: 'Từ đến hạn ôn',
      subtitle: 'Ôn ngay để giữ nhịp ghi nhớ',
      badge: '$dueWordCount',
      onTap: onReviewDue,
    ));
  }

  return entries;
}

/// Khu vực "Tiếp tục học" trên Home: danh sách dọc full-width (không cuộn
/// ngang → không overflow ngang), mỗi tile có vùng chạm ≥ 48dp.
class ContinueLearningSection extends StatelessWidget {
  final List<ContinueLearningEntry> entries;

  const ContinueLearningSection({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: continueLearningSectionKey,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'TIẾP TỤC HỌC',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (entries.isEmpty)
            const _EmptyContinueHint()
          else
            for (final entry in entries) _ContinueTile(entry: entry),
        ],
      ),
    );
  }
}

class _EmptyContinueHint extends StatelessWidget {
  const _EmptyContinueHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: continueLearningEmptyKey,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          Icon(
            Icons.spa_outlined,
            size: 18,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chưa có hoạt động đang dở — chọn một phòng Studio để bắt đầu.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueTile extends StatelessWidget {
  final ContinueLearningEntry entry;

  const _ContinueTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: entry.key,
      onTap: entry.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: entry.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(entry.icon, size: 18, color: entry.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (entry.badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: entry.color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.badge!,
                  style: TextStyle(
                    color: entry.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: Colors.white.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }
}
