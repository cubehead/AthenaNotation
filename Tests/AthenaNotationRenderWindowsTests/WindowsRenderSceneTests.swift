import AthenaNotationCore
import AthenaNotationRenderWindows
import Testing

@Test func windowsRendererProducesPortableDisplayList() throws {
  let eventID = NotationEventID(rawValue: "windows-test-c4")
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

  let scene = WindowsScoreRenderer(options: .init(width: 800, height: 320))
    .render(score: score, playbackEventIDs: [eventID])

  #expect(scene.commands.contains { $0.role == "notehead" })
  #expect(scene.commands.contains { $0.role == "playbackHighlight" })
  #expect(try scene.jsonString().contains("windows-test-c4"))

  let scoreOnlyScene = WindowsScoreRenderer(options: .init(
    width: 800,
    height: 320,
    accessibilityLocaleIdentifier: "en_US",
    showsPlaybackCursor: false
  )).render(score: score, playbackEventIDs: [eventID])
  #expect(!scoreOnlyScene.commands.contains { $0.role == "playbackHighlight" })
}
