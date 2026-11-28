import SwiftUI
import WidgetKit

// MARK: - PLAN-050 P4 · ADR-0040 — #1 Quick Command Bar Widget (`in4up_quick_bar`)

struct In4UpQuickBarWidgetView: View {
  let entry: In4UpWidgetEntry
  @Environment(\.widgetFamily) private var family

  private var dictSearchURL: URL {
    In4UpWidgetTheme.safeURL("in4up://action/dict_search?autofocus=1&src=ios_widget")
  }

  private var slots: [WidgetQuickSlotItem] {
    Array(entry.snapshot.quickSlots.prefix(3))
  }

  var body: some View {
    Group {
      if #available(iOSApplicationExtension 16.0, *) {
        if family == .accessoryCircular {
          accessoryCircularView
        } else if family == .accessoryRectangular {
          accessoryRectangularView
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
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        ZStack {
          Circle()
            .fill(In4UpWidgetTheme.indigo)
            .frame(width: 30, height: 30)
          Image(systemName: "magnifyingglass")
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
        }
        Spacer(minLength: 4)
        if entry.snapshot.srs.totalDueCount > 0 {
          Text("\(entry.snapshot.srs.totalDueCount)")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.black)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(In4UpWidgetTheme.emerald)
            .clipShape(Capsule())
        }
      }

      Text(entry.snapshot.labels.searchHint)
        .font(.system(size: 12.5, weight: .semibold))
        .foregroundColor(.white)
        .lineLimit(2)

      Spacer(minLength: 0)

      HStack(spacing: 6) {
        ForEach(slots) { slot in
          ZStack {
            Circle()
              .fill(slot.tintColor.opacity(0.22))
              .frame(width: 26, height: 26)
            Image(systemName: slot.sfSymbolName)
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(slot.tintColor)
          }
        }
        Spacer(minLength: 0)
      }
    }
    .padding(12)
    .widgetURL(dictSearchURL)
  }

  private var mediumView: some View {
    VStack(alignment: .leading, spacing: 10) {
      Link(destination: dictSearchURL) {
        HStack(spacing: 10) {
          ZStack {
            Circle()
              .fill(In4UpWidgetTheme.indigo)
              .frame(width: 32, height: 32)
            Image(systemName: "magnifyingglass")
              .font(.system(size: 14, weight: .bold))
              .foregroundColor(.white)
          }
          Text(entry.snapshot.labels.searchHint)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white.opacity(0.86))
            .lineLimit(1)
          Spacer(minLength: 4)
          if entry.snapshot.srs.totalDueCount > 0 {
            Text(entry.snapshot.labels.dueCountBadge)
              .font(.system(size: 10.5, weight: .bold))
              .foregroundColor(In4UpWidgetTheme.emerald)
              .padding(.horizontal, 7)
              .padding(.vertical, 3)
              .background(In4UpWidgetTheme.emerald.opacity(0.16))
              .clipShape(Capsule())
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.32))
        .overlay(
          Capsule().stroke(In4UpWidgetTheme.cardBorder, lineWidth: 1)
        )
        .clipShape(Capsule())
      }

      HStack(spacing: 8) {
        ForEach(slots) { slot in
          Link(destination: In4UpWidgetTheme.safeURL(slot.deepLink)) {
            VStack(spacing: 5) {
              ZStack {
                Circle()
                  .fill(slot.tintColor.opacity(0.20))
                  .frame(width: 32, height: 32)
                Image(systemName: slot.sfSymbolName)
                  .font(.system(size: 14, weight: .semibold))
                  .foregroundColor(slot.tintColor)
              }
              Text(slot.label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.90))
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .padding(.horizontal, 4)
            .background(In4UpWidgetTheme.cardSurface)
            .overlay(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(slot.tintColor.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
        }
      }
    }
    .padding(12)
  }

  @available(iOSApplicationExtension 16.0, *)
  private var accessoryCircularView: some View {
    ZStack {
      AccessoryWidgetBackground()
      Image(systemName: "magnifyingglass")
        .font(.system(size: 18, weight: .bold))
    }
    .widgetURL(dictSearchURL)
  }

  @available(iOSApplicationExtension 16.0, *)
  private var accessoryRectangularView: some View {
    VStack(alignment: .leading, spacing: 3) {
      HStack(spacing: 5) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 11, weight: .bold))
        Text("In4Up")
          .font(.system(size: 12, weight: .bold))
          .lineLimit(1)
      }
      Text(entry.snapshot.labels.searchHint)
        .font(.system(size: 11))
        .lineLimit(1)
      if entry.snapshot.srs.totalDueCount > 0 {
        Text(entry.snapshot.labels.dueCountBadge)
          .font(.system(size: 10, weight: .semibold))
          .opacity(0.85)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .widgetURL(dictSearchURL)
  }
}

struct In4UpQuickBarWidget: Widget {
  static let widgetKind = "in4up_quick_bar"

  private static var families: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) {
      return [.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular]
    }
    return [.systemSmall, .systemMedium]
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.widgetKind, provider: In4UpTimelineProvider()) { entry in
      In4UpQuickBarWidgetView(entry: entry)
    }
    .configurationDisplayName("Quick Command Bar")
    .description("1-tap Dictionary search plus 3 customizable study shortcuts.")
    .supportedFamilies(Self.families)
  }
}
