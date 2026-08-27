import AthenaMusicXML
import AthenaNotationCore
import Foundation
import XCTest

final class MusicXMLImporterTests: XCTestCase {
  func testBundledPianoFixtureImportsWithoutThirdPartyRenderer() throws {
    let fixture = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent(
        "Examples/AthenaNotationExample/Resources/athena-demo.musicxml"
      )
    let result = try MusicXMLImporter().parse(data: Data(contentsOf: fixture))

    XCTAssertEqual(result.title, "Athena MusicXML Import")
    XCTAssertEqual(result.tempoBPM, 80)
    XCTAssertEqual(result.score.staves.count, 2)
    XCTAssertEqual(result.score.staves.map(\.clef), [.treble, .bass])
    XCTAssertEqual(result.score.voices.count, 2)
    XCTAssertEqual(result.score.voices[0].events.count, 9)
    XCTAssertEqual(result.score.voices[1].events.count, 4)
    XCTAssertTrue(result.score.voices[0].events.allSatisfy { $0.hand == .right })
    XCTAssertTrue(result.score.voices[1].events.allSatisfy { $0.hand == .left })
    XCTAssertTrue(result.score.barlines.contains { $0.style == .repeatEnd })
    XCTAssertEqual(result.score.barlines.last?.style, .final)
    XCTAssertEqual(result.score.voltas.map(\.numbers), [[1], [2]])
    XCTAssertTrue(result.diagnostics.isEmpty)
  }

  func testChordDotsAccidentalAndBackupKeepNativeNotationSemantics() throws {
    let xml = """
      <score-partwise version="4.0">
        <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
        <part id="P1"><measure number="1">
          <attributes><divisions>8</divisions><staves>2</staves>
            <key><fifths>1</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time>
            <clef number="1"><sign>G</sign></clef><clef number="2"><sign>F</sign></clef>
          </attributes>
          <note><pitch><step>F</step><alter>1</alter><octave>4</octave></pitch>
            <duration>12</duration><voice>1</voice><type>quarter</type><dot/><staff>1</staff></note>
          <note><chord/><pitch><step>A</step><octave>4</octave></pitch>
            <duration>12</duration><voice>1</voice><type>quarter</type><dot/><staff>1</staff></note>
          <backup><duration>12</duration></backup>
          <note><rest/><duration>8</duration><voice>2</voice><type>quarter</type><staff>2</staff></note>
        </measure></part>
      </score-partwise>
      """

    let result = try MusicXMLImporter().parse(data: Data(xml.utf8))
    let upper = try XCTUnwrap(result.score.voices.first { $0.id.contains("staff-1") })
    let lower = try XCTUnwrap(result.score.voices.first { $0.id.contains("staff-2") })
    let chord = try XCTUnwrap(upper.events.first)

    guard case .notes(let pitches) = chord.content else { return XCTFail("Expected chord") }
    XCTAssertEqual(pitches.count, 2)
    XCTAssertEqual(pitches[0].accidental, .sharp)
    XCTAssertEqual(chord.duration, Rational(3, 8))
    XCTAssertEqual(chord.writtenDuration, Rational(1, 4))
    XCTAssertEqual(chord.dotCount, 1)
    XCTAssertEqual(lower.events.first?.content, .rest)
  }

  func testTupletSpannersRepeatsVoltaAndFingeringRemainSemantic() throws {
    let xml = """
      <score-partwise version="4.0">
        <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
        <part id="P1"><measure number="1">
          <attributes><divisions>12</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
          <barline location="left"><repeat direction="forward"/><ending number="1" type="start"/></barline>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type>
            <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>
            <tie type="start"/><notations><slur number="1" type="start"/><tuplet number="1" type="start"/>
            <technical><fingering>1</fingering></technical></notations></note>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type>
            <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification><tie type="stop"/></note>
          <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>eighth</type>
            <time-modification><actual-notes>3</actual-notes><normal-notes>2</normal-notes></time-modification>
            <notations><slur number="1" type="stop"/><tuplet number="1" type="stop"/></notations></note>
          <barline location="right"><repeat direction="backward" times="3"/>
            <ending number="1" type="stop"/></barline>
        </measure></part>
      </score-partwise>
      """

    let result = try MusicXMLImporter().parse(data: Data(xml.utf8))
    let tuplet = try XCTUnwrap(result.score.tuplets.first)

    XCTAssertEqual(tuplet.actualCount, 3)
    XCTAssertEqual(tuplet.normalCount, 2)
    XCTAssertEqual(tuplet.eventIDs.count, 3)
    XCTAssertEqual(
      result.score.spanners.map(\.kind).sorted { $0.rawValue < $1.rawValue }, [.slur, .tie])
    XCTAssertEqual(result.score.barlines.first?.style, .repeatStart)
    XCTAssertEqual(result.score.barlines.last?.style, .repeatEnd)
    XCTAssertEqual(result.score.barlines.last?.repeatCount, 3)
    XCTAssertEqual(result.score.voltas.first?.numbers, [1])
    XCTAssertEqual(result.score.voices.first?.events.first?.attachments.count, 1)
    XCTAssertTrue(result.diagnostics.isEmpty)
  }

  func testTempoDirectionsBecomeExactScoreTimelineChanges() throws {
    let xml = """
      <score-partwise version="4.0">
        <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
        <part id="P1">
          <measure number="1">
            <attributes><divisions>4</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
            <direction><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>120</per-minute></metronome></direction-type><sound tempo="120"/></direction>
            <note><rest/><duration>16</duration><voice>1</voice><type>whole</type></note>
          </measure>
          <measure number="2">
            <direction><direction-type><metronome><beat-unit>quarter</beat-unit><per-minute>72</per-minute></metronome></direction-type><sound tempo="72"/></direction>
            <note><rest/><duration>16</duration><voice>1</voice><type>whole</type></note>
          </measure>
        </part>
      </score-partwise>
      """

    let result = try MusicXMLImporter().parse(data: Data(xml.utf8))
    XCTAssertEqual(result.tempoBPM, 120)
    XCTAssertEqual(result.score.tempoChanges.count, 2)
    XCTAssertEqual(result.score.tempoChanges[0].onset, .zero)
    XCTAssertEqual(result.score.tempoChanges[0].beatsPerMinute, 120)
    XCTAssertEqual(result.score.tempoChanges[1].onset, .one)
    XCTAssertEqual(result.score.tempoChanges[1].beatsPerMinute, 72)
  }

  func testCommonDirectionsSymbolsLyricsAndRangesRemainSemantic() throws {
    let xml = """
      <score-partwise version="4.0">
        <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
        <part id="P1"><measure number="1">
          <attributes><divisions>4</divisions><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
          <direction placement="below"><direction-type><dynamics><mf/></dynamics><wedge number="1" type="crescendo"/></direction-type><sound dynamics="70"/><staff>1</staff></direction>
          <direction placement="above"><direction-type><octave-shift number="1" type="down" size="8"/></direction-type><staff>1</staff></direction>
          <note><pitch><step>C</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff>
            <notations><articulations><staccato placement="above"/></articulations><ornaments><trill-mark/></ornaments><fermata/><arpeggiate/>
              <technical><up-bow/></technical><glissando number="1" type="start"/></notations>
            <lyric number="1"><syllabic>begin</syllabic><text>A</text></lyric></note>
          <direction placement="above"><direction-type><words>dolce</words><rehearsal>A</rehearsal><pedal number="1" type="start"/></direction-type><staff>1</staff></direction>
          <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff>
            <notations><glissando number="1" type="stop"/></notations></note>
          <direction placement="below"><direction-type><wedge number="1" type="stop"/></direction-type><staff>1</staff></direction>
          <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
          <direction placement="below"><direction-type><pedal number="1" type="stop"/><octave-shift number="1" type="stop"/></direction-type><staff>1</staff></direction>
          <note><pitch><step>F</step><octave>4</octave></pitch><duration>4</duration><voice>1</voice><type>quarter</type><staff>1</staff></note>
        </measure></part>
      </score-partwise>
      """

    let result = try MusicXMLImporter().parse(data: Data(xml.utf8))
    let events = try XCTUnwrap(result.score.voices.first?.events)
    let firstAttachments = events[0].attachments.map(\.content)
    let secondAttachments = events[1].attachments.map(\.content)

    XCTAssertTrue(firstAttachments.contains(.dynamic(label: "mf", velocity: 89)))
    XCTAssertTrue(firstAttachments.contains(.smuflGlyph(name: "articStaccatoAbove")))
    XCTAssertTrue(firstAttachments.contains(.smuflGlyph(name: "ornamentTrill")))
    XCTAssertTrue(firstAttachments.contains(.smuflGlyph(name: "fermataAbove")))
    XCTAssertTrue(firstAttachments.contains(.technique(name: "arpeggio")))
    XCTAssertTrue(firstAttachments.contains(.technique(name: "up-bow")))
    XCTAssertTrue(firstAttachments.contains(.text("A-")))
    XCTAssertTrue(secondAttachments.contains(.text("dolce")))
    XCTAssertTrue(secondAttachments.contains(.technique(name: "A")))
    XCTAssertEqual(
      Set(result.score.spanners.map(\.kind)),
      Set([.crescendo, .pedal, .ottava, .glissando])
    )
    XCTAssertTrue(result.diagnostics.isEmpty)
  }
}
