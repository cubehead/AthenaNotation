import AthenaNotationCore
import AthenaNotationLayout
import XCTest

final class AccidentalPlannerTests: XCTestCase {
  func testKeySignatureMapsCircleOfFifthsOrder() {
    let dMajor = KeySignature(fifths: 2)
    let eFlatMajor = KeySignature(fifths: -3)

    XCTAssertEqual(dMajor.accidental(for: .f), .sharp)
    XCTAssertEqual(dMajor.accidental(for: .c), .sharp)
    XCTAssertNil(dMajor.accidental(for: .g))
    XCTAssertEqual(eFlatMajor.accidental(for: .b), .flat)
    XCTAssertEqual(eFlatMajor.accidental(for: .e), .flat)
    XCTAssertEqual(eFlatMajor.accidental(for: .a), .flat)
  }

  func testAccidentalMemoryResetsAtMeasureBoundary() {
    let inputs = [
      input("natural-first", onset: .zero, accidental: .natural),
      input("natural-repeat", onset: Rational(1, 4), accidental: .natural),
      input("sharp-restore", onset: Rational(1, 2), accidental: .sharp),
      input("natural-next-measure", onset: .one, accidental: .natural),
    ]
    let staff = NotationStaff(id: "treble", clef: .treble, keySignature: .gMajor)

    let visible = AccidentalPlanner().visibleAccidentals(inputs: inputs, staves: [staff])

    XCTAssertEqual(visible[eventID("natural-first")]?.first?.accidental, .natural)
    XCTAssertNil(visible[eventID("natural-repeat")])
    XCTAssertEqual(visible[eventID("sharp-restore")]?.first?.accidental, .sharp)
    XCTAssertEqual(visible[eventID("natural-next-measure")]?.first?.accidental, .natural)
  }

  func testExplicitAccidentalMatchingKeySignatureIsSuppressed() {
    let visible = AccidentalPlanner().visibleAccidentals(
      inputs: [input("f-sharp", onset: .zero, accidental: .sharp)],
      staves: [NotationStaff(id: "treble", clef: .treble, keySignature: .gMajor)]
    )

    XCTAssertNil(visible[eventID("f-sharp")])
  }

  private func input(
    _ id: String,
    onset: Rational,
    accidental: AccidentalKind
  ) -> LayoutInput {
    LayoutInput(
      event: NotationEvent(
        id: eventID(id),
        content: .notes([
          NotatedPitch(
            midi: MIDIPitch(rawValue: accidental == .natural ? 77 : 78),
            step: .f,
            octave: 5,
            accidental: accidental
          )
        ]),
        duration: Rational(1, 4),
        staffID: "treble"
      ),
      voiceID: "voice",
      onset: onset
    )
  }

  private func eventID(_ value: String) -> NotationEventID {
    NotationEventID(rawValue: value)
  }
}
