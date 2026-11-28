// lib/features/home_widgets/models/widget_snapshot.dart
//
// PLAN-050 · ADR-0040 — Mô hình dữ liệu JSON phẳng «WidgetSnapshot» (v1, < 8 KB).
//
// Mục đích:
//   - Tầng Dart gom dữ liệu thật + nhãn đã dịch sẵn (Rule #5) thành 1 chuỗi JSON.
//   - Tầng Native (Android AppWidgetProvider / iOS WidgetKit) chỉ việc đọc chuỗi
//     này trong < 2ms mà KHÔNG cần khởi tạo Flutter Engine, Hive hay SQLite.
//   - Bảo toàn tuyệt đối 3 trục kỹ năng SM-2 tách biệt (Hiểu · Nghe · Đọc —
//     Quy tắc vàng #2).

import 'dart:convert';

class WidgetQuickSlotItem {
  final String id;
  final String label;
  final String iconKey;
  final String deepLink;

  const WidgetQuickSlotItem({
    required this.id,
    required this.label,
    required this.iconKey,
    required this.deepLink,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'iconKey': iconKey,
        'deepLink': deepLink,
      };

  factory WidgetQuickSlotItem.fromJson(Map<String, dynamic> json) {
    return WidgetQuickSlotItem(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? 'sparkle',
      deepLink: json['deepLink'] as String? ?? 'in4up://action/dict_search',
    );
  }
}

class WidgetChromeLabels {
  final String searchHint;
  final String continueHeader;
  final String continueEmptyHint;
  final String openReadLabel;
  final String openListenLabel;
  final String gardenHeader;
  final String srsEmptyHint;
  final String flipShowLabel;
  final String flipHideLabel;
  final String nextCardLabel;
  final String reviewNowLabel;
  final String streakHeader;
  final String skillUnderstand;
  final String skillListen;
  final String skillRead;
  final String dueCountBadge;

  const WidgetChromeLabels({
    required this.searchHint,
    required this.continueHeader,
    required this.continueEmptyHint,
    required this.openReadLabel,
    required this.openListenLabel,
    required this.gardenHeader,
    required this.srsEmptyHint,
    required this.flipShowLabel,
    required this.flipHideLabel,
    required this.nextCardLabel,
    required this.reviewNowLabel,
    required this.streakHeader,
    required this.skillUnderstand,
    required this.skillListen,
    required this.skillRead,
    required this.dueCountBadge,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'searchHint': searchHint,
        'continueHeader': continueHeader,
        'continueEmptyHint': continueEmptyHint,
        'openReadLabel': openReadLabel,
        'openListenLabel': openListenLabel,
        'gardenHeader': gardenHeader,
        'srsEmptyHint': srsEmptyHint,
        'flipShowLabel': flipShowLabel,
        'flipHideLabel': flipHideLabel,
        'nextCardLabel': nextCardLabel,
        'reviewNowLabel': reviewNowLabel,
        'streakHeader': streakHeader,
        'skillUnderstand': skillUnderstand,
        'skillListen': skillListen,
        'skillRead': skillRead,
        'dueCountBadge': dueCountBadge,
      };

  factory WidgetChromeLabels.fromJson(Map<String, dynamic> json) {
    return WidgetChromeLabels(
      searchHint: json['searchHint'] as String? ?? 'Search dictionary...',
      continueHeader: json['continueHeader'] as String? ?? 'CONTINUE LEARNING',
      continueEmptyHint:
          json['continueEmptyHint'] as String? ?? 'Start reading or listening',
      openReadLabel: json['openReadLabel'] as String? ?? 'Read',
      openListenLabel: json['openListenLabel'] as String? ?? 'Listen',
      gardenHeader: json['gardenHeader'] as String? ?? 'MEMORY GARDEN',
      srsEmptyHint:
          json['srsEmptyHint'] as String? ?? 'No cards due right now',
      flipShowLabel: json['flipShowLabel'] as String? ?? 'Show meaning',
      flipHideLabel: json['flipHideLabel'] as String? ?? 'Hide meaning',
      nextCardLabel: json['nextCardLabel'] as String? ?? 'Next',
      reviewNowLabel: json['reviewNowLabel'] as String? ?? 'Review now',
      streakHeader: json['streakHeader'] as String? ?? 'LEARNING RHYTHM',
      skillUnderstand: json['skillUnderstand'] as String? ?? 'Understand',
      skillListen: json['skillListen'] as String? ?? 'Listen',
      skillRead: json['skillRead'] as String? ?? 'Read',
      dueCountBadge: json['dueCountBadge'] as String? ?? '0',
    );
  }
}

class WidgetStreakData {
  final int days;
  final bool activeToday;
  final String headline;
  final String todaySummary;
  final String weekWindowSummary;
  final List<double> weekBars;
  final List<String> weekDayLabels;
  final String ctaLabel;
  final String ctaDeepLink;

  const WidgetStreakData({
    required this.days,
    required this.activeToday,
    required this.headline,
    required this.todaySummary,
    required this.weekWindowSummary,
    required this.weekBars,
    required this.weekDayLabels,
    required this.ctaLabel,
    required this.ctaDeepLink,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'days': days,
        'activeToday': activeToday,
        'headline': headline,
        'todaySummary': todaySummary,
        'weekWindowSummary': weekWindowSummary,
        'weekBars': weekBars,
        'weekDayLabels': weekDayLabels,
        'ctaLabel': ctaLabel,
        'ctaDeepLink': ctaDeepLink,
      };

  factory WidgetStreakData.fromJson(Map<String, dynamic> json) {
    final rawBars = (json['weekBars'] as List<dynamic>?) ?? const <dynamic>[];
    final rawLabels =
        (json['weekDayLabels'] as List<dynamic>?) ?? const <dynamic>[];
    return WidgetStreakData(
      days: json['days'] as int? ?? 0,
      activeToday: json['activeToday'] as bool? ?? false,
      headline: json['headline'] as String? ?? '0-day streak',
      todaySummary: json['todaySummary'] as String? ?? '',
      weekWindowSummary: json['weekWindowSummary'] as String? ?? '0/7',
      weekBars: rawBars
          .map((item) => (item is num) ? item.toDouble().clamp(0.0, 1.0) : 0.0)
          .toList(growable: false),
      weekDayLabels:
          rawLabels.map((item) => item.toString()).toList(growable: false),
      ctaLabel: json['ctaLabel'] as String? ?? 'Review now',
      ctaDeepLink:
          json['ctaDeepLink'] as String? ?? 'in4up://action/review_due',
    );
  }
}

class WidgetResumeItem {
  final String title;
  final String subtitle;
  final double progress;
  final bool isPlaying;
  final String deepLink;

  const WidgetResumeItem({
    required this.title,
    required this.subtitle,
    required this.progress,
    this.isPlaying = false,
    required this.deepLink,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'title': title,
        'subtitle': subtitle,
        'progress': progress,
        'isPlaying': isPlaying,
        'deepLink': deepLink,
      };

  factory WidgetResumeItem.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    return WidgetResumeItem(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      progress:
          rawProgress is num ? rawProgress.toDouble().clamp(0.0, 1.0) : 0.0,
      isPlaying: json['isPlaying'] as bool? ?? false,
      deepLink: json['deepLink'] as String? ?? 'in4up://nav/studio?target=home',
    );
  }
}

class WidgetResumeData {
  final WidgetResumeItem? listen;
  final WidgetResumeItem? read;

  const WidgetResumeData({
    this.listen,
    this.read,
  });

  bool get isEmpty => listen == null && read == null;

  Map<String, Object?> toJson() => <String, Object?>{
        if (listen != null) 'listen': listen!.toJson(),
        if (read != null) 'read': read!.toJson(),
      };

  factory WidgetResumeData.fromJson(Map<String, dynamic> json) {
    final listenRaw = json['listen'];
    final readRaw = json['read'];
    return WidgetResumeData(
      listen: listenRaw is Map<String, dynamic>
          ? WidgetResumeItem.fromJson(listenRaw)
          : null,
      read: readRaw is Map<String, dynamic>
          ? WidgetResumeItem.fromJson(readRaw)
          : null,
    );
  }
}

/// Một thẻ từ trong bộ đệm xem trước ngoài màn hình chính.
///
/// BẤT BIẾN QUY TẮC VÀNG #2:
/// Ba điểm `understandScore`, `listenScore`, `readScore` (0.0..1.0) và mức chấm
/// `understandDots`, `listenDots`, `readDots` (0..3) được giữ TÁCH BIỆT HOÀN TOÀN,
/// tuyệt đối không trung bình cộng thành một con số duy nhất.
class WidgetFlashcardItem {
  final String id;
  final String word;
  final String ipa;
  final String meaning;
  final String example;
  final double understandScore;
  final double listenScore;
  final double readScore;

  const WidgetFlashcardItem({
    required this.id,
    required this.word,
    required this.ipa,
    required this.meaning,
    required this.example,
    required this.understandScore,
    required this.listenScore,
    required this.readScore,
  });

  /// Quy đổi điểm 0.0..1.0 sang 0..3 nấc hiển thị trực quan cho từng trục riêng.
  int get understandDots => _scoreToDots(understandScore);
  int get listenDots => _scoreToDots(listenScore);
  int get readDots => _scoreToDots(readScore);

  static int _scoreToDots(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (clamped <= 0.0) return 0;
    if (clamped < 0.4) return 1;
    if (clamped < 0.75) return 2;
    return 3;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'word': word,
        'ipa': ipa,
        'meaning': meaning,
        'example': example,
        'understandScore': understandScore,
        'listenScore': listenScore,
        'readScore': readScore,
        'understandDots': understandDots,
        'listenDots': listenDots,
        'readDots': readDots,
      };

  factory WidgetFlashcardItem.fromJson(Map<String, dynamic> json) {
    double numField(String key) {
      final v = json[key];
      return v is num ? v.toDouble().clamp(0.0, 1.0) : 0.0;
    }

    return WidgetFlashcardItem(
      id: json['id'] as String? ?? '',
      word: json['word'] as String? ?? '',
      ipa: json['ipa'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
      example: json['example'] as String? ?? '',
      understandScore: numField('understandScore'),
      listenScore: numField('listenScore'),
      readScore: numField('readScore'),
    );
  }
}

class WidgetSrsData {
  final int dueVocabCount;
  final int dueLhbCount;
  final List<WidgetFlashcardItem> deck;

  const WidgetSrsData({
    required this.dueVocabCount,
    required this.dueLhbCount,
    required this.deck,
  });

  int get totalDueCount => dueVocabCount + dueLhbCount;

  Map<String, Object?> toJson() => <String, Object?>{
        'dueVocabCount': dueVocabCount,
        'dueLhbCount': dueLhbCount,
        'deck': deck.map((card) => card.toJson()).toList(growable: false),
      };

  factory WidgetSrsData.fromJson(Map<String, dynamic> json) {
    final rawDeck = (json['deck'] as List<dynamic>?) ?? const <dynamic>[];
    return WidgetSrsData(
      dueVocabCount: json['dueVocabCount'] as int? ?? 0,
      dueLhbCount: json['dueLhbCount'] as int? ?? 0,
      deck: rawDeck
          .whereType<Map<String, dynamic>>()
          .map(WidgetFlashcardItem.fromJson)
          .toList(growable: false),
    );
  }
}

class WidgetSnapshot {
  static const int currentSchemaVersion = 1;

  /// Trần kích thước JSON an toàn (8 KB) cho SharedPreferences & App Group.
  static const int maxEncodedBytes = 8192;

  final int schemaVersion;
  final int updatedAtEpochMs;
  final String locale;
  final WidgetChromeLabels labels;
  final WidgetStreakData streak;
  final WidgetResumeData resume;
  final WidgetSrsData srs;
  final List<WidgetQuickSlotItem> quickSlots;

  const WidgetSnapshot({
    this.schemaVersion = currentSchemaVersion,
    required this.updatedAtEpochMs,
    required this.locale,
    required this.labels,
    required this.streak,
    required this.resume,
    required this.srs,
    required this.quickSlots,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'updatedAtEpochMs': updatedAtEpochMs,
        'locale': locale,
        'labels': labels.toJson(),
        'streak': streak.toJson(),
        'resume': resume.toJson(),
        'srs': srs.toJson(),
        'quickSlots':
            quickSlots.map((slot) => slot.toJson()).toList(growable: false),
      };

  String toEncodedJson() => jsonEncode(toJson());

  factory WidgetSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSlots =
        (json['quickSlots'] as List<dynamic>?) ?? const <dynamic>[];
    return WidgetSnapshot(
      schemaVersion: json['schemaVersion'] as int? ?? currentSchemaVersion,
      updatedAtEpochMs: json['updatedAtEpochMs'] as int? ?? 0,
      locale: json['locale'] as String? ?? 'en',
      labels: WidgetChromeLabels.fromJson(
        (json['labels'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      streak: WidgetStreakData.fromJson(
        (json['streak'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      resume: WidgetResumeData.fromJson(
        (json['resume'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      srs: WidgetSrsData.fromJson(
        (json['srs'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      quickSlots: rawSlots
          .whereType<Map<String, dynamic>>()
          .map(WidgetQuickSlotItem.fromJson)
          .toList(growable: false),
    );
  }
}
