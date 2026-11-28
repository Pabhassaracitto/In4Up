import SwiftUI
import WidgetKit

// MARK: - PLAN-050 P4 · ADR-0040 — #2 Continue Learning Widget (`in4up_continue_learning`)

struct In4UpContinueLearningWidgetView: View {
  let entry: In4UpWidgetEntry
  @Environment(\.widgetFamily) private var family

  private var readFallbackURL: URL {
    In4UpWidgetTheme.safeURL("in4up://nav/studio?target=read&src=ios_widget")
  }

  private var listenFallbackURL: URL {
    In4UpWidgetTheme.safeURL("in4up://nav/studio?target=listen&src=ios_widget")
  }

  var body: some View {
    Group {
      if family == .systemSmall {
        smallView
      } else {
        mediumView
      }
    }
    .in4upWidgetBackground()
  }

  private var primaryItem: (item: WidgetResumeItem, isListen: Bool)? {
    if let read = entry.snapshot.resume.read {
      return (read, false)
    }
    if let listen = entry.snapshot.resume.listen {
      return (listen, true)
    }
    return nil
  }

  private var smallView: some View {
    let targetURL: URL = {
      if let p = primaryItem {
        return In4UpWidgetTheme.safeURL(p.item.deepLink)
      }
      return readFallbackURL
    }()

    return VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: primaryItem?.isListen == true ? "headphones" : "book.fill")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(In4UpWidgetTheme.cyan)
        Text(entry.snapshot.labels.continueHeader)
          .font(.system(size: 9.5, weight: .bold))
          .foregroundColor(In4UpWidgetTheme.cyan)
          .lineLimit(1)
      }

      if let current = primaryItem {
        Text(current.item.title)
          .font(.system(size: 13, weight: .bold))
          .foregroundColor(.white)
          .lineLimit(2)

        Spacer(minLength: 0)

        Text(current.item.subtitle)
          .font(.system(size: 10.5, weight: .medium))
          .foregroundColor(.white.opacity(0.68))
          .lineLimit(1)

        progressBar(progress: current.item.progress, color: In4UpWidgetTheme.cyan)
      } else {
        Spacer(minLength: 0)
        Text(entry.snapshot.labels.continueEmptyHint)
          .font(.system(size: 11.5, weight: .medium))
          .foregroundColor(.white.opacity(0.75))
          .lineLimit(3)
        Spacer(minLength: 0)
      }
    }
    .padding(12)
    .widgetURL(targetURL)
  }

  private var mediumView: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        HStack(spacing: 5) {
          Image(systemName: "play.circle.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(In4UpWidgetTheme.cyan)
          Text(entry.snapshot.labels.continueHeader)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundColor(In4UpWidgetTheme.cyan)
            .lineLimit(1)
        }
        Spacer()
      }

      if entry.snapshot.resume.isEmpty {
        emptyMediumBody
      } else {
        HStack(spacing: 8) {
          resumeCard(
            item: entry.snapshot.resume.read,
            fallbackLabel: entry.snapshot.labels.openReadLabel,
            fallbackURL: readFallbackURL,
            iconName: "book.fill",
            accent: In4UpWidgetTheme.indigo
          )
          resumeCard(
            item: entry.snapshot.resume.listen,
            fallbackLabel: entry.snapshot.labels.openListenLabel,
            fallbackURL: listenFallbackURL,
            iconName: entry.snapshot.resume.listen?.isPlaying == true ? "pause.fill" : "headphones",
            accent: In4UpWidgetTheme.cyan
          )
        }
      }
    }
    .padding(12)
  }

  private var emptyMediumBody: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(entry.snapshot.labels.continueEmptyHint)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.white.opacity(0.78))
        .lineLimit(2)

      Spacer(minLength: 0)

      HStack(spacing: 8) {
        Link(destination: readFallbackURL) {
          HStack(spacing: 6) {
            Image(systemName: "book.fill")
              .font(.system(size: 12, weight: .semibold))
            Text(entry.snapshot.labels.openReadLabel)
              .font(.system(size: 12, weight: .semibold))
              .lineLimit(1)
          }
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(In4UpWidgetTheme.indigo.opacity(0.28))
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }

        Link(destination: listenFallbackURL) {
          HStack(spacing: 6) {
            Image(systemName: "headphones")
              .font(.system(size: 12, weight: .semibold))
            Text(entry.snapshot.labels.openListenLabel)
              .font(.system(size: 12, weight: .semibold))
              .lineLimit(1)
          }
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(In4UpWidgetTheme.cyan.opacity(0.25))
          .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
      }
    }
  }

  private func resumeCard(
    item: WidgetResumeItem?,
    fallbackLabel: String,
    fallbackURL: URL,
    iconName: String,
    accent: Color
  ) -> some View {
    let destination = item != nil ? In4UpWidgetTheme.safeURL(item!.deepLink) : fallbackURL
    return Link(destination: destination) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          ZStack {
            Circle()
              .fill(accent.opacity(0.22))
              .frame(width: 24, height: 24)
            Image(systemName: iconName)
              .font(.system(size: 11, weight: .bold))
              .foregroundColor(accent)
          }
          Text(fallbackLabel)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(accent)
            .lineLimit(1)
          Spacer(minLength: 0)
        }

        if let active = item {
          Text(active.title)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

          Spacer(minLength: 0)

          Text(active.subtitle)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.65))
            .lineLimit(1)

          progressBar(progress: active.progress, color: accent)
        } else {
          Spacer(minLength: 0)
          Text(fallbackLabel)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white.opacity(0.80))
            .lineLimit(1)
          Spacer(minLength: 0)
        }
      }
      .padding(9)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(In4UpWidgetTheme.cardSurface)
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(accent.opacity(0.32), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
  }

  private func progressBar(progress: Double, color: Color) -> some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.white.opacity(0.14))
          .frame(height: 4)
        Capsule()
          .fill(color)
          .frame(width: max(4, geo.size.width * CGFloat(min(max(progress, 0.0), 1.0))), height: 4)
      }
    }
    .frame(height: 4)
  }
}

struct In4UpContinueLearningWidget: Widget {
  static let widgetKind = "in4up_continue_learning"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.widgetKind, provider: In4UpTimelineProvider()) { entry in
      In4UpContinueLearningWidgetView(entry: entry)
    }
    .configurationDisplayName("Continue Learning")
    .description("Resume your latest PDF/text book or audio/Dharma lesson in 1 tap.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
