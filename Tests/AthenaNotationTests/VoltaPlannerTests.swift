import AthenaNotationCore
import AthenaNotationLayout
import XCTest

final class VoltaPlannerTests: XCTestCase {
  func testVoltaPreservesNumbersAndExactRange() {
    let volta = NotationVolta(
      id: "ending-1",
      startOnset: Rational(1, 2),
      endOnset: Rational(3, 2),
      numbers: [1, 3]
    )

    XCTAssertEqual(volta.startOnset, Rational(1, 2))
    XCTAssertEqual(volta.endOnset, Rational(3, 2))
    XCTAssertEqual(volta.numbers, [1, 3])
  }

  func testVoltaSplitsAcrossSystemsAndOnlyLabelsItsStart() {
    let events = (0..<8).map { index in
      NotationEvent(
        id: NotationEventID(rawValue: "note-\(index)"),
        content: .notes([
          NotatedPitch(midi: MIDIPitch(rawValue: 60), step: .c, octave: 4)
        ]),
        duration: Rational(1, 4),
        staffID: "treble"
      )
    }
    let formatter = HorizontalFormatter()
    let layouts = SystemFormatter(horizontalFormatter: formatter).format(
      inputs: formatter.makeInputs(voices: [NotationVoice(id: "voice", events: events)]),
      systemCount: 2,
      justifyTo: 500,
      measureDuration: .one
    )
    let volta = NotationVolta(
      id: "cross-system",
      startOnset: Rational(1, 2),
      endOnset: Rational(3, 2),
      numbers: [1]
    )

    let segments = VoltaPlanner().segments(
      voltas: [volta],
      layouts: layouts,
      scoreEnd: Rational(2)
    )

    XCTAssertEqual(segments.count, 2)
    XCTAssertTrue(segments[0].startsHere)
    XCTAssertFalse(segments[0].endsHere)
    XCTAssertFalse(segments[1].startsHere)
    XCTAssertTrue(segments[1].endsHere)
  }
}
