import AthenaNotationCore
import AthenaNotationRenderApple
import XCTest

final class SMuFLGlyphTests: XCTestCase {
  func testAugmentationDotUsesSMuFLCodepoint() {
    XCTAssertEqual(SMuFLGlyph.augmentationDot.rawValue, 0xE1E7)
    XCTAssertEqual(SMuFLGlyph.named("augmentationDot"), .augmentationDot)
    let bounds = BravuraFont.metrics(for: .augmentationDot, size: 40)?.bounds
    XCTAssertGreaterThan(bounds?.width ?? 0, 3)
    XCTAssertGreaterThan(bounds?.height ?? 0, 3)
  }
  func testBravuraRegistersAndContainsCoreGlyphs() {
    XCTAssertTrue(BravuraFont.isRegistered)
    XCTAssertTrue(BravuraFont.contains(.gClef))
    XCTAssertTrue(BravuraFont.contains(.noteheadBlack))
    XCTAssertTrue(BravuraFont.contains(.restQuarter))
    XCTAssertTrue(BravuraFont.contains(.flag8thUp))
    XCTAssertTrue(BravuraFont.contains(.flag16thDown))
  }

  func testBlackNoteheadExposesRealBoundsForStemAttachment() throws {
    let metrics = try XCTUnwrap(BravuraFont.metrics(for: .noteheadBlack, size: 30))
    let path = try XCTUnwrap(BravuraFont.path(for: .noteheadBlack, size: 30))

    XCTAssertEqual(metrics.bounds.width, 8.85, accuracy: 0.1)
    XCTAssertEqual(metrics.bounds.height, 7.5, accuracy: 0.1)
    XCTAssertEqual(metrics.advance.width, metrics.bounds.width, accuracy: 0.1)
    XCTAssertEqual(path.boundingBoxOfPath.width, metrics.bounds.width, accuracy: 0.1)
    XCTAssertEqual(path.boundingBoxOfPath.height, metrics.bounds.height, accuracy: 0.1)
  }

  func testAccidentalsMapToExpectedSMuFLCodepoints() {
    XCTAssertEqual(SMuFLGlyph.accidental(.flat)?.rawValue, 0xE260)
    XCTAssertEqual(SMuFLGlyph.accidental(.sharp)?.rawValue, 0xE262)
    XCTAssertEqual(SMuFLGlyph.accidental(.doubleSharp)?.rawValue, 0xE263)
  }

  func testFlagCodepointsFollowSMuFLUpDownPairs() {
    XCTAssertEqual(SMuFLGlyph.flag8thUp.rawValue, 0xE240)
    XCTAssertEqual(SMuFLGlyph.flag8thDown.rawValue, SMuFLGlyph.flag8thUp.rawValue + 1)
    XCTAssertEqual(SMuFLGlyph.flag16thUp.rawValue, 0xE242)
    XCTAssertEqual(SMuFLGlyph.flag16thDown.rawValue, SMuFLGlyph.flag16thUp.rawValue + 1)
  }

  func testPitchSpellingIsIndependentFromSoundingMIDIPitch() {
    let cSharp = NotatedPitch(
      midi: MIDIPitch(rawValue: 61),
      step: .c,
      octave: 4,
      accidental: .sharp
    )
    let dFlat = NotatedPitch(
      midi: MIDIPitch(rawValue: 61),
      step: .d,
      octave: 4,
      accidental: .flat
    )

    XCTAssertEqual(cSharp.midi, dFlat.midi)
    XCTAssertNotEqual(cSharp.diatonicIndex, dFlat.diatonicIndex)
  }
}
