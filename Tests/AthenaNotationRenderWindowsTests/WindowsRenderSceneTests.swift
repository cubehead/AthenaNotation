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

@Test func windowsFacadeExposesAdaptiveSystemGeometry() {
  let events = (0..<16).map { index in
    NotationEvent(
      id: .init(rawValue: "windows-adaptive-\(index)"),
      content: .notes([NotatedPitch(
        midi: MIDIPitch(rawValue: UInt8(60 + index % 5)),
        step: [.c, .d, .e, .f, .g][index % 5],
        octave: 4
      )]),
      duration: Rational(1, 4),
      staffID: "treble"
    )
  }
  let score = NotationScore(
    staves: [NotationStaff(id: "treble", clef: .treble)],
    voices: [NotationVoice(id: "right", events: events)]
  )
  let scene = WindowsScoreRenderer(options: .init(
    width: 360,
    height: 180,
    accessibilityLocaleIdentifier: "en_US",
    showsPlaybackCursor: true,
    automaticSystemBreaks: true,
    minimumSystemHeight: 180
  )).render(score: score)

  #expect(scene.systems.count > 1)
  #expect(scene.systems.indices.allSatisfy { scene.systems[$0].index == $0 })
}
