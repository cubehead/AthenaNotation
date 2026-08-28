#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif
import SwiftUI

/// A scrollable viewport that preserves readable vertical spacing for native notation.
///
/// `NativeScorePreview` remains the low-level renderer. This view supplies the reusable
/// presentation policy: systems keep a stable minimum height and scroll vertically when
/// the available viewport is shorter than the notation canvas.
@available(iOS 17.0, macOS 15.0, *)
public struct ScrollableNativeScorePreview: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var automaticallyMeasuredSystemCount: Int?
  @State private var automaticallyMeasuredSystemHeights: [Double]?

  private let score: NotationScore
  private let playbackEventIDs: Set<NotationEventID>
  private var showsPlaybackCursor = true
  private var automaticallyBreaksSystems = false
  private let preferredSystemCount: Int
  private let minimumSystemHeight: CGFloat
  private let theme: NativeScoreTheme?
  private let interactionOptions: NativeScoreInteractionOptions
  private let onInteraction: NativeScoreInteractionHandler?
  private let onEventTap: ((NotationEventID) -> Void)?

  public init(
    score: NotationScore,
    playbackEventID: NotationEventID? = nil,
    preferredSystemCount: Int = 1,
    minimumSystemHeight: CGFloat = 310,
    theme: NativeScoreTheme? = nil
  ) {
    self.init(
      score: score,
      playbackEventID: playbackEventID,
      preferredSystemCount: preferredSystemCount,
      minimumSystemHeight: minimumSystemHeight,
      theme: theme,
      interactionOptions: .default,
      onInteraction: nil,
      onEventTap: nil
    )
  }

  public init(
    score: NotationScore,
    playbackEventIDs: Set<NotationEventID>,
    preferredSystemCount: Int = 1,
    minimumSystemHeight: CGFloat = 310,
    theme: NativeScoreTheme? = nil
  ) {
    self.init(
      score: score,
      playbackEventIDs: playbackEventIDs,
      preferredSystemCount: preferredSystemCount,
      minimumSystemHeight: minimumSystemHeight,
      theme: theme,
      interactionOptions: .default,
      onInteraction: nil,
      onEventTap: nil
    )
  }

  public init(
    score: NotationScore,
    playbackEventID: NotationEventID? = nil,
    preferredSystemCount: Int = 1,
    minimumSystemHeight: CGFloat = 310,
    theme: NativeScoreTheme? = nil,
    interactionOptions: NativeScoreInteractionOptions,
    onInteraction: NativeScoreInteractionHandler? = nil,
    onEventTap: ((NotationEventID) -> Void)? = nil
  ) {
    precondition(preferredSystemCount > 0)
    precondition(minimumSystemHeight > 0)
    self.score = score
    playbackEventIDs = playbackEventID.map { [$0] } ?? []
    self.preferredSystemCount = preferredSystemCount
    self.minimumSystemHeight = minimumSystemHeight
    self.theme = theme
    self.interactionOptions = interactionOptions
    self.onInteraction = onInteraction
    self.onEventTap = onEventTap
  }

  public init(
    score: NotationScore,
    playbackEventIDs: Set<NotationEventID>,
    preferredSystemCount: Int = 1,
    minimumSystemHeight: CGFloat = 310,
    theme: NativeScoreTheme? = nil,
    interactionOptions: NativeScoreInteractionOptions,
    onInteraction: NativeScoreInteractionHandler? = nil,
    onEventTap: ((NotationEventID) -> Void)? = nil
  ) {
    precondition(preferredSystemCount > 0)
    precondition(minimumSystemHeight > 0)
    self.score = score
    self.playbackEventIDs = playbackEventIDs
    self.preferredSystemCount = preferredSystemCount
    self.minimumSystemHeight = minimumSystemHeight
    self.theme = theme
    self.interactionOptions = interactionOptions
    self.onInteraction = onInteraction
    self.onEventTap = onEventTap
  }

  public var body: some View {
    GeometryReader { viewport in
      let systemCount = automaticallyBreaksSystems
        ? automaticallyMeasuredSystemHeights?.count
          ?? automaticallyMeasuredSystemCount ?? preferredSystemCount
        : preferredSystemCount
      let intrinsicSystemHeights: [CGFloat] = {
        if automaticallyBreaksSystems,
          let measured = automaticallyMeasuredSystemHeights,
          measured.count == systemCount
        {
          return measured.map { max(CGFloat($0), minimumSystemHeight) }
        }
        return Array(repeating: minimumSystemHeight, count: systemCount)
      }()
      let intrinsicContentHeight = intrinsicSystemHeights.reduce(0, +)
      let contentHeight = max(
        viewport.size.height,
        intrinsicContentHeight
      )
      let systemHeights = automaticallyBreaksSystems
        ? intrinsicSystemHeights
        : Array(repeating: contentHeight / CGFloat(systemCount), count: systemCount)
      let automaticTopInset = automaticallyBreaksSystems
        ? max(0, (contentHeight - intrinsicContentHeight) / 2) : 0

      ScrollViewReader { scrollProxy in
        ScrollView(.vertical) {
          ZStack(alignment: .top) {
            NativeScorePreview(
              score: score,
              playbackEventIDs: playbackEventIDs,
              preferredSystemCount: preferredSystemCount,
              theme: theme,
              interactionOptions: interactionOptions,
              onInteraction: onInteraction,
              onEventTap: onEventTap
            )
            .playbackCursorVisible(showsPlaybackCursor)
            .automaticSystemBreaks(automaticallyBreaksSystems)
            .automaticMinimumSystemHeight(Double(minimumSystemHeight))
            .frame(width: viewport.size.width, height: contentHeight)

            VStack(spacing: 0) {
              Color.clear.frame(width: 1, height: automaticTopInset)
              ForEach(0..<systemCount, id: \.self) { systemIndex in
                Color.clear
                  .frame(
                    width: 1,
                    height: systemHeights[systemIndex]
                  )
                  .id(ScoreSystemScrollAnchor(index: systemIndex))
              }
            }
            .frame(width: 1, height: contentHeight)
            .allowsHitTesting(false)
          }
          .frame(
            width: viewport.size.width,
            height: contentHeight
          )
        }
        .scrollIndicators(.visible)
        .scrollBounceBehavior(.basedOnSize)
        .background(resolvedTheme.background)
        .onPreferenceChange(NativeScoreSystemCountPreferenceKey.self) { measuredCount in
          guard automaticallyBreaksSystems else { return }
          let count = max(measuredCount, 1)
          if automaticallyMeasuredSystemCount != count {
            automaticallyMeasuredSystemCount = count
          }
        }
        .onPreferenceChange(NativeScoreSystemHeightsPreferenceKey.self) { measuredHeights in
          guard automaticallyBreaksSystems, !measuredHeights.isEmpty else { return }
          if automaticallyMeasuredSystemHeights != measuredHeights {
            automaticallyMeasuredSystemHeights = measuredHeights
          }
        }
        .onPreferenceChange(NativeScorePlaybackSystemPreferenceKey.self) { systemIndex in
          guard let systemIndex else { return }
          scrollProxy.scrollTo(
            ScoreSystemScrollAnchor(index: systemIndex),
            anchor: .center
          )
        }
      }
    }
    .background(resolvedTheme.background)
  }

  /// Controls playback-cursor drawing and automatic following while preserving
  /// the caller's current playback event IDs.
  public func playbackCursorVisible(_ isVisible: Bool) -> Self {
    var copy = self
    copy.showsPlaybackCursor = isVisible
    return copy
  }

  /// Measures the score's engraving at the current viewport width and creates
  /// as many vertically scrollable systems as the complete score requires.
  public func automaticSystemBreaks(_ isEnabled: Bool = true) -> Self {
    var copy = self
    copy.automaticallyBreaksSystems = isEnabled
    return copy
  }

  private var resolvedTheme: NativeScoreTheme {
    theme ?? (colorScheme == .dark ? .dark : .light)
  }

  private struct ScoreSystemScrollAnchor: Hashable {
    let index: Int
  }
}
