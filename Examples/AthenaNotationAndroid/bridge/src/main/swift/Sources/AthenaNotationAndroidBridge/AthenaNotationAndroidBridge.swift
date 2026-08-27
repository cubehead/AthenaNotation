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

@_cdecl("Java_io_github_cubehead_athenanotation_SwiftNotation_renderMusicXML")
public func renderMusicXML(
  env: UnsafeMutablePointer<JNIEnv?>,
  receiver: jobject,
  musicXML: jstring
) -> jstring {
  guard let xml = readJavaString(musicXML, env: env) else {
    return makeJavaString(errorJSON("MusicXML: invalid UTF-8 input"), env: env)
  }
  return makeJavaString(renderMusicXMLScene(xml), env: env)
}

@_cdecl("Java_io_github_cubehead_athenanotation_SwiftNotation_renderMIDI")
public func renderMIDI(
  env: UnsafeMutablePointer<JNIEnv?>,
  receiver: jobject,
  midiData: jbyteArray
) -> jstring {
  guard let data = readJavaBytes(midiData, env: env) else {
    return makeJavaString(errorJSON("MIDI: invalid byte array"), env: env)
  }
  return makeJavaString(renderMIDIScene(data), env: env)
}

private func renderMusicXMLScene(_ xml: String) -> String {
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

private func renderMIDIScene(_ midi: Data) -> String {
  do {
    let imported = try MIDIFileImporter().parse(data: midi)
    return try AndroidScoreRenderer(options: .init(width: 1_024, height: 480))
      .renderJSON(score: imported.score)
  } catch {
    return errorJSON("MIDI: \(error)")
  }
}

private func readJavaString(
  _ value: jstring,
  env: UnsafeMutablePointer<JNIEnv?>
) -> String? {
  guard let characters = env.pointee!.pointee.GetStringUTFChars(env, value, nil) else {
    return nil
  }
  defer { env.pointee!.pointee.ReleaseStringUTFChars(env, value, characters) }
  return String(cString: characters)
}

private func readJavaBytes(
  _ value: jbyteArray,
  env: UnsafeMutablePointer<JNIEnv?>
) -> Data? {
  let count = Int(env.pointee!.pointee.GetArrayLength(env, value))
  guard let bytes = env.pointee!.pointee.GetByteArrayElements(env, value, nil) else {
    return nil
  }
  defer { env.pointee!.pointee.ReleaseByteArrayElements(env, value, bytes, 2) }
  return Data(bytes: bytes, count: count)
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
