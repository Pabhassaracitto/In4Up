import Foundation
import SwiftUI
import WidgetKit

// MARK: - PLAN-050 P4 · ADR-0040 — WidgetSnapshot v1 Models (iOS WidgetKit)
//
// Matches `lib/features/home_widgets/models/widget_snapshot.dart` 1:1.
// Golden Rule #2: `understandDots`, `listenDots`, and `readDots` remain
// strictly separate — never averaged into a single SRS score.
// Golden Rule #5: Fallback chrome defaults are pure English so non-`vi`
// devices never see leaked Vietnamese strings before first sync.

struct WidgetQuickSlotItem: Codable, Hashable, Identifiable {
  let id: String
  let label: String
  let iconKey: String
  let deepLink: String

  init(id: String, label: String, iconKey: String, deepLink: String) {
    self.id = id
    self.label = label
    self.iconKey = iconKey
    self.deepLink = deepLink
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? "voice_capture"
    self.label = try c.decodeIfPresent(String.self, forKey: .label) ?? "Quick Action"
    self.iconKey = try c.decodeIfPresent(String.self, forKey: .iconKey) ?? "sparkle"
    self.deepLink =
      try c.decodeIfPresent(String.self, forKey: .deepLink)
      ?? "in4up://action/dict_search?src=ios_widget"
  }

  var sfSymbolName: String {
    switch iconKey {
    case "mic":
      return "mic.fill"
    case "ocr":
      return "doc.viewfinder"
    case "translate":
      return "character.bubble.fill"
    case "sparkle":
      return "sparkles"
    case "leaf":
      return "leaf.fill"
    case "book":
      return "book.fill"
    case "video":
      return "play.rectangle.fill"
    case "headphones":
      return "headphones"
    case "search":
      return "magnifyingglass"
    default:
      return "bolt.fill"
    }
  }

  var tintColor: Color {
    switch iconKey {
    case "mic":
      return Color(red: 1.0, green: 0.32, blue: 0.32)
    case "ocr":
      return Color(red: 0.26, green: 0.65, blue: 0.96)
    case "translate":
      return Color(red: 0.15, green: 0.78, blue: 0.85)
    case "sparkle":
      return Color(red: 0.71, green: 0.36, blue: 0.90)
    case "leaf":
      return Color(red: 0.0, green: 0.88, blue: 0.46)
    case "book":
      return Color(red: 1.0, green: 0.80, blue: 0.28)
    case "video":
      return Color(red: 0.94, green: 0.33, blue: 0.31)
    case "headphones":
      return Color(red: 0.16, green: 0.71, blue: 0.96)
    default:
      return Color(red: 0.42, green: 0.39, blue: 1.0)
    }
  }
}

struct WidgetChromeLabels: Codable, Hashable {
  let searchHint: String
  let continueHeader: String
  let continueEmptyHint: String
  let openReadLabel: String
  let openListenLabel: String
  let gardenHeader: String
  let srsEmptyHint: String
  let flipShowLabel: String
  let flipHideLabel: String
  let nextCardLabel: String
  let reviewNowLabel: String
  let streakHeader: String
  let skillUnderstand: String
  let skillListen: String
  let skillRead: String
  let dueCountBadge: String

  static let fallback = WidgetChromeLabels(
    searchHint: "Search In4Up dictionary...",
    continueHeader: "CONTINUE LEARNING",
    continueEmptyHint: "Open a book or audio lesson to resume in 1 tap",
    openReadLabel: "Read",
    openListenLabel: "Listen",
    gardenHeader: "MEMORY GARDEN",
    srsEmptyHint: "All caught up! Add or review words in In4Up",
    flipShowLabel: "Meaning",
    flipHideLabel: "Hide",
    nextCardLabel: "Next",
    reviewNowLabel: "Review",
    streakHeader: "LEARNING RHYTHM",
    skillUnderstand: "Understand",
    skillListen: "Listen",
    skillRead: "Read",
    dueCountBadge: "0"
  )

  init(
    searchHint: String,
    continueHeader: String,
    continueEmptyHint: String,
    openReadLabel: String,
    openListenLabel: String,
    gardenHeader: String,
    srsEmptyHint: String,
    flipShowLabel: String,
    flipHideLabel: String,
    nextCardLabel: String,
    reviewNowLabel: String,
    streakHeader: String,
    skillUnderstand: String,
    skillListen: String,
    skillRead: String,
    dueCountBadge: String
  ) {
    self.searchHint = searchHint
    self.continueHeader = continueHeader
    self.continueEmptyHint = continueEmptyHint
    self.openReadLabel = openReadLabel
    self.openListenLabel = openListenLabel
    self.gardenHeader = gardenHeader
    self.srsEmptyHint = srsEmptyHint
    self.flipShowLabel = flipShowLabel
    self.flipHideLabel = flipHideLabel
    self.nextCardLabel = nextCardLabel
    self.reviewNowLabel = reviewNowLabel
    self.streakHeader = streakHeader
    self.skillUnderstand = skillUnderstand
    self.skillListen = skillListen
    self.skillRead = skillRead
    self.dueCountBadge = dueCountBadge
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let f = Self.fallback
    self.searchHint = try c.decodeIfPresent(String.self, forKey: .searchHint) ?? f.searchHint
    self.continueHeader =
      try c.decodeIfPresent(String.self, forKey: .continueHeader) ?? f.continueHeader
    self.continueEmptyHint =
      try c.decodeIfPresent(String.self, forKey: .continueEmptyHint) ?? f.continueEmptyHint
    self.openReadLabel =
      try c.decodeIfPresent(String.self, forKey: .openReadLabel) ?? f.openReadLabel
    self.openListenLabel =
      try c.decodeIfPresent(String.self, forKey: .openListenLabel) ?? f.openListenLabel
    self.gardenHeader =
      try c.decodeIfPresent(String.self, forKey: .gardenHeader) ?? f.gardenHeader
    self.srsEmptyHint =
      try c.decodeIfPresent(String.self, forKey: .srsEmptyHint) ?? f.srsEmptyHint
    self.flipShowLabel =
      try c.decodeIfPresent(String.self, forKey: .flipShowLabel) ?? f.flipShowLabel
    self.flipHideLabel =
      try c.decodeIfPresent(String.self, forKey: .flipHideLabel) ?? f.flipHideLabel
    self.nextCardLabel =
      try c.decodeIfPresent(String.self, forKey: .nextCardLabel) ?? f.nextCardLabel
    self.reviewNowLabel =
      try c.decodeIfPresent(String.self, forKey: .reviewNowLabel) ?? f.reviewNowLabel
    self.streakHeader =
      try c.decodeIfPresent(String.self, forKey: .streakHeader) ?? f.streakHeader
    self.skillUnderstand =
      try c.decodeIfPresent(String.self, forKey: .skillUnderstand) ?? f.skillUnderstand
    self.skillListen =
      try c.decodeIfPresent(String.self, forKey: .skillListen) ?? f.skillListen
    self.skillRead =
      try c.decodeIfPresent(String.self, forKey: .skillRead) ?? f.skillRead
    self.dueCountBadge =
      try c.decodeIfPresent(String.self, forKey: .dueCountBadge) ?? f.dueCountBadge
  }
}

struct WidgetStreakData: Codable, Hashable {
  let days: Int
  let activeToday: Bool
  let headline: String
  let todaySummary: String
  let weekWindowSummary: String
  let weekBars: [Double]
  let weekDayLabels: [String]
  let ctaLabel: String
  let ctaDeepLink: String

  static let fallback = WidgetStreakData(
    days: 0,
    activeToday: false,
    headline: "Start your streak",
    todaySummary: "1 tap to study today",
    weekWindowSummary: "0/7 days",
    weekBars: [0.15, 0.3, 0.2, 0.5, 0.4, 0.65, 0.25],
    weekDayLabels: ["M", "T", "W", "T", "F", "S", "S"],
    ctaLabel: "Study now",
    ctaDeepLink: "in4up://action/review_due?mode=srs&src=ios_widget"
  )

  init(
    days: Int,
    activeToday: Bool,
    headline: String,
    todaySummary: String,
    weekWindowSummary: String,
    weekBars: [Double],
    weekDayLabels: [String],
    ctaLabel: String,
    ctaDeepLink: String
  ) {
    self.days = days
    self.activeToday = activeToday
    self.headline = headline
    self.todaySummary = todaySummary
    self.weekWindowSummary = weekWindowSummary
    self.weekBars = weekBars
    self.weekDayLabels = weekDayLabels
    self.ctaLabel = ctaLabel
    self.ctaDeepLink = ctaDeepLink
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let f = Self.fallback
    self.days = try c.decodeIfPresent(Int.self, forKey: .days) ?? f.days
    self.activeToday = try c.decodeIfPresent(Bool.self, forKey: .activeToday) ?? f.activeToday
    self.headline = try c.decodeIfPresent(String.self, forKey: .headline) ?? f.headline
    self.todaySummary = try c.decodeIfPresent(String.self, forKey: .todaySummary) ?? f.todaySummary
    self.weekWindowSummary =
      try c.decodeIfPresent(String.self, forKey: .weekWindowSummary) ?? f.weekWindowSummary
    self.weekBars = try c.decodeIfPresent([Double].self, forKey: .weekBars) ?? f.weekBars
    self.weekDayLabels =
      try c.decodeIfPresent([String].self, forKey: .weekDayLabels) ?? f.weekDayLabels
    self.ctaLabel = try c.decodeIfPresent(String.self, forKey: .ctaLabel) ?? f.ctaLabel
    self.ctaDeepLink = try c.decodeIfPresent(String.self, forKey: .ctaDeepLink) ?? f.ctaDeepLink
  }
}

struct WidgetResumeItem: Codable, Hashable {
  let title: String
  let subtitle: String
  let progress: Double
  let isPlaying: Bool
  let deepLink: String

  init(title: String, subtitle: String, progress: Double, isPlaying: Bool, deepLink: String) {
    self.title = title
    self.subtitle = subtitle
    self.progress = min(max(progress, 0.0), 1.0)
    self.isPlaying = isPlaying
    self.deepLink = deepLink
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
    self.subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle) ?? ""
    let raw = try c.decodeIfPresent(Double.self, forKey: .progress) ?? 0.0
    self.progress = min(max(raw, 0.0), 1.0)
    self.isPlaying = try c.decodeIfPresent(Bool.self, forKey: .isPlaying) ?? false
    self.deepLink =
      try c.decodeIfPresent(String.self, forKey: .deepLink)
      ?? "in4up://nav/studio?target=home&src=ios_widget"
  }
}

struct WidgetResumeData: Codable, Hashable {
  let listen: WidgetResumeItem?
  let read: WidgetResumeItem?

  var isEmpty: Bool {
    listen == nil && read == nil
  }

  init(listen: WidgetResumeItem? = nil, read: WidgetResumeItem? = nil) {
    self.listen = listen
    self.read = read
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.listen = try c.decodeIfPresent(WidgetResumeItem.self, forKey: .listen)
    self.read = try c.decodeIfPresent(WidgetResumeItem.self, forKey: .read)
  }
}

struct WidgetFlashcardItem: Codable, Hashable, Identifiable {
  let id: String
  let word: String
  let ipa: String
  let meaning: String
  let example: String
  let understandScore: Double
  let listenScore: Double
  let readScore: Double
  let understandDots: Int
  let listenDots: Int
  let readDots: Int

  init(
    id: String,
    word: String,
    ipa: String,
    meaning: String,
    example: String,
    understandScore: Double,
    listenScore: Double,
    readScore: Double,
    understandDots: Int,
    listenDots: Int,
    readDots: Int
  ) {
    self.id = id
    self.word = word
    self.ipa = ipa
    self.meaning = meaning
    self.example = example
    self.understandScore = understandScore
    self.listenScore = listenScore
    self.readScore = readScore
    self.understandDots = understandDots
    self.listenDots = listenDots
    self.readDots = readDots
  }

  private static func scoreToDots(_ value: Double) -> Int {
    let clamped = min(max(value, 0.0), 1.0)
    if clamped <= 0.0 { return 0 }
    if clamped < 0.4 { return 1 }
    if clamped < 0.75 { return 2 }
    return 3
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try c.decodeIfPresent(String.self, forKey: .id) ?? ""
    self.word = try c.decodeIfPresent(String.self, forKey: .word) ?? ""
    self.ipa = try c.decodeIfPresent(String.self, forKey: .ipa) ?? ""
    self.meaning = try c.decodeIfPresent(String.self, forKey: .meaning) ?? ""
    self.example = try c.decodeIfPresent(String.self, forKey: .example) ?? ""
    let uScore = try c.decodeIfPresent(Double.self, forKey: .understandScore) ?? 0.0
    let lScore = try c.decodeIfPresent(Double.self, forKey: .listenScore) ?? 0.0
    let rScore = try c.decodeIfPresent(Double.self, forKey: .readScore) ?? 0.0
    self.understandScore = uScore
    self.listenScore = lScore
    self.readScore = rScore
    self.understandDots =
      try c.decodeIfPresent(Int.self, forKey: .understandDots) ?? Self.scoreToDots(uScore)
    self.listenDots =
      try c.decodeIfPresent(Int.self, forKey: .listenDots) ?? Self.scoreToDots(lScore)
    self.readDots =
      try c.decodeIfPresent(Int.self, forKey: .readDots) ?? Self.scoreToDots(rScore)
  }
}

struct WidgetSrsData: Codable, Hashable {
  let dueVocabCount: Int
  let dueLhbCount: Int
  let deck: [WidgetFlashcardItem]

  var totalDueCount: Int {
    dueVocabCount + dueLhbCount
  }

  static let fallback = WidgetSrsData(dueVocabCount: 0, dueLhbCount: 0, deck: [])

  init(dueVocabCount: Int, dueLhbCount: Int, deck: [WidgetFlashcardItem]) {
    self.dueVocabCount = dueVocabCount
    self.dueLhbCount = dueLhbCount
    self.deck = deck
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.dueVocabCount = try c.decodeIfPresent(Int.self, forKey: .dueVocabCount) ?? 0
    self.dueLhbCount = try c.decodeIfPresent(Int.self, forKey: .dueLhbCount) ?? 0
    self.deck = try c.decodeIfPresent([WidgetFlashcardItem].self, forKey: .deck) ?? []
  }
}

struct WidgetSnapshot: Codable, Hashable {
  let schemaVersion: Int
  let updatedAtEpochMs: Int64
  let locale: String
  let labels: WidgetChromeLabels
  let streak: WidgetStreakData
  let resume: WidgetResumeData
  let srs: WidgetSrsData
  let quickSlots: [WidgetQuickSlotItem]

  static let defaultSlots: [WidgetQuickSlotItem] = [
    WidgetQuickSlotItem(
      id: "voice_capture",
      label: "Voice Note",
      iconKey: "mic",
      deepLink: "in4up://action/voice_capture?autostart=1&src=ios_widget"
    ),
    WidgetQuickSlotItem(
      id: "ocr_scan",
      label: "Scan OCR",
      iconKey: "ocr",
      deepLink: "in4up://action/ocr_scan?src=ios_widget"
    ),
    WidgetQuickSlotItem(
      id: "ai_chat",
      label: "AI Chat",
      iconKey: "sparkle",
      deepLink: "in4up://action/ai_chat?autofocus=1&src=ios_widget"
    ),
  ]

  static let placeholder = WidgetSnapshot(
    schemaVersion: 1,
    updatedAtEpochMs: 0,
    locale: "en",
    labels: .fallback,
    streak: WidgetStreakData(
      days: 7,
      activeToday: true,
      headline: "7-day streak",
      todaySummary: "15m study · 6 words",
      weekWindowSummary: "6/7 days",
      weekBars: [0.4, 0.7, 0.55, 0.85, 0.6, 0.9, 1.0],
      weekDayLabels: ["M", "T", "W", "T", "F", "S", "S"],
      ctaLabel: "Review",
      ctaDeepLink: "in4up://action/review_due?mode=srs&src=ios_widget"
    ),
    resume: WidgetResumeData(
      listen: WidgetResumeItem(
        title: "Audio Lesson — Mindful Listening",
        subtitle: "12:40 / 28:00",
        progress: 0.45,
        isPlaying: false,
        deepLink: "in4up://action/resume_listen?autoplay=1&src=ios_widget"
      ),
      read: WidgetResumeItem(
        title: "Reading Guide.pdf",
        subtitle: "Line 42 / 180",
        progress: 0.23,
        isPlaying: false,
        deepLink: "in4up://action/resume_read?src=ios_widget"
      )
    ),
    srs: WidgetSrsData(
      dueVocabCount: 8,
      dueLhbCount: 2,
      deck: [
        WidgetFlashcardItem(
          id: "sample_1",
          word: "resilient",
          ipa: "/rɪˈzɪl.i.ənt/",
          meaning: "Able to recover quickly from difficulties",
          example: "Consistent daily practice builds resilient memory.",
          understandScore: 0.8,
          listenScore: 0.5,
          readScore: 0.9,
          understandDots: 3,
          listenDots: 2,
          readDots: 3
        )
      ]
    ),
    quickSlots: defaultSlots
  )

  static let emptyInitial = WidgetSnapshot(
    schemaVersion: 1,
    updatedAtEpochMs: 0,
    locale: "en",
    labels: .fallback,
    streak: .fallback,
    resume: WidgetResumeData(),
    srs: .fallback,
    quickSlots: defaultSlots
  )

  init(
    schemaVersion: Int,
    updatedAtEpochMs: Int64,
    locale: String,
    labels: WidgetChromeLabels,
    streak: WidgetStreakData,
    resume: WidgetResumeData,
    srs: WidgetSrsData,
    quickSlots: [WidgetQuickSlotItem]
  ) {
    self.schemaVersion = schemaVersion
    self.updatedAtEpochMs = updatedAtEpochMs
    self.locale = locale
    self.labels = labels
    self.streak = streak
    self.resume = resume
    self.srs = srs
    self.quickSlots = quickSlots.isEmpty ? Self.defaultSlots : quickSlots
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    self.updatedAtEpochMs = try c.decodeIfPresent(Int64.self, forKey: .updatedAtEpochMs) ?? 0
    self.locale = try c.decodeIfPresent(String.self, forKey: .locale) ?? "en"
    self.labels = try c.decodeIfPresent(WidgetChromeLabels.self, forKey: .labels) ?? .fallback
    self.streak = try c.decodeIfPresent(WidgetStreakData.self, forKey: .streak) ?? .fallback
    self.resume =
      try c.decodeIfPresent(WidgetResumeData.self, forKey: .resume) ?? WidgetResumeData()
    self.srs = try c.decodeIfPresent(WidgetSrsData.self, forKey: .srs) ?? .fallback
    let decodedSlots = try c.decodeIfPresent([WidgetQuickSlotItem].self, forKey: .quickSlots) ?? []
    self.quickSlots = decodedSlots.isEmpty ? Self.defaultSlots : decodedSlots
  }
}

// MARK: - Shared UI Helpers (iOS 15.0+ through iOS 18+)

enum In4UpWidgetTheme {
  static let bgTop = Color(red: 0.08, green: 0.10, blue: 0.20)
  static let bgBottom = Color(red: 0.05, green: 0.06, blue: 0.13)
  static let cardSurface = Color.white.opacity(0.08)
  static let cardBorder = Color.white.opacity(0.12)
  static let indigo = Color(red: 0.42, green: 0.39, blue: 1.0)
  static let cyan = Color(red: 0.15, green: 0.78, blue: 0.85)
  static let emerald = Color(red: 0.0, green: 0.90, blue: 0.46)
  static let amber = Color(red: 1.0, green: 0.57, blue: 0.0)

  static var surfaceGradient: LinearGradient {
    LinearGradient(
      colors: [bgTop, bgBottom],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  static func safeURL(_ raw: String, fallback: String = "in4up://action/dict_search?src=ios_widget") -> URL {
    if let parsed = URL(string: raw), parsed.scheme != nil {
      return parsed
    }
    return URL(string: fallback)!
  }
}

extension View {
  @ViewBuilder
  func in4upWidgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.containerBackground(for: .widget) {
        In4UpWidgetTheme.surfaceGradient
      }
    } else {
      self.background(In4UpWidgetTheme.surfaceGradient)
    }
  }
}

/// Renders the 3 independent SM-2 skill dots (`0..3`) for one skill axis.
struct SkillAxisBadgeView: View {
  let label: String
  let dots: Int
  let accent: Color

  var body: some View {
    HStack(spacing: 3) {
      Text(label)
        .font(.system(size: 9, weight: .semibold))
        .foregroundColor(.white.opacity(0.72))
        .lineLimit(1)
      HStack(spacing: 2) {
        ForEach(0..<3, id: \.self) { idx in
          Circle()
            .fill(idx < dots ? accent : Color.white.opacity(0.20))
            .frame(width: 4.5, height: 4.5)
        }
      }
    }
    .padding(.horizontal, 5)
    .padding(.vertical, 2.5)
    .background(Color.white.opacity(0.07))
    .clipShape(Capsule())
  }
}
