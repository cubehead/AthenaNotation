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
  #expect(scene.accessibility.map(\.eventID) == ["n1", "n2"])
  #expect(scene.accessibility.first?.label.contains("Measure 1, beat 1") == true)

  let json = try scene.jsonString()
  #expect(json.contains("playbackHighlight"))
  #expect(json.contains("accessibility"))
  #expect(try JSONSerialization.jsonObject(with: Data(json.utf8)) is [String: Any])
}

@Test func playbackCursorCanBeHiddenWithoutDiscardingPlaybackState() {
  let eventID = NotationEventID(rawValue: "hidden-cursor")
  let score = NotationScore(
    staves: [NotationStaff(id: "treble", clef: .treble)],
    voices: [NotationVoice(id: "right", events: [NotationEvent(
      id: eventID,
      content: .notes([pitch(60, .c, 4)]),
      duration: Rational(1, 4),
      staffID: "treble"
    )])]
  )
  let scene = AndroidScoreRenderer(options: .init(
    width: 600,
    height: 260,
    accessibilityLocaleIdentifier: "en_US",
    showsPlaybackCursor: false
  )).render(score: score, playbackEventIDs: [eventID])

  #expect(scene.commands.contains { $0.role == "notehead" })
  #expect(!scene.commands.contains { $0.role == "playbackHighlight" })

  let scoreJSON = String(decoding: try! JSONEncoder().encode(score), as: UTF8.self)
  let bridgeJSON = try! AndroidRenderBridge().renderScoreJSON(
    scoreJSON,
    width: 600,
    height: 260,
    playbackEventIDs: [eventID.rawValue],
    showsPlaybackCursor: false
  )
  #expect(!bridgeJSON.contains("playbackHighlight"))
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

@Test func stemsUseBravuraNoteheadEdgesAndFlagsUseStemAnchors() throws {
  let upwardID = NotationEventID(rawValue: "upward")
  let downwardID = NotationEventID(rawValue: "downward")
  let score = NotationScore(
    staves: [NotationStaff(id: "treble", clef: .treble)],
    voices: [NotationVoice(id: "right", events: [
      NotationEvent(
        id: upwardID,
        content: .notes([pitch(60, .c, 4)]),
        duration: Rational(1, 8),
        staffID: "treble"
      ),
      NotationEvent(
        id: downwardID,
        content: .notes([pitch(84, .c, 6)]),
        duration: Rational(1, 4),
        staffID: "treble"
      ),
    ])]
  )
  let scene = AndroidScoreRenderer(options: .init(width: 600, height: 260))
    .render(score: score)

  let upwardHead = try #require(scene.commands.first {
    $0.role == "notehead" && $0.eventID == upwardID.rawValue
  })
  let upwardStem = try #require(scene.commands.first {
    $0.role == "stem" && $0.eventID == upwardID.rawValue
  })
  let upwardFlag = try #require(scene.commands.first {
    $0.role == "flag" && $0.eventID == upwardID.rawValue
  })
  let upwardStemX = try #require(upwardStem.points.first?.x)
  #expect(abs(upwardStemX - ((upwardHead.x ?? 0) + 5.2)) < 0.001)
  #expect((upwardFlag.x ?? 0) > upwardStemX)

  let downwardHead = try #require(scene.commands.first {
    $0.role == "notehead" && $0.eventID == downwardID.rawValue
  })
  let downwardStem = try #require(scene.commands.first {
    $0.role == "stem" && $0.eventID == downwardID.rawValue
  })
  let downwardStemX = try #require(downwardStem.points.first?.x)
  #expect(abs(downwardStemX - ((downwardHead.x ?? 0) - 5.2)) < 0.001)
}

@Test func eventAttachmentOnChordRendersOnlyOnce() {
  let score = NotationScore(
    staves: [NotationStaff(id: "treble", clef: .treble)],
    voices: [NotationVoice(id: "voice", events: [NotationEvent(
      id: .init(rawValue: "chord"),
      content: .notes([pitch(60, .c, 4), pitch(64, .e, 4)]),
      duration: Rational(1, 4),
      staffID: "treble",
      attachments: [NotationAttachment(
        id: "dynamic",
        content: .dynamic(label: "mf", velocity: nil)
      )]
    )])]
  )
  let scene = AndroidScoreRenderer(options: .init(width: 600, height: 260))
    .render(score: score)

  #expect(scene.commands.filter { $0.role == "dynamic" }.count == 1)
}

private func pitch(_ midi: UInt8, _ step: DiatonicStep, _ octave: Int) -> NotatedPitch {
  NotatedPitch(midi: MIDIPitch(rawValue: midi), step: step, octave: octave)
}
