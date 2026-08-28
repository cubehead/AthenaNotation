import AthenaMIDI
import AthenaMusicXML
import AthenaNotationCore
import AthenaNotationRenderWindows
import AthenaScoreAnalysis

let eventID = NotationEventID(rawValue: "windows-c4")
let score = NotationScore(
  staves: [NotationStaff(id: "treble", clef: .treble)],
  voices: [
    NotationVoice(
      id: "right",
      events: [
        NotationEvent(
          id: eventID,
          content: .notes([
            NotatedPitch(
              midi: MIDIPitch(rawValue: 60),
              step: .c,
              octave: 4
            )
          ]),
          duration: Rational(1, 4),
          staffID: "treble"
        )
      ])
  ]
)

let scene = WindowsScoreRenderer(options: .init(
  width: 800,
  height: 320,
  accessibilityLocaleIdentifier: "en_US",
  showsPlaybackCursor: true,
  automaticSystemBreaks: true
))
  .render(score: score, playbackEventIDs: [eventID])
let snapshot = ScorePlaybackEventPlanner(score: score).snapshot(at: .zero)

do {
  print(try scene.jsonString(prettyPrinted: true))
  print("Rendered \(scene.commands.count) commands; active notes: \(snapshot.activeMIDINotes)")
} catch {
  fatalError("Unable to encode the Windows render scene: \(error)")
}
