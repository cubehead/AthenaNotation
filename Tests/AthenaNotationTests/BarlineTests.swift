import AthenaNotationCore
import XCTest

final class BarlineTests: XCTestCase {
  func testRepeatBarlinePreservesExactOnsetAndPlaybackCount() {
    let barline = NotationBarline(
      onset: Rational(3, 4),
      style: .repeatEnd,
      repeatCount: 3
    )

    XCTAssertEqual(barline.onset, Rational(3, 4))
    XCTAssertEqual(barline.style, .repeatEnd)
    XCTAssertEqual(barline.repeatCount, 3)
  }

  func testScoreStoresRepeatStartEndAndBothStyles() {
    let score = NotationScore(
      staves: [],
      voices: [],
      barlines: [
        NotationBarline(onset: .zero, style: .repeatStart),
        NotationBarline(onset: .one, style: .repeatBoth),
        NotationBarline(onset: Rational(2), style: .repeatEnd),
      ]
    )

    XCTAssertEqual(score.barlines.map(\.style), [.repeatStart, .repeatBoth, .repeatEnd])
  }
}
