import AthenaMIDI
import AthenaNotationCore
import Foundation
import XCTest

final class MIDIFileImporterTests: XCTestCase {
  func testTypeOneImportsTempoHandsChordsAndDuration() throws {
    let conductor: [UInt8] = [
      0x00, 0xFF, 0x03, 0x05, 0x50, 0x69, 0x61, 0x6E, 0x6F,
      0x00, 0xFF, 0x51, 0x03, 0x07, 0xA1, 0x20,
      0x00, 0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08,
      0x00, 0xFF, 0x2F, 0x00,
    ]
    let notes: [UInt8] = [
      0x00, 0x90, 0x3C, 0x64,
      0x00, 0x90, 0x40, 0x64,
      0x83, 0x60, 0x80, 0x3C, 0x00,
      0x00, 0x80, 0x40, 0x00,
      0x00, 0x90, 0x30, 0x50,
      0x83, 0x60, 0x80, 0x30, 0x00,
      0x00, 0xFF, 0x2F, 0x00,
    ]
    let result = try MIDIFileImporter().parse(
      data: midiFile(format: 1, ppqn: 480, tracks: [conductor, notes])
    )

    XCTAssertEqual(result.title, "Piano")
    XCTAssertEqual(result.tempoBPM, 120, accuracy: 0.001)
    XCTAssertEqual(result.score.staves.map(\.clef), [.treble, .bass])
    XCTAssertTrue(result.score.voices.contains { $0.id.contains("right") })
    XCTAssertTrue(result.score.voices.contains { $0.id.contains("left") })

    let noteEvents = result.score.voices.flatMap(\.events).filter {
      if case .notes = $0.content { return true }
      return false
    }
    XCTAssertEqual(noteEvents.count, 2)
    guard case .notes(let chord) = noteEvents.first?.content else {
      return XCTFail("Expected first event to be a chord")
    }
    XCTAssertEqual(chord.map(\.midi.rawValue), [60, 64])
    XCTAssertEqual(noteEvents.first?.duration, Rational(1, 4))
    XCTAssertEqual(noteEvents.first?.velocity, 100)
    XCTAssertEqual(result.score.barlines.last?.style, .final)
  }

  func testRunningStatusAndTempoChangeArePreserved() throws {
    let track: [UInt8] = [
      0x00, 0x90, 0x3C, 0x50,
      0x81, 0x70, 0x3C, 0x00,
      0x00, 0xFF, 0x51, 0x03, 0x0F, 0x42, 0x40,
      0x00, 0x90, 0x3E, 0x50,
      0x81, 0x70, 0x3E, 0x00,
      0x00, 0xFF, 0x2F, 0x00,
    ]
    let result = try MIDIFileImporter().parse(
      data: midiFile(format: 0, ppqn: 480, tracks: [track])
    )

    XCTAssertEqual(result.score.tempoChanges.count, 2)
    XCTAssertEqual(result.score.tempoChanges[0].beatsPerMinute, 120, accuracy: 0.001)
    XCTAssertEqual(result.score.tempoChanges[1].onset, Rational(1, 8))
    XCTAssertEqual(result.score.tempoChanges[1].beatsPerMinute, 60, accuracy: 0.001)
  }

  func testRejectsSMPTETimeDivision() {
    XCTAssertThrowsError(
      try MIDIFileImporter().parse(
        data: midiFile(format: 0, ppqn: 0xE728, tracks: [[0, 0xFF, 0x2F, 0]])
      )
    ) { error in
      XCTAssertEqual(error as? MIDIImportError, .unsupportedSMPTETimeDivision)
    }
  }

  private func midiFile(format: UInt16, ppqn: UInt16, tracks: [[UInt8]]) -> Data {
    var bytes = Array("MThd".utf8)
    bytes += be32(6)
    bytes += be16(format)
    bytes += be16(UInt16(tracks.count))
    bytes += be16(ppqn)
    for track in tracks {
      bytes += Array("MTrk".utf8)
      bytes += be32(UInt32(track.count))
      bytes += track
    }
    return Data(bytes)
  }

  private func be16(_ value: UInt16) -> [UInt8] {
    [UInt8(value >> 8), UInt8(value & 0xFF)]
  }

  private func be32(_ value: UInt32) -> [UInt8] {
    [
      UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF),
      UInt8(value & 0xFF),
    ]
  }
}
