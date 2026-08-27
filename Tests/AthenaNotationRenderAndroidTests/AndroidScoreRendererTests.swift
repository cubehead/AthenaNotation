import AthenaNotationCore
import AthenaNotationRenderAndroid
import Foundation
import Testing

@Test func sceneContainsNotationPlaybackAndFinalBarline() throws {
  let firstID = NotationEventID(rawValue: "n1")
  let secondID = NotationEventID(rawValue: "n2")
  let score = NotationScore(
    staves: [NotationStaff(id: "treble", clef: .treble)],
    voices: [NotationVoice(id: "right", events: [
      NotationEvent(
        id: firstID,
        content: .notes([pitch(60, .c, 4)]),
        duration: Rational(1, 8),
        dotCount: 1,
        staffID: "treble",
        attachments: [NotationAttachment(id: "finger", content: .fingering(.thumb))]
      ),
      NotationEvent(
        id: secondID,
        content: .notes([pitch(62, .d, 4)]),
        duration: Rational(1, 8),
        staffID: "treble"
      ),
    ])],
    barlines: [NotationBarline(onset: Rational(1, 4), style: .final)]
  )
  let scene = AndroidScoreRenderer(options: .init(width: 600, height: 260))
    .render(score: score, playbackEventIDs: [firstID])

  #expect(scene.commands.contains { $0.role == "staffLine" })
  #expect(scene.commands.contains { $0.role == "notehead" && $0.eventID == "n1" })
  #expect(scene.commands.contains { $0.role == "augmentationDot" })
  #expect(scene.commands.contains { $0.role == "fingering" })
  #expect(scene.commands.contains { $0.role == "beam" })
  #expect(scene.commands.contains { $0.role == "playbackHighlight" })
  #expect(scene.commands.filter { $0.role == "barline" }.contains { $0.lineWidth == 4 })

  let json = try scene.jsonString()
  #expect(json.contains("playbackHighlight"))
  #expect(try JSONSerialization.jsonObject(with: Data(json.utf8)) is [String: Any])
}

@Test func renderSupportsGrandStaffAndSpanners() {
  let upperID = NotationEventID(rawValue: "upper")
  let upperEndID = NotationEventID(rawValue: "upper-end")
  let lowerID = NotationEventID(rawValue: "lower")
  let score = NotationScore(
    staves: [
      NotationStaff(id: "treble", clef: .treble),
      NotationStaff(id: "bass", clef: .bass),
    ],
    voices: [
      NotationVoice(id: "right", events: [
        NotationEvent(
          id: upperID, content: .notes([pitch(72, .c, 5)]),
          duration: Rational(1, 4), staffID: "treble"
        ),
        NotationEvent(
          id: upperEndID, content: .notes([pitch(74, .d, 5)]),
          duration: Rational(1, 4), staffID: "treble"
        ),
      ]),
      NotationVoice(id: "left", events: [NotationEvent(
        id: lowerID, content: .notes([pitch(48, .c, 3)]),
        duration: Rational(1, 4), staffID: "bass"
      )]),
    ],
    spanners: [NotationSpanner(
      id: "crescendo", kind: .crescendo,
      startEventID: upperID, endEventID: upperEndID, placement: .below
    )]
  )
  let scene = AndroidScoreRenderer(options: .init(width: 600, height: 360))
    .render(score: score)

  #expect(scene.commands.filter { $0.role == "staffLine" }.count == 10)
  #expect(scene.commands.filter { $0.role == "clef" }.count == 2)
  #expect(scene.commands.contains { $0.role == "hairpin" })
}

private func pitch(_ midi: UInt8, _ step: DiatonicStep, _ octave: Int) -> NotatedPitch {
  NotatedPitch(midi: MIDIPitch(rawValue: midi), step: step, octave: octave)
}
