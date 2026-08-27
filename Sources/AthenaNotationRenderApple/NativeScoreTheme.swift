import SwiftUI

/// Semantic colors used by the native notation renderer.
@available(iOS 17.0, macOS 15.0, *)
public struct NativeScoreTheme {
  public let background: Color
  public let foreground: Color
  public let playbackHighlight: Color

  public init(background: Color, foreground: Color, playbackHighlight: Color) {
    self.background = background
    self.foreground = foreground
    self.playbackHighlight = playbackHighlight
  }

  public static var light: Self {
    Self(
      background: .white,
      foreground: .black,
      playbackHighlight: .blue.opacity(0.20)
    )
  }

  public static var dark: Self {
    Self(
      background: Color(red: 0.055, green: 0.071, blue: 0.102),
      foreground: Color(red: 0.91, green: 0.93, blue: 0.96),
      playbackHighlight: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.30)
    )
  }
}
