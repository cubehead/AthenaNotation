import AthenaNotationCore
import AthenaScoreAnalysis
import XCTest

final class ScoreExpressionTimelineTests: XCTestCase {
  func testDynamicsAndHairpinInterpolateOnExactScoreTimeline() {
    let expression = ScoreExpressionTimeline(score: score())

    XCTAssertEqual(expression.state(at: .zero).velocity, 64)
    XCTAssertEqual(expression.state(at: Rational(3, 8)).velocity, 82)
    XCTAssertEqual(expression.state(at: Rational(3, 4)).velocity, 100)
  }

  func testPedalRangeUsesSameEventAnchorsAsNotation() {
    let expression = ScoreExpressionTimeline(score: score())

    XCTAssertFalse(expression.state(at: .zero).sustainPedalDown)
    XCTAssertTrue(expression.state(at: Rational(1, 4)).sustainPedalDown)
    XCTAssertFalse(expression.state(at: Rational(1, 2)).sustainPedalDown)
  }

  private func score() -> NotationScore {
    let ids = (0..<4).map { NotationEventID(rawValue: "expression-\($0)") }
    let events = ids.enumerated().map { index, id in
      NotationEvent(
        id: id,
        content: .notes([
          NotatedPitch(midi: MIDIPitch(rawValue: UInt8(60 + index)), step: .c, octave: 4)
        ]),
        duration: Rational(1, 4),
        staffID: "treble",
        attachments: index == 0
          ? [NotationAttachment(id: "mf", content: .dynamic(label: "mf", velocity: 64))]
          : (index == 3
            ? [NotationAttachment(id: "f", content: .dynamic(label: "f", velocity: 100))]
            : [])
      )
    }
    return NotationScore(
      staves: [NotationStaff(id: "treble", clef: .treble)],
      voices: [NotationVoice(id: "voice", events: events)],
      spanners: [
        NotationSpanner(
          id: "crescendo",
          kind: .crescendo,
          startEventID: ids[0],
          endEventID: ids[3],
          placement: .below
        ),
        NotationSpanner(
          id: "pedal",
          kind: .pedal,
          startEventID: ids[1],
          endEventID: ids[2],
          placement: .below
        ),
      ]
    )
  }
}
