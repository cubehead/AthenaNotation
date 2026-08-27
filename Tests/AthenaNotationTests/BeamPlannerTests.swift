import AthenaNotationCore
import AthenaNotationLayout
import XCTest

final class BeamPlannerTests: XCTestCase {
  func testGroupsTwoEighthNotesWithinOneQuarterBeat() throws {
    let inputs = HorizontalFormatter().makeInputs(voices: [
      NotationVoice(
        id: "voice",
        events: [
          event("a", duration: Rational(1, 8)),
          event("b", duration: Rational(1, 8)),
        ])
    ])

    let group = try XCTUnwrap(BeamPlanner().groups(inputs: inputs).only)
    XCTAssertEqual(group.eventIDs.map(\.rawValue), ["a", "b"])
    XCTAssertEqual(group.beamCount, 1)
    XCTAssertEqual(group.eventBeamCounts, [1, 1])
  }

  func testGroupsFourSixteenthNotesWithTwoBeams() throws {
    let inputs = HorizontalFormatter().makeInputs(voices: [
      NotationVoice(
        id: "voice",
        events: [
          event("a", duration: Rational(1, 16)),
          event("b", duration: Rational(1, 16)),
          event("c", duration: Rational(1, 16)),
          event("d", duration: Rational(1, 16)),
        ])
    ])

    let group = try XCTUnwrap(BeamPlanner().groups(inputs: inputs).only)
    XCTAssertEqual(group.eventIDs.count, 4)
    XCTAssertEqual(group.beamCount, 2)
    XCTAssertEqual(group.eventBeamCounts, [2, 2, 2, 2])
  }

  func testMixedEighthAndTwoSixteenthsSharePrimaryBeam() throws {
    let inputs = HorizontalFormatter().makeInputs(voices: [
      NotationVoice(
        id: "voice",
        events: [
          event("eighth", duration: Rational(1, 8)),
          event("sixteenth-a", duration: Rational(1, 16)),
          event("sixteenth-b", duration: Rational(1, 16)),
        ])
    ])

    let group = try XCTUnwrap(BeamPlanner().groups(inputs: inputs).only)
    XCTAssertEqual(group.eventIDs.map(\.rawValue), ["eighth", "sixteenth-a", "sixteenth-b"])
    XCTAssertEqual(group.eventBeamCounts, [1, 2, 2])
    XCTAssertEqual(group.beamCount, 2)
  }

  func testTwoSixteenthsThenEighthRemainOneMixedGroup() throws {
    let inputs = HorizontalFormatter().makeInputs(voices: [
      NotationVoice(
        id: "voice",
        events: [
          event("sixteenth-a", duration: Rational(1, 16)),
          event("sixteenth-b", duration: Rational(1, 16)),
          event("eighth", duration: Rational(1, 8)),
        ])
    ])

    let group = try XCTUnwrap(BeamPlanner().groups(inputs: inputs).only)
    XCTAssertEqual(group.eventBeamCounts, [2, 2, 1])
  }

  func testDoesNotBeamAcrossQuarterBeatBoundary() {
    let inputs = [
      input("before", onset: Rational(3, 16), duration: Rational(1, 16)),
      input("after", onset: Rational(1, 4), duration: Rational(1, 16)),
    ]

    XCTAssertTrue(BeamPlanner().groups(inputs: inputs).isEmpty)
  }

  private func input(
    _ id: String,
    onset: Rational,
    duration: Rational
  ) -> LayoutInput {
    LayoutInput(event: event(id, duration: duration), voiceID: "voice", onset: onset)
  }

  private func event(_ id: String, duration: Rational) -> NotationEvent {
    NotationEvent(
      id: NotationEventID(rawValue: id),
      content: .notes([
        NotatedPitch(midi: MIDIPitch(rawValue: 60), step: .c, octave: 4)
      ]),
      duration: duration,
      staffID: "treble"
    )
  }
}

extension Array {
  fileprivate var only: Element? {
    count == 1 ? self[0] : nil
  }
}
