import AthenaMusicXML
import AthenaNotationCore
import Foundation

enum NativeDemoScore {
  static let bundledResult: MusicXMLImportResult? = {
    guard
      let url = Bundle.module.url(forResource: "athena-demo", withExtension: "musicxml"),
      let data = try? Data(contentsOf: url)
    else {
      return nil
    }
    return try? MusicXMLImporter().parse(data: data)
  }()

  static let score = NotationScore(
    staves: [
      NotationStaff(id: "treble", clef: .treble, keySignature: .gMajor),
      NotationStaff(id: "bass", clef: .bass, keySignature: .gMajor),
    ],
    voices: [
      NotationVoice(
        id: "treble-upper",
        events: [
          note("upper-c5", midi: 72, step: .c, octave: 5, finger: .thumb),
          NotationEvent(
            id: NotationEventID(rawValue: "quarter-rest"),
            content: .rest,
            duration: Rational(1, 4),
            staffID: "treble",
            hand: .right
          ),
          note(
            "sixteenth-up-1",
            midi: 76,
            step: .e,
            octave: 5,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "sixteenth-up-2",
            midi: 78,
            step: .f,
            octave: 5,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "sixteenth-up-3",
            midi: 79,
            step: .g,
            octave: 5,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "sixteenth-up-4",
            midi: 81,
            step: .a,
            octave: 5,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "sixteenth-up-5",
            midi: 88,
            step: .e,
            octave: 6,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "sixteenth-up-6",
            midi: 86,
            step: .d,
            octave: 6,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "sixteenth-up-7",
            midi: 84,
            step: .c,
            octave: 6,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "sixteenth-up-8",
            midi: 79,
            step: .b,
            octave: 5,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "mixed-eighth",
            midi: 76,
            step: .e,
            octave: 5,
            finger: nil,
            duration: Rational(1, 8)
          ),
          note(
            "mixed-sixteenth-1",
            midi: 77,
            step: .f,
            octave: 5,
            accidental: .natural,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "mixed-sixteenth-2",
            midi: 79,
            step: .g,
            octave: 5,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "upper-eighth-1",
            midi: 81,
            step: .a,
            octave: 5,
            finger: nil,
            duration: Rational(1, 12),
            writtenDuration: Rational(1, 8)
          ),
          note(
            "upper-eighth-2",
            midi: 79,
            step: .g,
            octave: 5,
            finger: nil,
            duration: Rational(1, 12),
            writtenDuration: Rational(1, 8)
          ),
          note(
            "upper-eighth-3",
            midi: 77,
            step: .f,
            octave: 5,
            finger: nil,
            duration: Rational(1, 12),
            writtenDuration: Rational(1, 8)
          ),
          note(
            "upper-sixteenth-9",
            midi: 77,
            step: .f,
            octave: 5,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "upper-sixteenth-10",
            midi: 76,
            step: .e,
            octave: 5,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "upper-sixteenth-11",
            midi: 74,
            step: .d,
            octave: 5,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "upper-sixteenth-12",
            midi: 72,
            step: .c,
            octave: 5,
            finger: nil,
            duration: Rational(1, 16)
          ),
          note(
            "upper-dotted-eighth",
            midi: 74,
            step: .d,
            octave: 5,
            finger: nil,
            duration: Rational(3, 16),
            writtenDuration: Rational(1, 8),
            dotCount: 1
          ),
          note(
            "upper-final-sixteenth",
            midi: 72,
            step: .c,
            octave: 5,
            finger: nil,
            duration: Rational(1, 16)
          ),
        ]),
      NotationVoice(
        id: "treble-lower",
        events: [
          note(
            "inner-e4", midi: 64, step: .e, octave: 4, finger: nil,
            duration: Rational(1, 4)),
          note(
            "inner-e4-tied", midi: 64, step: .e, octave: 4, finger: nil,
            duration: Rational(1, 4)),
          note(
            "inner-g4", midi: 67, step: .g, octave: 4, finger: nil,
            duration: Rational(1, 2)),
          note(
            "inner-a4", midi: 69, step: .a, octave: 4, finger: nil,
            duration: Rational(1, 2)),
          note(
            "inner-f4", midi: 66, step: .f, octave: 4, finger: nil,
            duration: Rational(1, 2)),
        ]),
      NotationVoice(
        id: "bass",
        events: [
          chord(
            "bass-cluster",
            pitches: [
              NotatedPitch(midi: MIDIPitch(rawValue: 48), step: .c, octave: 3),
              NotatedPitch(midi: MIDIPitch(rawValue: 50), step: .d, octave: 3),
              NotatedPitch(midi: MIDIPitch(rawValue: 55), step: .g, octave: 3),
            ],
            duration: Rational(1, 2)
          ),
          note(
            "bass-g2", midi: 43, step: .g, octave: 2, staffID: "bass", hand: .left,
            finger: nil, duration: Rational(1, 2)),
          chord(
            "bass-a-minor",
            pitches: [
              NotatedPitch(midi: MIDIPitch(rawValue: 45), step: .a, octave: 2),
              NotatedPitch(midi: MIDIPitch(rawValue: 48), step: .c, octave: 3),
              NotatedPitch(midi: MIDIPitch(rawValue: 52), step: .e, octave: 3),
            ],
            duration: Rational(1, 2)
          ),
          note(
            "bass-f2", midi: 42, step: .f, octave: 2, staffID: "bass", hand: .left,
            finger: nil, duration: Rational(1, 2)),
        ]),
    ],
    spanners: [
      NotationSpanner(
        id: "upper-phrase",
        kind: .slur,
        startEventID: NotationEventID(rawValue: "sixteenth-up-1"),
        endEventID: NotationEventID(rawValue: "sixteenth-up-8"),
        placement: .automatic
      ),
      NotationSpanner(
        id: "inner-voice-tie",
        kind: .tie,
        startEventID: NotationEventID(rawValue: "inner-e4"),
        endEventID: NotationEventID(rawValue: "inner-e4-tied"),
        placement: .automatic
      ),
    ],
    tuplets: [
      NotationTuplet(
        id: "second-measure-triplet",
        eventIDs: ["upper-eighth-1", "upper-eighth-2", "upper-eighth-3"].map {
          NotationEventID(rawValue: $0)
        },
        actualCount: 3,
        normalCount: 2
      )
    ],
    barlines: [
      NotationBarline(onset: .one, style: .repeatBoth),
      NotationBarline(onset: Rational(2), style: .final),
    ],
    voltas: [
      NotationVolta(
        id: "first-ending",
        startOnset: .zero,
        endOnset: .one,
        numbers: [1]
      ),
      NotationVolta(
        id: "second-ending",
        startOnset: .one,
        endOnset: Rational(2),
        numbers: [2]
      ),
    ]
  )

  private static func chord(
    _ id: String,
    pitches: [NotatedPitch],
    duration: Rational
  ) -> NotationEvent {
    NotationEvent(
      id: NotationEventID(rawValue: id),
      content: .notes(pitches),
      duration: duration,
      staffID: "bass",
      hand: .left
    )
  }

  private static func note(
    _ id: String,
    midi: UInt8,
    step: DiatonicStep,
    octave: Int,
    accidental: AccidentalKind? = nil,
    staffID: String = "treble",
    hand: Hand = .right,
    finger: PianoFinger?,
    duration: Rational = Rational(1, 4),
    writtenDuration: Rational? = nil,
    dotCount: UInt8 = 0
  ) -> NotationEvent {
    NotationEvent(
      id: NotationEventID(rawValue: id),
      content: .notes([
        NotatedPitch(
          midi: MIDIPitch(rawValue: midi),
          step: step,
          octave: octave,
          accidental: accidental
        )
      ]),
      duration: duration,
      writtenDuration: writtenDuration,
      dotCount: dotCount,
      staffID: staffID,
      hand: hand,
      attachments: finger.map {
        [
          NotationAttachment(
            id: "\(id)-fingering",
            anchor: .notehead(index: 0),
            placement: .above,
            content: .fingering($0)
          )
        ]
      } ?? []
    )
  }
}
