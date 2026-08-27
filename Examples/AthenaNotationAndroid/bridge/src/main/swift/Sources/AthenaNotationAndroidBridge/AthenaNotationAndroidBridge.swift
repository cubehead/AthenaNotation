import Android
import AthenaMIDI
import AthenaMusicXML
import AthenaNotationCore
import AthenaNotationRenderAndroid
import Foundation

@_cdecl("Java_io_github_cubehead_athenanotation_SwiftNotation_healthCheck")
public func healthCheck(
  env: UnsafeMutablePointer<JNIEnv?>,
  receiver: jobject
) -> jstring {
  makeJavaString("AthenaNotation Swift Android bridge OK", env: env)
}

@_cdecl("Java_io_github_cubehead_athenanotation_SwiftNotation_renderMusicXMLFixture")
public func renderMusicXMLFixture(
  env: UnsafeMutablePointer<JNIEnv?>,
  receiver: jobject
) -> jstring {
  makeJavaString(renderMusicXMLScene(), env: env)
}

@_cdecl("Java_io_github_cubehead_athenanotation_SwiftNotation_renderMIDIFixture")
public func renderMIDIFixture(
  env: UnsafeMutablePointer<JNIEnv?>,
  receiver: jobject
) -> jstring {
  makeJavaString(renderMIDIScene(), env: env)
}

private func renderMusicXMLScene() -> String {
  let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <score-partwise version="4.0">
      <part-list>
        <score-part id="P1"><part-name>Piano</part-name></score-part>
      </part-list>
      <part id="P1">
        <measure number="1">
          <attributes>
            <divisions>4</divisions>
            <key><fifths>0</fifths></key>
            <time><beats>4</beats><beat-type>4</beat-type></time>
            <staves>2</staves>
            <clef number="1"><sign>G</sign><line>2</line></clef>
            <clef number="2"><sign>F</sign><line>4</line></clef>
          </attributes>
          <note>
            <pitch><step>C</step><octave>5</octave></pitch>
            <duration>2</duration><voice>1</voice><type>eighth</type><staff>1</staff>
            <notations><technical><fingering>1</fingering></technical></notations>
          </note>
          <note>
            <pitch><step>D</step><octave>5</octave></pitch>
            <duration>2</duration><voice>1</voice><type>eighth</type><dot/><staff>1</staff>
          </note>
          <backup><duration>4</duration></backup>
          <note>
            <pitch><step>C</step><octave>3</octave></pitch>
            <duration>4</duration><voice>2</voice><type>quarter</type><staff>2</staff>
          </note>
          <barline location="right"><bar-style>light-heavy</bar-style></barline>
        </measure>
      </part>
    </score-partwise>
    """
  do {
    let imported = try MusicXMLImporter().parse(data: Data(xml.utf8))
    let highlighted = imported.score.voices.first?.events.first.map { Set([$0.id]) } ?? []
    return try AndroidScoreRenderer(options: .init(
      width: 1_024,
      height: 720,
      preferredSystemCount: 1
    )).renderJSON(score: imported.score, playbackEventIDs: highlighted)
  } catch {
    return errorJSON("MusicXML: \(error)")
  }
}

private func renderMIDIScene() -> String {
  let midi: [UInt8] = [
    0x4D, 0x54, 0x68, 0x64, 0, 0, 0, 6, 0, 0, 0, 1, 0x01, 0xE0,
    0x4D, 0x54, 0x72, 0x6B, 0, 0, 0, 0x14,
    0, 0xFF, 0x51, 3, 0x07, 0xA1, 0x20,
    0, 0x90, 60, 100,
    0x83, 0x60, 0x80, 60, 0,
    0, 0xFF, 0x2F, 0,
  ]
  do {
    let imported = try MIDIFileImporter().parse(data: Data(midi))
    return try AndroidScoreRenderer(options: .init(width: 1_024, height: 480))
      .renderJSON(score: imported.score)
  } catch {
    return errorJSON("MIDI: \(error)")
  }
}

private func errorJSON(_ message: String) -> String {
  let escaped = message
    .replacingOccurrences(of: "\\", with: "\\\\")
    .replacingOccurrences(of: "\"", with: "\\\"")
  return "{\"error\":\"\(escaped)\"}"
}

private func makeJavaString(
  _ value: String,
  env: UnsafeMutablePointer<JNIEnv?>
) -> jstring {
  value.withCString { pointer in
    env.pointee!.pointee.NewStringUTF(env, pointer)!
  }
}
