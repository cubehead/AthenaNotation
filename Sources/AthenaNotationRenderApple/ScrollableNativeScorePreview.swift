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

  private let score: NotationScore
  private let playbackEventIDs: Set<NotationEventID>
  private let preferredSystemCount: Int
  private let minimumSystemHeight: CGFloat
  private let theme: NativeScoreTheme?

  public init(
    score: NotationScore,
    playbackEventID: NotationEventID? = nil,
    preferredSystemCount: Int = 1,
    minimumSystemHeight: CGFloat = 310,
    theme: NativeScoreTheme? = nil
  ) {
    precondition(preferredSystemCount > 0)
    precondition(minimumSystemHeight > 0)
    self.score = score
    playbackEventIDs = playbackEventID.map { [$0] } ?? []
    self.preferredSystemCount = preferredSystemCount
    self.minimumSystemHeight = minimumSystemHeight
    self.theme = theme
  }

  public init(
    score: NotationScore,
    playbackEventIDs: Set<NotationEventID>,
    preferredSystemCount: Int = 1,
    minimumSystemHeight: CGFloat = 310,
    theme: NativeScoreTheme? = nil
  ) {
    precondition(preferredSystemCount > 0)
    precondition(minimumSystemHeight > 0)
    self.score = score
    self.playbackEventIDs = playbackEventIDs
    self.preferredSystemCount = preferredSystemCount
    self.minimumSystemHeight = minimumSystemHeight
    self.theme = theme
  }

  public var body: some View {
    GeometryReader { viewport in
      ScrollView(.vertical) {
        NativeScorePreview(
          score: score,
          playbackEventIDs: playbackEventIDs,
          preferredSystemCount: preferredSystemCount,
          theme: theme
        )
        .frame(
          width: viewport.size.width,
          height: max(
            viewport.size.height,
            CGFloat(preferredSystemCount) * minimumSystemHeight
          )
        )
      }
      .scrollIndicators(.visible)
      .scrollBounceBehavior(.basedOnSize)
      .background(resolvedTheme.background)
    }
    .background(resolvedTheme.background)
  }

  private var resolvedTheme: NativeScoreTheme {
    theme ?? (colorScheme == .dark ? .dark : .light)
  }
}
