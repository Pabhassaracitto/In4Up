import SwiftUI
import WidgetKit

// MARK: - PLAN-050 P4 · ADR-0040 — #4 Streak & Weekly Rhythm Widget (`in4up_streak_pulse`)

struct In4UpStreakPulseWidgetView: View {
  let entry: In4UpWidgetEntry
  @Environment(\.widgetFamily) private var family

  private var ctaURL: URL {
    In4UpWidgetTheme.safeURL(entry.snapshot.streak.ctaDeepLink)
  }

  var body: some View {
    Group {
      if #available(iOSApplicationExtension 16.0, *) {
        if family == .accessoryCircular {
          accessoryCircularView
        } else if family == .accessoryRectangular {
          accessoryRectangularView
        } else if family == .accessoryInline {
          accessoryInlineView
        } else if family == .systemSmall {
          smallView
        } else {
          mediumView
        }
      } else {
        if family == .systemSmall {
          smallView
        } else {
          mediumView
        }
      }
    }
    .in4upWidgetBackground()
  }

  private var smallView: some View {
    let streak = entry.snapshot.streak
    return VStack(alignment: .leading, spacing: 6) {
      HStack {
        ZStack {
          Circle()
            .fill(In4UpWidgetTheme.amber.opacity(streak.activeToday ? 0.24 : 0.12))
            .frame(width: 30, height: 30)
          Image(systemName: "flame.fill")
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(streak.activeToday ? In4UpWidgetTheme.amber : .white.opacity(0.5))
        }
        Spacer()
        Text(streak.weekWindowSummary)
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(In4UpWidgetTheme.amber)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(In4UpWidgetTheme.amber.opacity(0.15))
          .clipShape(Capsule())
      }

      Text("\(streak.days)")
        .font(.system(size: 26, weight: .heavy))
        .foregroundColor(.white)
        .lineLimit(1)

      Text(streak.headline)
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundColor(.white.opacity(0.88))
        .lineLimit(1)

      Spacer(minLength: 0)

      if !streak.todaySummary.isEmpty {
        Text(streak.todaySummary)
          .font(.system(size: 10.5, weight: .medium))
          .foregroundColor(.white.opacity(0.65))
          .lineLimit(1)
      }
    }
    .padding(12)
    .widgetURL(ctaURL)
  }

  private var mediumView: some View {
    let streak = entry.snapshot.streak
    return HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 5) {
          Image(systemName: "flame.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(In4UpWidgetTheme.amber)
          Text(entry.snapshot.labels.streakHeader)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(In4UpWidgetTheme.amber)
            .lineLimit(1)
        }

        Text(streak.headline)
          .font(.system(size: 16, weight: .bold))
          .foregroundColor(.white)
          .lineLimit(1)

        if !streak.todaySummary.isEmpty {
          Text(streak.todaySummary)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.70))
            .lineLimit(1)
        }

        Spacer(minLength: 0)

        Link(destination: ctaURL) {
          HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
              .font(.system(size: 10, weight: .bold))
            Text(streak.ctaLabel)
              .font(.system(size: 11, weight: .bold))
              .lineLimit(1)
          }
          .foregroundColor(.black)
          .padding(.horizontal, 11)
          .padding(.vertical, 5)
          .background(In4UpWidgetTheme.amber)
          .clipShape(Capsule())
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      weekBarsChart(streak: streak)
        .frame(width: 128)
    }
    .padding(12)
  }

  private func weekBarsChart(streak: WidgetStreakData) -> some View {
    let bars = normalizedWeekBars(streak.weekBars)
    let labels = normalizedWeekLabels(streak.weekDayLabels)
    return VStack(spacing: 5) {
      HStack {
        Spacer()
        Text(streak.weekWindowSummary)
          .font(.system(size: 10, weight: .semibold))
          .foregroundColor(.white.opacity(0.65))
          .lineLimit(1)
      }
      HStack(alignment: .bottom, spacing: 6) {
        ForEach(0..<7, id: \.self) { idx in
          VStack(spacing: 4) {
            GeometryReader { geo in
              VStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                  .fill(idx == 6 && streak.activeToday ? In4UpWidgetTheme.amber : In4UpWidgetTheme.indigo)
                  .frame(height: max(6, geo.size.height * CGFloat(bars[idx])))
              }
            }
            Text(labels[idx])
              .font(.system(size: 9, weight: .semibold))
              .foregroundColor(.white.opacity(idx == 6 ? 0.95 : 0.55))
              .lineLimit(1)
          }
        }
      }
    }
    .padding(9)
    .background(In4UpWidgetTheme.cardSurface)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func normalizedWeekBars(_ raw: [Double]) -> [Double] {
    var result = Array(raw.prefix(7)).map { min(max($0, 0.08), 1.0) }
    while result.count < 7 {
      result.append(0.08)
    }
    return result
  }

  private func normalizedWeekLabels(_ raw: [String]) -> [String] {
    let defaults = ["1", "2", "3", "4", "5", "6", "7"]
    var result = Array(raw.prefix(7))
    while result.count < 7 {
      result.append(defaults[result.count])
    }
    return result
  }

  @available(iOSApplicationExtension 16.0, *)
  private var accessoryCircularView: some View {
    ZStack {
      AccessoryWidgetBackground()
      VStack(spacing: 1) {
        Image(systemName: "flame.fill")
          .font(.system(size: 13, weight: .bold))
        Text("\(entry.snapshot.streak.days)")
          .font(.system(size: 13, weight: .heavy))
          .lineLimit(1)
      }
    }
    .widgetURL(ctaURL)
  }

  @available(iOSApplicationExtension 16.0, *)
  private var accessoryRectangularView: some View {
    let streak = entry.snapshot.streak
    return VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 4) {
        Image(systemName: "flame.fill")
          .font(.system(size: 11, weight: .bold))
        Text(streak.headline)
          .font(.system(size: 12, weight: .bold))
          .lineLimit(1)
      }
      if !streak.todaySummary.isEmpty {
        Text(streak.todaySummary)
          .font(.system(size: 11))
          .lineLimit(1)
      }
      Text(streak.weekWindowSummary)
        .font(.system(size: 10, weight: .semibold))
        .opacity(0.85)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .widgetURL(ctaURL)
  }

  @available(iOSApplicationExtension 16.0, *)
  private var accessoryInlineView: some View {
    Text("🔥 \(entry.snapshot.streak.headline) · \(entry.snapshot.streak.weekWindowSummary)")
      .widgetURL(ctaURL)
  }
}

struct In4UpStreakPulseWidget: Widget {
  static let widgetKind = "in4up_streak_pulse"

  private static var families: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) {
      return [
        .systemSmall,
        .systemMedium,
        .accessoryCircular,
        .accessoryRectangular,
        .accessoryInline,
      ]
    }
    return [.systemSmall, .systemMedium]
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.widgetKind, provider: In4UpTimelineProvider()) { entry in
      In4UpStreakPulseWidgetView(entry: entry)
    }
    .configurationDisplayName("Streak & Study Rhythm")
    .description("Track your daily study streak and 7-day learning rhythm on Home or Lock Screen.")
    .supportedFamilies(Self.families)
  }
}
