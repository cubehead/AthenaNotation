import AthenaNotationCore
import XCTest

final class NotationExtensionTests: XCTestCase {
  func testFingeringCanTargetOneNoteheadInAChord() {
    let fingering = NotationAttachment(
      id: "finger-e4",
      anchor: .notehead(index: 1),
      placement: .above,
      content: .fingering(.middle)
    )
    let chord = NotationEvent(
      id: NotationEventID(rawValue: "c-major"),
      content: .notes([
        NotatedPitch(midi: MIDIPitch(rawValue: 60), step: .c, octave: 4),
        NotatedPitch(midi: MIDIPitch(rawValue: 64), step: .e, octave: 4),
        NotatedPitch(midi: MIDIPitch(rawValue: 67), step: .g, octave: 4),
      ]),
      duration: Rational(1, 4),
      staffID: "treble",
      hand: .right,
      attachments: [fingering]
    )

    XCTAssertEqual(chord.attachments.first?.anchor, .notehead(index: 1))
    XCTAssertEqual(chord.attachments.first?.content, .fingering(.middle))
  }

  func testUnknownModernSymbolAndSpannerKindsRemainRepresentable() {
    let symbol = NotationAttachment(
      id: "custom-symbol",
      content: .smuflGlyph(name: "wiggleVibratoLargestFastest")
    )
    let spannerKind = NotationSpannerKind(rawValue: "custom.electroacoustic.region")

    XCTAssertEqual(symbol.content, .smuflGlyph(name: "wiggleVibratoLargestFastest"))
    XCTAssertEqual(spannerKind.rawValue, "custom.electroacoustic.region")
  }

  func testSingleAndDoubleDotsKeepExactWrittenSpan() {
    let dottedQuarter = eventWithDots(1)
    let doubleDottedQuarter = eventWithDots(2)

    XCTAssertEqual(dottedQuarter.dottedWrittenDuration, Rational(3, 8))
    XCTAssertEqual(doubleDottedQuarter.dottedWrittenDuration, Rational(7, 16))
  }

  private func eventWithDots(_ dotCount: UInt8) -> NotationEvent {
    NotationEvent(
      id: NotationEventID(rawValue: "dots-\(dotCount)"),
      content: .notes([
        NotatedPitch(midi: MIDIPitch(rawValue: 60), step: .c, octave: 4)
      ]),
      duration: dotCount == 1 ? Rational(3, 8) : Rational(7, 16),
      writtenDuration: Rational(1, 4),
      dotCount: dotCount,
      staffID: "treble"
    )
  }
}
