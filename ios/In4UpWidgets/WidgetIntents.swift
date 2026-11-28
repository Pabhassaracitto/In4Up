import AppIntents
import Foundation
import WidgetKit

// MARK: - PLAN-050 P4 · ADR-0040 (Q3) — iOS 17+ Interactive Flashcard Intents
//
// Flips meaning & advances preview cards directly on the iOS 17+ Home Screen,
// Lock Screen, or StandBy without launching the main app. Official SRS grading
// always routes through `in4up://action/review_due` to protect the 3-skill SM-2
// algorithm (`Understand · Listen · Read`).

@available(iOS 17.0, iOSApplicationExtension 17.0, *)
struct FlipFlashcardIntent: AppIntent {
  static var title: LocalizedStringResource = "Flip Flashcard Meaning"
  static var description = IntentDescription("Show or hide the meaning of the current vocabulary card.")

  init() {}

  func perform() async throws -> some IntentResult {
    In4UpWidgetStore.shared.toggleFlip()
    WidgetCenter.shared.reloadTimelines(ofKind: In4UpFlashcardSrsWidget.widgetKind)
    return .result()
  }
}

@available(iOS 17.0, iOSApplicationExtension 17.0, *)
struct NextFlashcardIntent: AppIntent {
  static var title: LocalizedStringResource = "Next Flashcard"
  static var description = IntentDescription("Advance to the next due vocabulary card in the widget preview.")

  init() {}

  func perform() async throws -> some IntentResult {
    In4UpWidgetStore.shared.advanceCard()
    WidgetCenter.shared.reloadTimelines(ofKind: In4UpFlashcardSrsWidget.widgetKind)
    return .result()
  }
}
