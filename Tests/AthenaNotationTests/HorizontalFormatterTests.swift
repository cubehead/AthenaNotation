import AthenaNotationCore
import AthenaNotationLayout
import XCTest

final class HorizontalFormatterTests: XCTestCase {
  func testEventsAtSameMusicalTimeShareAContextAndXPosition() throws {
    let upper = NotationVoice(
      id: "upper",
      events: [
        event("upper-c", pitch: 60, duration: Rational(1, 4), staff: "treble"),
        event("upper-d", pitch: 62, duration: Rational(1, 4), staff: "treble"),
      ])
    let lower = NotationVoice(
      id: "lower",
      events: [
        event("lower-c", pitch: 48, duration: Rational(1, 2), staff: "bass")
      ])

    let formatter = HorizontalFormatter()
    let layout = formatter.format(
      inputs: formatter.makeInputs(voices: [upper, lower]), justifyTo: 400)

    XCTAssertEqual(layout.contexts.count, 2)
    XCTAssertEqual(layout.contexts[0].inputs.count, 2)

    let firstUpper = try XCTUnwrap(layout.events.first { $0.input.event.id.rawValue == "upper-c" })
    let firstLower = try XCTUnwrap(layout.events.first { $0.input.event.id.rawValue == "lower-c" })
    XCTAssertEqual(firstUpper.x, firstLower.x, accuracy: 0.0001)
  }

  func testJustificationPreservesMinimumCollisionSpacing() {
    let voice = NotationVoice(
      id: "upper",
      events: [
        event("a", pitch: 60, duration: Rational(1, 2), staff: "treble"),
        event("b", pitch: 62, duration: Rational(1, 4), staff: "treble"),
        event("c", pitch: 64, duration: Rational(1, 4), staff: "treble"),
      ])
    let formatter = HorizontalFormatter(options: .init(minimumContextGap: 8))
    let layout = formatter.format(inputs: formatter.makeInputs(voices: [voice]), justifyTo: 500)

    XCTAssertEqual(layout.width, 500, accuracy: 0.0001)
    XCTAssertGreaterThan(layout.contexts[1].x - layout.contexts[0].x, 18)
    XCTAssertGreaterThan(layout.contexts[2].x - layout.contexts[1].x, 18)
  }

  private func event(
    _ id: String,
    pitch: UInt8,
    duration: Rational,
    staff: String
  ) -> NotationEvent {
    NotationEvent(
      id: NotationEventID(rawValue: id),
      content: .notes([
        NotatedPitch(
          midi: MIDIPitch(rawValue: pitch),
          step: .c,
          octave: 4
        )
      ]),
      duration: duration,
      staffID: staff
    )
  }
}
