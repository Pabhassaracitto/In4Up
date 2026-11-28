import SwiftUI
import WidgetKit

// MARK: - PLAN-050 P4 · ADR-0040 — In4Up WidgetKit Bundle Entrypoint

@main
struct In4UpWidgetsBundle: WidgetBundle {
  var body: some Widget {
    In4UpQuickBarWidget()
    In4UpContinueLearningWidget()
    In4UpFlashcardSrsWidget()
    In4UpStreakPulseWidget()
  }
}
