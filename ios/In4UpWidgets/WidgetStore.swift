import Foundation
import WidgetKit

// MARK: - PLAN-050 P4 · ADR-0040 — App Group Store & TimelineProvider
//
// Reads `widget_snapshot_json` from `group.com.in4up.shared` (< 2 ms, zero
// Flutter Engine / FFI startup). Falls back gracefully to `UserDefaults.standard`
// if an unsigned/free-account sideload strips App Group entitlements.

final class In4UpWidgetStore {
  static let shared = In4UpWidgetStore()

  static let appGroupSuiteName = "group.com.in4up.shared"
  static let snapshotKey = "widget_snapshot_json"
  static let deckIndexKey = "widget_srs_deck_index"
  static let isFlippedKey = "widget_srs_is_flipped"

  private init() {}

  private var defaults: UserDefaults {
    UserDefaults(suiteName: Self.appGroupSuiteName) ?? .standard
  }

  func loadSnapshot() -> WidgetSnapshot {
    let store = defaults
    guard let raw = store.string(forKey: Self.snapshotKey),
          !raw.isEmpty,
          let data = raw.data(using: .utf8)
    else {
      return .emptyInitial
    }
    do {
      return try JSONDecoder().decode(WidgetSnapshot.self, from: data)
    } catch {
      return .emptyInitial
    }
  }

  func currentDeckIndex(deckCount: Int) -> Int {
    guard deckCount > 0 else { return 0 }
    let raw = defaults.integer(forKey: Self.deckIndexKey)
    let normalized = ((raw % deckCount) + deckCount) % deckCount
    return normalized
  }

  var isFlipped: Bool {
    defaults.bool(forKey: Self.isFlippedKey)
  }

  func toggleFlip() {
    let store = defaults
    store.set(!store.bool(forKey: Self.isFlippedKey), forKey: Self.isFlippedKey)
  }

  func advanceCard() {
    let snapshot = loadSnapshot()
    let count = snapshot.srs.deck.count
    let store = defaults
    guard count > 0 else {
      store.set(0, forKey: Self.deckIndexKey)
      store.set(false, forKey: Self.isFlippedKey)
      return
    }
    let next = (currentDeckIndex(deckCount: count) + 1) % count
    store.set(next, forKey: Self.deckIndexKey)
    store.set(false, forKey: Self.isFlippedKey)
  }
}

struct In4UpWidgetEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot
  let currentCardIndex: Int
  let isCardFlipped: Bool

  var activeCard: WidgetFlashcardItem? {
    let deck = snapshot.srs.deck
    guard !deck.isEmpty else { return nil }
    let idx = min(max(currentCardIndex, 0), deck.count - 1)
    return deck[idx]
  }

  static var placeholderEntry: In4UpWidgetEntry {
    In4UpWidgetEntry(
      date: Date(),
      snapshot: .placeholder,
      currentCardIndex: 0,
      isCardFlipped: true
    )
  }
}

struct In4UpTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> In4UpWidgetEntry {
    .placeholderEntry
  }

  func getSnapshot(in context: Context, completion: @escaping (In4UpWidgetEntry) -> Void) {
    if context.isPreview {
      completion(.placeholderEntry)
      return
    }
    completion(loadCurrentEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<In4UpWidgetEntry>) -> Void) {
    let entry = loadCurrentEntry()
    // Event-driven updates come immediately via `WidgetCenter.shared.reloadAllTimelines()`.
    // Schedule the fallback refresh at the start of tomorrow so daily streak boundaries stay fresh
    // without draining battery in the background.
    let calendar = Calendar.current
    let tomorrow = calendar.startOfDay(
      for: calendar.date(byAdding: .day, value: 1, to: entry.date) ?? entry.date.addingTimeInterval(3600)
    )
    completion(Timeline(entries: [entry], policy: .after(tomorrow)))
  }

  private func loadCurrentEntry() -> In4UpWidgetEntry {
    let store = In4UpWidgetStore.shared
    let snapshot = store.loadSnapshot()
    let index = store.currentDeckIndex(deckCount: snapshot.srs.deck.count)
    return In4UpWidgetEntry(
      date: Date(),
      snapshot: snapshot,
      currentCardIndex: index,
      isCardFlipped: store.isFlipped
    )
  }
}
