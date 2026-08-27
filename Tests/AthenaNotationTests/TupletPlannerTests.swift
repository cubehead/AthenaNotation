import AthenaNotationCore
import AthenaNotationLayout
import XCTest

final class TupletPlannerTests: XCTestCase {
  func testTripletUsesActualTimeButEighthNoteEngraving() {
    let voice = NotationVoice(
      id: "triplet",
      events: (0..<3).map {
        event("triplet-\($0)", duration: Rational(1, 12), written: Rational(1, 8))
      }
    )
    let inputs = HorizontalFormatter().makeInputs(voices: [voice])

    XCTAssertEqual(inputs.map(\.onset), [.zero, Rational(1, 12), Rational(1, 6)])
    XCTAssertEqual(
      inputs.map(\.event.engravingDuration), Array(repeating: Rational(1, 8), count: 3))

    let beam = BeamPlanner().groups(inputs: inputs).first
    XCTAssertEqual(beam?.eventIDs.count, 3)
    XCTAssertEqual(beam?.eventBeamCounts, [1, 1, 1])
  }

  func testFiveletRatioAndQuarterBeatOccupancyRemainExact() {
    let events = (0..<5).map {
      event("fivelet-\($0)", duration: Rational(1, 20), written: Rational(1, 16))
    }
    let tuplet = NotationTuplet(
      id: "fivelet",
      eventIDs: events.map(\.id),
      actualCount: 5,
      normalCount: 4
    )
    let inputs = HorizontalFormatter().makeInputs(voices: [
      NotationVoice(id: "voice", events: events)
    ])

    XCTAssertEqual(tuplet.actualCount, 5)
    XCTAssertEqual(tuplet.normalCount, 4)
    let totalDuration = (inputs.last?.onset ?? .zero) + (events.last?.duration ?? .zero)
    XCTAssertEqual(totalDuration, Rational(1, 4))
  }

  func testTupletPlannerPreservesGroupOnOneSystem() throws {
    let events = (0..<3).map {
      event("event-\($0)", duration: Rational(1, 12), written: Rational(1, 8))
    }
    let inputs = HorizontalFormatter().makeInputs(voices: [
      NotationVoice(id: "voice", events: events)
    ])
    let layouts = [HorizontalFormatter().format(inputs: inputs, justifyTo: 400)]
    let tuplet = NotationTuplet(
      id: "triplet",
      eventIDs: events.map(\.id),
      actualCount: 3,
      normalCount: 2
    )

    let segment = try XCTUnwrap(TupletPlanner().segments(tuplets: [tuplet], layouts: layouts).first)

    XCTAssertEqual(segment.eventIDs, events.map(\.id))
    XCTAssertTrue(segment.beginsTuplet)
    XCTAssertTrue(segment.endsTuplet)
  }

  private func event(_ id: String, duration: Rational, written: Rational) -> NotationEvent {
    NotationEvent(
      id: NotationEventID(rawValue: id),
      content: .notes([NotatedPitch(midi: MIDIPitch(rawValue: 72), step: .c, octave: 5)]),
      duration: duration,
      writtenDuration: written,
      staffID: "treble",
      hand: .right
    )
  }
}
