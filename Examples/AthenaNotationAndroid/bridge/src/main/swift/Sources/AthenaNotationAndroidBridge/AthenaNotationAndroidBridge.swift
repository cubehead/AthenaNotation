import Android
import AthenaMIDI
import AthenaMusicXML
import AthenaNotationCore
import AthenaNotationRenderAndroid
import AthenaScoreAnalysis
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

@_cdecl("Java_io_github_cubehead_athenanotation_SwiftNotation_renderMusicXMLWithCursorVisibility")
public func renderMusicXMLWithCursorVisibility(
  env: UnsafeMutablePointer<JNIEnv?>,
  receiver: jobject,
  musicXML: jstring,
  showsPlaybackCursor: jboolean
) -> jstring {
  guard let xml = readJavaString(musicXML, env: env) else {
    return makeJavaString(errorJSON("MusicXML: invalid UTF-8 input"), env: env)
  }
  return makeJavaString(
    renderMusicXMLScene(xml, showsPlaybackCursor: showsPlaybackCursor != 0),
    env: env
  )
}

@_cdecl("Java_io_github_cubehead_athenanotation_SwiftNotation_renderMusicXMLAtEvent")
public func renderMusicXMLAtEvent(
  env: UnsafeMutablePointer<JNIEnv?>,
  receiver: jobject,
  musicXML: jstring,
  eventID: jstring
) -> jstring {
  guard
    let xml = readJavaString(musicXML, env: env),
    let rawEventID = readJavaString(eventID, env: env)
  else {
    return makeJavaString(errorJSON("MusicXML interaction: invalid UTF-8 input"), env: env)
  }
  return makeJavaString(
    renderMusicXMLScene(xml, highlightedEventID: rawEventID),
    env: env
  )
}

@_cdecl("Java_io_github_cubehead_athenanotation_SwiftNotation_renderMusicXMLAtEventWithCursorVisibility")
public func renderMusicXMLAtEventWithCursorVisibility(
  env: UnsafeMutablePointer<JNIEnv?>,
  receiver: jobject,
  musicXML: jstring,
  eventID: jstring,
  showsPlaybackCursor: jboolean
) -> jstring {
  guard
    let xml = readJavaString(musicXML, env: env),
    let rawEventID = readJavaString(eventID, env: env)
  else {
    return makeJavaString(errorJSON("MusicXML interaction: invalid UTF-8 input"), env: env)
  }
  return makeJavaString(
    renderMusicXMLScene(
      xml,
      highlightedEventID: rawEventID,
      showsPlaybackCursor: showsPlaybackCursor != 0
    ),
    env: env
  )
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

@_cdecl("Java_io_github_cubehead_athenanotation_SwiftNotation_resolveABStep")
public func resolveABStep(
  env: UnsafeMutablePointer<JNIEnv?>,
  receiver: jobject,
  position: jdouble,
  duration: jdouble,
  elapsedSeconds: jdouble,
  beatsPerMinute: jdouble,
  loopStart: jdouble,
  loopEnd: jdouble,
  countInOnLoop: jboolean
) -> jstring {
  let range = ScoreABLoopRange(
    start: loopStart,
    end: loopEnd,
    scoreDuration: duration
  )
  let advance = ScorePlaybackClock.advance(
    position: position,
    duration: duration,
    elapsedSeconds: elapsedSeconds,
    beatsPerMinute: beatsPerMinute,
    rate: 1,
    loops: range != nil,
    loopRange: range?.range
  )
  let step = ScorePlaybackStepPlanner.resolve(
    advance,
    loopRange: range,
    countInOnLoop: countInOnLoop != 0
  )
  return makeJavaString(playbackStepJSON(step), env: env)
}

@_cdecl("Java_io_github_cubehead_athenanotation_SwiftNotation_countInDuration")
public func countInDuration(
  env: UnsafeMutablePointer<JNIEnv?>,
  receiver: jobject,
  beats: jint,
  beatType: jint,
  beatsPerMinute: jdouble
) -> jdouble {
  ScoreCountInClock.durationSeconds(
    timeSignature: TimeSignature(
      numerator: UInt8(max(1, min(255, Int(beats)))),
      denominator: UInt8(max(1, min(255, Int(beatType))))
    ),
    beatsPerMinute: beatsPerMinute,
    rate: 1
  )
}

@_cdecl("Java_io_github_cubehead_athenanotation_SwiftNotation_countInBeat")
public func countInBeat(
  env: UnsafeMutablePointer<JNIEnv?>,
  receiver: jobject,
  remainingSeconds: jdouble,
  beats: jint,
  beatType: jint,
  beatsPerMinute: jdouble
) -> jint {
  jint(ScoreCountInClock.displayedBeat(
    remainingSeconds: remainingSeconds,
    timeSignature: TimeSignature(
      numerator: UInt8(max(1, min(255, Int(beats)))),
      denominator: UInt8(max(1, min(255, Int(beatType))))
    ),
    beatsPerMinute: beatsPerMinute,
    rate: 1
  ))
}

private func renderMusicXMLScene(
  _ xml: String,
  highlightedEventID: String? = nil,
  showsPlaybackCursor: Bool = true
) -> String {
  do {
    let imported = try MusicXMLImporter().parse(data: Data(xml.utf8))
    let highlighted: Set<NotationEventID>
    if let highlightedEventID {
      highlighted = [NotationEventID(rawValue: highlightedEventID)]
    } else {
      highlighted = imported.score.voices.first?.events.first.map { Set([$0.id]) } ?? []
    }
    return try AndroidScoreRenderer(options: .init(
      width: 1_024,
      height: 720,
      preferredSystemCount: 1,
      showsPlaybackCursor: showsPlaybackCursor
    )).renderJSON(score: imported.score, playbackEventIDs: highlighted)
  } catch {
    return errorJSON("MusicXML: \(error)")
  }
}

private func playbackStepJSON(_ step: ScorePlaybackStep) -> String {
  let reason: String
  switch step.reason {
  case .started: reason = "started"
  case .advanced: reason = "advanced"
  case .seeked: reason = "seeked"
  case .looped: reason = "looped"
  case .countInStarted: reason = "countInStarted"
  case .countInBeat(let beat): reason = "countInBeat(\(beat))"
  case .paused: reason = "paused"
  case .finished: reason = "finished"
  }
  let action: String
  let countInPosition: Double?
  switch step.nextAction {
  case .continuePlayback:
    action = "continuePlayback"
    countInPosition = nil
  case .beginCountIn(let position):
    action = "beginCountIn"
    countInPosition = position
  case .finish:
    action = "finish"
    countInPosition = nil
  }
  let payload: [String: Any] = [
    "position": step.position,
    "reason": reason,
    "action": action,
    "countInPosition": countInPosition.map { $0 as Any } ?? NSNull(),
  ]
  guard
    let data = try? JSONSerialization.data(withJSONObject: payload),
    let value = String(data: data, encoding: .utf8)
  else { return errorJSON("Playback step: JSON encoding failed") }
  return value
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
