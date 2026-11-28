import AppIntents
import SwiftUI
import WidgetKit

// MARK: - PLAN-050 P4 · ADR-0040 — #3 Flashcard & SRS Garden Widget (`in4up_flashcard_srs`)
//
// Golden Rule #2: Preserves the 3 separate SM-2 skill scores (`Understand`,
// `Listen`, `Read`) as distinct dot indicators (`understandDots`, `listenDots`,
// `readDots`), never averaging them.
// Q3: On iOS 17+, `FlipFlashcardIntent` & `NextFlashcardIntent` flip meaning
// and cycle preview cards directly on the Home Screen without opening the app.

struct In4UpFlashcardSrsWidgetView: View {
  let entry: In4UpWidgetEntry
  @Environment(\.widgetFamily) private var family

  private var reviewURL: URL {
    In4UpWidgetTheme.safeURL("in4up://action/review_due?mode=srs&src=ios_widget")
  }

  var body: some View {
    Group {
      if #available(iOSApplicationExtension 16.0, *) {
        if family == .accessoryRectangular {
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
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Image(systemName: "leaf.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(In4UpWidgetTheme.emerald)
        Spacer()
        Text("\(entry.snapshot.srs.totalDueCount)")
          .font(.system(size: 10.5, weight: .bold))
          .foregroundColor(.black)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(In4UpWidgetTheme.emerald)
          .clipShape(Capsule())
      }

      if let card = entry.activeCard {
        Text(card.word)
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(.white)
          .lineLimit(1)

        if entry.isCardFlipped {
          Text(card.meaning)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(In4UpWidgetTheme.emerald)
            .lineLimit(2)
        } else if !card.ipa.isEmpty {
          Text(card.ipa)
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(.white.opacity(0.65))
            .lineLimit(1)
        }

        Spacer(minLength: 0)

        HStack(spacing: 4) {
          compactDots(card.understandDots, color: In4UpWidgetTheme.indigo)
          compactDots(card.listenDots, color: In4UpWidgetTheme.cyan)
          compactDots(card.readDots, color: In4UpWidgetTheme.emerald)
          Spacer(minLength: 0)
          if #available(iOSApplicationExtension 17.0, *) {
            Button(intent: FlipFlashcardIntent()) {
              Image(systemName: entry.isCardFlipped ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(5)
                .background(Color.white.opacity(0.16))
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
          }
        }
      } else {
        Spacer(minLength: 0)
        Text(entry.snapshot.labels.srsEmptyHint)
          .font(.system(size: 11.5, weight: .medium))
          .foregroundColor(.white.opacity(0.76))
          .lineLimit(3)
        Spacer(minLength: 0)
      }
    }
    .padding(12)
    .widgetURL(reviewURL)
  }

  private var mediumView: some View {
    let labels = entry.snapshot.labels
    return VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 6) {
        Image(systemName: "leaf.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(In4UpWidgetTheme.emerald)
        Text(labels.gardenHeader)
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(In4UpWidgetTheme.emerald)
          .lineLimit(1)
        Spacer()
        Text(labels.dueCountBadge)
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(In4UpWidgetTheme.emerald)
          .padding(.horizontal, 7)
          .padding(.vertical, 2)
          .background(In4UpWidgetTheme.emerald.opacity(0.16))
          .clipShape(Capsule())
      }

      if let card = entry.activeCard {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(card.word)
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(.white)
            .lineLimit(1)
          if !card.ipa.isEmpty {
            Text(card.ipa)
              .font(.system(size: 12, weight: .regular))
              .foregroundColor(.white.opacity(0.62))
              .lineLimit(1)
          }
          Spacer(minLength: 0)
        }

        if entry.isCardFlipped {
          Text(card.meaning)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundColor(In4UpWidgetTheme.emerald)
            .lineLimit(2)
        } else if !card.example.isEmpty {
          Text(card.example)
            .font(.system(size: 11.5, weight: .regular))
            .foregroundColor(.white.opacity(0.72))
            .lineLimit(1)
        } else {
          Text("••••••")
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(.white.opacity(0.32))
            .lineLimit(1)
        }

        HStack(spacing: 5) {
          SkillAxisBadgeView(
            label: labels.skillUnderstand,
            dots: card.understandDots,
            accent: In4UpWidgetTheme.indigo
          )
          SkillAxisBadgeView(
            label: labels.skillListen,
            dots: card.listenDots,
            accent: In4UpWidgetTheme.cyan
          )
          SkillAxisBadgeView(
            label: labels.skillRead,
            dots: card.readDots,
            accent: In4UpWidgetTheme.emerald
          )
          Spacer(minLength: 0)
        }

        Spacer(minLength: 0)

        actionRow(labels: labels)
      } else {
        Spacer(minLength: 0)
        Text(labels.srsEmptyHint)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.white.opacity(0.78))
          .lineLimit(2)
        Spacer(minLength: 0)
        Link(destination: reviewURL) {
          HStack(spacing: 5) {
            Image(systemName: "play.fill")
              .font(.system(size: 10, weight: .bold))
            Text(labels.reviewNowLabel)
              .font(.system(size: 11.5, weight: .bold))
              .lineLimit(1)
          }
          .foregroundColor(.black)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(In4UpWidgetTheme.emerald)
          .clipShape(Capsule())
        }
      }
    }
    .padding(12)
  }

  @ViewBuilder
  private func actionRow(labels: WidgetChromeLabels) -> some View {
    HStack(spacing: 6) {
      if #available(iOSApplicationExtension 17.0, *) {
        Button(intent: FlipFlashcardIntent()) {
          HStack(spacing: 4) {
            Image(systemName: entry.isCardFlipped ? "eye.slash" : "eye")
              .font(.system(size: 10.5, weight: .semibold))
            Text(entry.isCardFlipped ? labels.flipHideLabel : labels.flipShowLabel)
              .font(.system(size: 11, weight: .semibold))
              .lineLimit(1)
          }
          .foregroundColor(.white)
          .padding(.horizontal, 9)
          .padding(.vertical, 5)
          .background(In4UpWidgetTheme.cardSurface)
          .clipShape(Capsule())
        }
        .buttonStyle(.plain)

        Button(intent: NextFlashcardIntent()) {
          HStack(spacing: 4) {
            Image(systemName: "forward.end.fill")
              .font(.system(size: 10, weight: .semibold))
            Text(labels.nextCardLabel)
              .font(.system(size: 11, weight: .semibold))
              .lineLimit(1)
          }
          .foregroundColor(.white)
          .padding(.horizontal, 9)
          .padding(.vertical, 5)
          .background(In4UpWidgetTheme.cardSurface)
          .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }

      Spacer(minLength: 0)

      Link(destination: reviewURL) {
        HStack(spacing: 4) {
          Image(systemName: "play.fill")
            .font(.system(size: 10, weight: .bold))
          Text(labels.reviewNowLabel)
            .font(.system(size: 11, weight: .bold))
            .lineLimit(1)
        }
        .foregroundColor(.black)
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(In4UpWidgetTheme.emerald)
        .clipShape(Capsule())
      }
    }
  }

  private func compactDots(_ count: Int, color: Color) -> some View {
    HStack(spacing: 1.5) {
      ForEach(0..<3, id: \.self) { idx in
        Circle()
          .fill(idx < count ? color : Color.white.opacity(0.18))
          .frame(width: 4, height: 4)
      }
    }
    .padding(.horizontal, 3.5)
    .padding(.vertical, 2)
    .background(Color.white.opacity(0.06))
    .clipShape(Capsule())
  }

  @available(iOSApplicationExtension 16.0, *)
  private var accessoryRectangularView: some View {
    VStack(alignment: .leading, spacing: 2) {
      if let card = entry.activeCard {
        HStack(spacing: 4) {
          Image(systemName: "leaf.fill")
            .font(.system(size: 10, weight: .bold))
          Text(card.word)
            .font(.system(size: 13, weight: .bold))
            .lineLimit(1)
        }
        Text(card.meaning.isEmpty ? card.ipa : card.meaning)
          .font(.system(size: 11))
          .lineLimit(1)
        Text(
          "\(entry.snapshot.labels.skillUnderstand):\(card.understandDots)/3 · \(entry.snapshot.labels.skillListen):\(card.listenDots)/3 · \(entry.snapshot.labels.skillRead):\(card.readDots)/3"
        )
        .font(.system(size: 9.5, weight: .medium))
        .opacity(0.85)
        .lineLimit(1)
      } else {
        Text(entry.snapshot.labels.gardenHeader)
          .font(.system(size: 11, weight: .bold))
          .lineLimit(1)
        Text(entry.snapshot.labels.srsEmptyHint)
          .font(.system(size: 11))
          .lineLimit(2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .widgetURL(reviewURL)
  }
}

struct In4UpFlashcardSrsWidget: Widget {
  static let widgetKind = "in4up_flashcard_srs"

  private static var families: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) {
      return [.systemSmall, .systemMedium, .accessoryRectangular]
    }
    return [.systemSmall, .systemMedium]
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.widgetKind, provider: In4UpTimelineProvider()) { entry in
      In4UpFlashcardSrsWidgetView(entry: entry)
    }
    .configurationDisplayName("Flashcard & SRS Garden")
    .description("Flip vocabulary meanings on your Home Screen and track Understand · Listen · Read skills.")
    .supportedFamilies(Self.families)
  }
}
