import AthenaNotationCore
import AthenaScoreAnalysis
import XCTest

final class ScoreNavigationTests: XCTestCase {
  func testNavigationUsesScoreOrderAndExactMeasureBeats() throws {
    let upper = NotationVoice(id: "upper", events: [
      event("u1", midi: 60, staff: "treble", duration: Rational(1, 4)),
      event("u2", midi: 62, staff: "treble", duration: Rational(3, 4)),
      event("u3", midi: 64, staff: "treble", duration: Rational(1, 8)),
    ])
    let lower = NotationVoice(id: "lower", events: [
      event("l1", midi: 48, staff: "bass", duration: .one),
      event("l2", midi: 50, staff: "bass", duration: Rational(1, 2)),
    ])
    let score = NotationScore(
      staves: [
        NotationStaff(id: "treble", clef: .treble),
        NotationStaff(id: "bass", clef: .bass),
      ],
      voices: [upper, lower]
    )

    let navigator = ScoreNavigator(score: score)
    XCTAssertEqual(navigator.entries.map(\.id.rawValue), ["u1", "l1", "u2", "u3", "l2"])
    XCTAssertEqual(navigator.entry(id: .init(rawValue: "u3"))?.measureNumber, 2)
    XCTAssertEqual(navigator.entry(id: .init(rawValue: "u3"))?.beat, .one)
    XCTAssertEqual(navigator.next(after: .init(rawValue: "u1"))?.id.rawValue, "l1")
    XCTAssertEqual(navigator.previous(before: .init(rawValue: "u1"), wrapping: true)?.id.rawValue, "l2")
    XCTAssertEqual(navigator.entries(at: .zero).count, 2)
    XCTAssertEqual(navigator.entries(inMeasure: 2).map(\.id.rawValue), ["u3", "l2"])
    XCTAssertEqual(navigator.nearest(to: Rational(9, 8), staffID: "bass")?.id.rawValue, "l2")
  }

  func testAccessibilityFormatterDescribesContentDurationAndAnnotations() throws {
    let chord = NotationEvent(
      id: .init(rawValue: "chord"),
      content: .notes([
        NotatedPitch(midi: .init(rawValue: 61), step: .c, octave: 4, accidental: .sharp),
        NotatedPitch(midi: .init(rawValue: 64), step: .e, octave: 4),
      ]),
      duration: Rational(3, 8),
      writtenDuration: Rational(1, 4),
      dotCount: 1,
      staffID: "treble",
      hand: .right,
      attachments: [
        NotationAttachment(id: "finger", content: .fingering(.thumb)),
        NotationAttachment(id: "dynamic", content: .dynamic(label: "mf", velocity: 72)),
      ]
    )
    let score = NotationScore(
      staves: [NotationStaff(id: "treble", clef: .treble)],
      voices: [NotationVoice(id: "voice", events: [chord])]
    )
    let entry = try XCTUnwrap(ScoreNavigator(score: score).entries.first)

    XCTAssertEqual(
      ScoreAccessibilityFormatter(localeIdentifier: "en_US").label(for: entry),
      "Measure 1, beat 1, chord C4 sharp E4, 1-dot quarter note, finger 1, dynamic mf"
    )
    XCTAssertEqual(
      ScoreAccessibilityFormatter(localeIdentifier: "zh_CN").label(for: entry),
      "第1小节，第1拍，和弦 升C4 E4，1个附点四分音符，指法 1，力度 mf"
    )
  }

  private func event(
    _ id: String,
    midi: UInt8,
    staff: String,
    duration: Rational
  ) -> NotationEvent {
    let steps: [DiatonicStep] = [.c, .d, .e, .f, .g, .a, .b]
    return NotationEvent(
      id: .init(rawValue: id),
      content: .notes([
        NotatedPitch(
          midi: .init(rawValue: midi),
          step: steps[Int(midi) % steps.count],
          octave: Int(midi) / 12 - 1
        )
      ]),
      duration: duration,
      staffID: staff
    )
  }
}
