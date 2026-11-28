// lib/features/home_widgets/services/widget_snapshot_builder.dart
//
// PLAN-050 · ADR-0040 — Bộ dựng `WidgetSnapshot` THUẦN DART (không plugin, không UI).
//
// Ba bảo chứng bất biến:
//   1. Rule #5 (i18n): Mọi nhãn giao diện (chrome) đi qua `AppUITranslations.translate`
//      theo `localeCode`. Khi `localeCode != 'vi'`, không một nhãn chrome nào còn
//      ký tự tiếng Việt. Nội dung của người dùng (tên tệp, từ vựng, nghĩa người
//      dùng nhập) giữ nguyên bản gốc theo đúng quy định của AGENTS.md.
//   2. Quy tắc vàng #2 (SM-2): Giữ tách biệt 3 điểm `understandData.score`,
//      `listenData.score`, `readData.score` trên mỗi thẻ từ.
//   3. Giới hạn kích thước: Cắt gọn theo ranh giới rune Unicode và giảm dần số
//      thẻ trong bộ đệm nếu tổng UTF-8 vượt quá `WidgetSnapshot.maxEncodedBytes`
//      (8192 byte) — không bao giờ làm vỡ ký tự đa byte hoặc phình bộ nhớ.

import 'dart:convert';

import '../../../core/language/app_ui_translations.dart';
import '../../../models/learning_activity.dart';
import '../../../models/word_entry.dart';
import '../models/widget_quick_action.dart';
import '../models/widget_snapshot.dart';

/// Đầu vào thô của mục nghe đang dở (lấy từ PlayerProvider hoặc RecentAudioService).
class WidgetListenSourceInput {
  final String title;
  final Duration position;
  final Duration duration;
  final bool isPlaying;

  const WidgetListenSourceInput({
    required this.title,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
  });
}

/// Đầu vào thô của mục đọc đang dở (lấy từ TextProvider hoặc RecentFilesService).
class WidgetReadSourceInput {
  final String title;
  final int currentUnit;
  final int totalUnits;
  final bool isPdf;

  const WidgetReadSourceInput({
    required this.title,
    this.currentUnit = 0,
    this.totalUnits = 0,
    this.isPdf = false,
  });
}

class WidgetSnapshotBuilder {
  WidgetSnapshotBuilder._();

  /// Số thẻ tối đa nạp sẵn vào snapshot cho Widget Thẻ Từ SRS lật/duyệt nhanh.
  static const int maxDeckCards = 8;

  static WidgetSnapshot build({
    required String localeCode,
    required LearningStreakSnapshot streakSnapshot,
    required List<WordEntry> dueWords,
    required List<WordEntry> fallbackWords,
    int dueLhbCount = 0,
    WidgetListenSourceInput? listenSource,
    WidgetReadSourceInput? readSource,
    Iterable<String>? rawQuickBarSlotKeys,
    required bool isAndroid,
    int? nowEpochMs,
  }) {
    final canonicalLocale = AppUITranslations.canonicalLocaleCode(localeCode);
    String tr(String viSource) =>
        AppUITranslations.translate(viSource, canonicalLocale);

    final totalDue = dueWords.length + (dueLhbCount > 0 ? dueLhbCount : 0);
    final dueBadge = totalDue > 0
        ? tr('$totalDue từ đến hạn')
        : tr('Đã hoàn thành hôm nay');

    final labels = WidgetChromeLabels(
      searchHint: tr('Tra từ điển In4Up...'),
      continueHeader: tr('TIẾP TỤC HỌC'),
      continueEmptyHint:
          tr('Chưa có bài đang dở — chạm Đọc hoặc Nghe để bắt đầu'),
      openReadLabel: tr('Đọc'),
      openListenLabel: tr('Nghe'),
      gardenHeader: tr('VƯỜN TRÍ NHỚ'),
      srsEmptyHint: tr('Chưa có thẻ đến hạn — chạm để mở kho từ vựng'),
      flipShowLabel: tr('Hiện nghĩa'),
      flipHideLabel: tr('Ẩn nghĩa'),
      nextCardLabel: tr('Từ tiếp'),
      reviewNowLabel: tr('Ôn ngay'),
      streakHeader: tr('NHỊP ĐIỆU HỌC TẬP'),
      skillUnderstand: tr('Hiểu'),
      skillListen: tr('Nghe'),
      skillRead: tr('Đọc'),
      dueCountBadge: dueBadge,
    );

    final resume = _buildResume(
      listenSource: listenSource,
      readSource: readSource,
      tr: tr,
    );

    final streak = _buildStreak(
      snapshot: streakSnapshot,
      totalDue: totalDue,
      hasResumeRead: resume.read != null,
      tr: tr,
    );

    final normalizedSlots = WidgetQuickActionId.normalizeSlots(
      rawQuickBarSlotKeys,
      isAndroid: isAndroid,
    );
    final quickSlots = normalizedSlots
        .map(
          (action) => WidgetQuickSlotItem(
            id: action.wireKey,
            label: tr(action.sourceTitle),
            iconKey: action.nativeIconKey,
            deepLink: action.deepLinkUri,
          ),
        )
        .toList(growable: false);

    // Ưu tiên thẻ đến hạn; nếu đã ôn hết hôm nay vẫn hiển thị tối đa vài từ đã lưu
    // để người học xem thụ động ngoài màn hình chính (nhưng dueVocabCount vẫn = 0).
    final sourceEntries = dueWords.isNotEmpty ? dueWords : fallbackWords;
    final rawDeck = sourceEntries
        .take(maxDeckCards)
        .map(_toFlashcardItem)
        .where((item) => item.word.isNotEmpty)
        .toList(growable: false);

    final timestamp = nowEpochMs ?? DateTime.now().millisecondsSinceEpoch;
    return _fitWithinByteBudget(
      locale: canonicalLocale,
      updatedAtEpochMs: timestamp,
      labels: labels,
      streak: streak,
      resume: resume,
      dueVocabCount: dueWords.length,
      dueLhbCount: dueLhbCount > 0 ? dueLhbCount : 0,
      deck: rawDeck,
      quickSlots: quickSlots,
    );
  }

  static WidgetResumeData _buildResume({
    required WidgetListenSourceInput? listenSource,
    required WidgetReadSourceInput? readSource,
    required String Function(String) tr,
  }) {
    WidgetResumeItem? listenItem;
    if (listenSource != null && listenSource.title.trim().isNotEmpty) {
      final cleanTitle = _truncateRunes(listenSource.title.trim(), 72);
      final totalSec = listenSource.duration.inSeconds;
      final posSec = listenSource.position.inSeconds;
      final progress =
          totalSec > 0 ? (posSec / totalSec).clamp(0.0, 1.0) : 0.0;
      final subtitle = totalSec > 0
          ? '${_formatClock(listenSource.position)} / ${_formatClock(listenSource.duration)}'
          : (listenSource.isPlaying ? tr('Đang phát') : tr('Chạm để nghe tiếp'));
      listenItem = WidgetResumeItem(
        title: cleanTitle,
        subtitle: subtitle,
        progress: _round3(progress),
        isPlaying: listenSource.isPlaying,
        deepLink: 'in4up://action/resume_listen?autoplay=1&src=widget',
      );
    }

    WidgetResumeItem? readItem;
    if (readSource != null && readSource.title.trim().isNotEmpty) {
      final cleanTitle = _truncateRunes(readSource.title.trim(), 72);
      final total = readSource.totalUnits;
      final current = readSource.currentUnit;
      final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
      String subtitle;
      if (total > 0 && current > 0) {
        subtitle = readSource.isPdf
            ? tr('Trang $current / $total')
            : tr('Dòng $current / $total');
      } else {
        subtitle = readSource.isPdf ? 'PDF' : tr('Chạm để đọc tiếp');
      }
      readItem = WidgetResumeItem(
        title: cleanTitle,
        subtitle: subtitle,
        progress: _round3(progress),
        deepLink: 'in4up://action/resume_read?src=widget',
      );
    }

    return WidgetResumeData(
      listen: listenItem,
      read: readItem,
    );
  }

  static WidgetStreakData _buildStreak({
    required LearningStreakSnapshot snapshot,
    required int totalDue,
    required bool hasResumeRead,
    required String Function(String) tr,
  }) {
    final days = snapshot.streak;
    final headline = tr('$days ngày liên tiếp');

    final summaryParts = <String>[];
    final today = snapshot.today;
    final readMin = today.countOf(LearningActivityKind.readingMinutes);
    final vocabCount = today.countOf(LearningActivityKind.vocabulary);
    final lhbCount = today.countOf(LearningActivityKind.learnByHeart);
    final shadowCount = today.countOf(LearningActivityKind.shadowing);
    final docCount = today.countOf(LearningActivityKind.readDocument);

    if (readMin > 0) summaryParts.add(tr('$readMin phút đọc'));
    if (vocabCount > 0) summaryParts.add(tr('$vocabCount từ'));
    if (lhbCount > 0) summaryParts.add(tr('$lhbCount lượt ôn'));
    if (shadowCount > 0) summaryParts.add(tr('$shadowCount lượt shadowing'));
    if (summaryParts.isEmpty && docCount > 0) {
      summaryParts.add(tr('$docCount tài liệu'));
    }

    final todaySummary = snapshot.activeToday && summaryParts.isNotEmpty
        ? summaryParts.take(2).join(' · ')
        : (snapshot.activeToday
            ? tr('Đã giữ nhịp hôm nay')
            : tr('Hôm nay chưa có hoạt động học'));

    final maxTotal = snapshot.maxDayTotal;
    final bars = <double>[];
    final dayLabels = <String>[];
    for (final day in snapshot.recentDays) {
      final factor = maxTotal <= 0
          ? 0.08
          : (day.totalEvents / maxTotal).clamp(0.08, 1.0);
      bars.add(_round3(day.isActive ? factor : 0.08));
      dayLabels.add('${day.dayOfMonth}');
    }

    final String ctaLabel;
    final String ctaLink;
    if (totalDue > 0) {
      ctaLabel = tr('Ôn ngay');
      ctaLink = 'in4up://action/review_due?mode=srs&src=widget';
    } else if (!snapshot.activeToday && hasResumeRead) {
      ctaLabel = tr('Đọc tiếp');
      ctaLink = 'in4up://action/resume_read?src=widget';
    } else {
      ctaLabel = tr('Bắt đầu học');
      ctaLink = 'in4up://nav/studio?target=home&src=widget';
    }

    return WidgetStreakData(
      days: days,
      activeToday: snapshot.activeToday,
      headline: headline,
      todaySummary: todaySummary,
      weekWindowSummary: tr('${snapshot.activeDaysInWindow}/7 ngày có học'),
      weekBars: List<double>.unmodifiable(bars),
      weekDayLabels: List<String>.unmodifiable(dayLabels),
      ctaLabel: ctaLabel,
      ctaDeepLink: ctaLink,
    );
  }

  static WidgetFlashcardItem _toFlashcardItem(WordEntry entry) {
    final rawExample = (entry.example ?? '').trim();
    final contextSentence = rawExample.isNotEmpty
        ? rawExample
        : (entry.contexts.isNotEmpty
            ? entry.contexts.first.surroundingText.trim()
            : '');
    return WidgetFlashcardItem(
      id: _truncateRunes(entry.id, 48),
      word: _truncateRunes(entry.word.trim(), 64),
      ipa: _truncateRunes((entry.phonetic ?? '').trim(), 48),
      meaning: _truncateRunes(entry.meaning.trim(), 120),
      example: _truncateRunes(contextSentence, 120),
      understandScore: _round3(entry.understandData.score.clamp(0.0, 1.0)),
      listenScore: _round3(entry.listenData.score.clamp(0.0, 1.0)),
      readScore: _round3(entry.readData.score.clamp(0.0, 1.0)),
    );
  }

  static WidgetSnapshot _fitWithinByteBudget({
    required String locale,
    required int updatedAtEpochMs,
    required WidgetChromeLabels labels,
    required WidgetStreakData streak,
    required WidgetResumeData resume,
    required int dueVocabCount,
    required int dueLhbCount,
    required List<WidgetFlashcardItem> deck,
    required List<WidgetQuickSlotItem> quickSlots,
  }) {
    var currentDeck = deck;
    while (true) {
      final candidate = WidgetSnapshot(
        updatedAtEpochMs: updatedAtEpochMs,
        locale: locale,
        labels: labels,
        streak: streak,
        resume: resume,
        srs: WidgetSrsData(
          dueVocabCount: dueVocabCount,
          dueLhbCount: dueLhbCount,
          deck: currentDeck,
        ),
        quickSlots: quickSlots,
      );
      final byteLength = utf8.encode(candidate.toEncodedJson()).length;
      if (byteLength <= WidgetSnapshot.maxEncodedBytes || currentDeck.isEmpty) {
        return candidate;
      }
      currentDeck = currentDeck.sublist(0, currentDeck.length - 1);
    }
  }

  static String _truncateRunes(String input, int maxRunes) {
    final singleLine = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.runes.length <= maxRunes) return singleLine;
    final kept = String.fromCharCodes(singleLine.runes.take(maxRunes - 1));
    return '$kept…';
  }

  static String _formatClock(Duration duration) {
    final totalSeconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  static double _round3(double value) =>
      (value * 1000).roundToDouble() / 1000.0;
}
