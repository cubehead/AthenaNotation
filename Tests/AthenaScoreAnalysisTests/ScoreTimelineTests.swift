import AthenaNotationCore
import AthenaScoreAnalysis
import XCTest

final class ScoreTimelineTests: XCTestCase {
  func testVoicesShareExactOnsetsAndRestsAreExcludedFromActiveNotes() {
    let score = NotationScore(
      staves: [NotationStaff(id: "staff", clef: .treble)],
      voices: [
        NotationVoice(
          id: "upper",
          events: [
            event("upper-a", duration: Rational(1, 4)),
            event("upper-b", duration: Rational(1, 4)),
          ]),
        NotationVoice(
          id: "lower",
          events: [
            event("lower-rest", duration: Rational(1, 4), rest: true),
            event("lower-b", duration: Rational(1, 2)),
          ]),
      ]
    )

    let timeline = ScoreTimeline(score: score)

    XCTAssertEqual(timeline.duration, Rational(3, 4))
    XCTAssertEqual(
      timeline.activeEvents(at: Rational(1, 8)).map(\.id.rawValue),
      ["upper-a"]
    )
    XCTAssertEqual(
      Set(timeline.activeEvents(at: Rational(1, 4)).map(\.id.rawValue)),
      Set(["upper-b", "lower-b"])
    )
  }

  func testWindowIncludesSustainedAndUpcomingEvents() {
    let score = NotationScore(
      staves: [NotationStaff(id: "staff", clef: .treble)],
      voices: [
        NotationVoice(
          id: "voice",
          events: [
            event("long", duration: Rational(1, 2)),
            event("next", duration: Rational(1, 4)),
          ])
      ]
    )

    let timeline = ScoreTimeline(score: score)
    XCTAssertEqual(
      timeline.events(overlapping: Rational(1, 4)..<Rational(5, 8)).map(\.id.rawValue),
      ["long", "next"]
    )
  }

  func testTempoConversionsUseQuarterNoteBPM() {
    XCTAssertEqual(ScoreTimeline.seconds(scoreTime: 1, beatsPerMinute: 120), 2)
    XCTAssertEqual(ScoreTimeline.scoreTime(seconds: 2, beatsPerMinute: 120), 1)
  }

  func testCursorUsesLatestOnsetInsteadOfEverySustainedNote() {
    let score = NotationScore(
      staves: [NotationStaff(id: "staff", clef: .treble)],
      voices: [
        NotationVoice(
          id: "moving",
          events: [
            event("moving-a", duration: Rational(1, 4)),
            event("moving-b", duration: Rational(1, 4)),
          ]),
        NotationVoice(
          id: "sustained",
          events: [event("sustained", duration: Rational(1, 2))]
        ),
      ]
    )

    let timeline = ScoreTimeline(score: score)
    XCTAssertEqual(
      timeline.cursorEventIDs(at: Rational(3, 8)),
      Set([NotationEventID(rawValue: "moving-b")])
    )
    XCTAssertEqual(
      Set(timeline.activeEvents(at: Rational(3, 8)).map(\.id.rawValue)),
      Set(["moving-b", "sustained"])
    )
  }

  func testPlaybackClockStopsOrLoopsAtScoreEnd() {
    let stopped = ScorePlaybackClock.advance(
      position: 2.9,
      duration: 3,
      elapsedSeconds: 1,
      beatsPerMinute: 60,
      rate: 1,
      loops: false
    )
    XCTAssertEqual(stopped.position, 3)
    XCTAssertTrue(stopped.didFinish)
    XCTAssertFalse(stopped.didLoop)

    let looped = ScorePlaybackClock.advance(
      position: 2.9,
      duration: 3,
      elapsedSeconds: 1,
      beatsPerMinute: 60,
      rate: 1,
      loops: true
    )
    XCTAssertEqual(looped.position, 0.15, accuracy: 0.000_001)
    XCTAssertTrue(looped.didLoop)
    XCTAssertFalse(looped.didFinish)
  }

  func testPlaybackClockAppliesRate() {
    let normal = ScorePlaybackClock.advance(
      position: 0,
      duration: 3,
      elapsedSeconds: 1,
      beatsPerMinute: 120,
      rate: 1,
      loops: false
    )
    let half = ScorePlaybackClock.advance(
      position: 0,
      duration: 3,
      elapsedSeconds: 1,
      beatsPerMinute: 120,
      rate: 0.5,
      loops: false
    )
    XCTAssertEqual(normal.position, 0.5)
    XCTAssertEqual(half.position, 0.25)
  }

  func testHandFilterControlsCursorAndUpcomingEvents() {
    let right = NotationEvent(
      id: NotationEventID(rawValue: "right"),
      content: .notes([NotatedPitch(midi: MIDIPitch(rawValue: 60), step: .c, octave: 4)]),
      duration: Rational(1, 4),
      staffID: "staff",
      hand: .right
    )
    let left = NotationEvent(
      id: NotationEventID(rawValue: "left"),
      content: .notes([NotatedPitch(midi: MIDIPitch(rawValue: 48), step: .c, octave: 3)]),
      duration: Rational(1, 2),
      staffID: "staff",
      hand: .left
    )
    let score = NotationScore(
      staves: [NotationStaff(id: "staff", clef: .treble)],
      voices: [
        NotationVoice(id: "right", events: [right]),
        NotationVoice(id: "left", events: [left]),
      ]
    )
    let timeline = ScoreTimeline(score: score)

    XCTAssertEqual(
      timeline.cursorEventIDs(at: .zero, hand: .right),
      Set([right.id])
    )
    XCTAssertEqual(
      timeline.events(overlapping: .zero..<Rational(1, 4), hand: .left).map(\.id),
      [left.id]
    )
  }

  func testPianoNoteTransitionDoesNotRetriggerHeldNotes() {
    let transition = PianoNoteStatePlanner.transition(
      from: [48, 60, 64],
      to: [48, 62, 64, 67]
    )

    XCTAssertEqual(transition.noteOffs, [60])
    XCTAssertEqual(transition.noteOns, [62, 67])
  }

  func testCountInRunsOneMeasureFromNegativeTimelineToZero() {
    let signature = TimeSignature(numerator: 4, denominator: 4)
    let duration = ScoreCountInClock.durationSeconds(
      timeSignature: signature,
      beatsPerMinute: 120,
      rate: 1
    )

    XCTAssertEqual(duration, 2)
    XCTAssertEqual(
      ScoreCountInClock.previewPosition(
        remainingSeconds: duration,
        timeSignature: signature,
        beatsPerMinute: 120,
        rate: 1
      ),
      -1
    )
    XCTAssertEqual(
      ScoreCountInClock.previewPosition(
        remainingSeconds: duration / 2,
        timeSignature: signature,
        beatsPerMinute: 120,
        rate: 1
      ),
      -0.5
    )
    XCTAssertEqual(
      ScoreCountInClock.displayedBeat(
        remainingSeconds: duration,
        timeSignature: signature,
        beatsPerMinute: 120,
        rate: 1
      ),
      4
    )
    XCTAssertTrue(
      ScoreCountInClock.advance(remainingSeconds: 0.1, elapsedSeconds: 0.2).didFinish
    )
  }

  func testTempoMapIntegratesAndAdvancesAcrossTempoChanges() {
    let score = NotationScore(
      staves: [NotationStaff(id: "staff", clef: .treble)],
      voices: [],
      tempoChanges: [
        NotationTempoChange(onset: .zero, beatsPerMinute: 120),
        NotationTempoChange(onset: Rational(1, 2), beatsPerMinute: 60),
      ]
    )
    let map = ScoreTempoMap(score: score)

    XCTAssertEqual(map.seconds(to: 1), 3)
    XCTAssertEqual(map.beatsPerMinute(at: 0.25), 120)
    XCTAssertEqual(map.beatsPerMinute(at: 0.75), 60)

    let result = map.advance(
      position: 0.49,
      duration: 1,
      elapsedSeconds: 0.1,
      rate: 1,
      loops: false
    )
    XCTAssertEqual(result.position, 0.52, accuracy: 0.000_001)

    let unmarked = NotationScore(
      staves: [NotationStaff(id: "default", clef: .treble)],
      voices: []
    )
    XCTAssertEqual(ScoreTempoMap(score: unmarked).beatsPerMinute(at: 0), 80)
  }

  private func event(_ id: String, duration: Rational, rest: Bool = false) -> NotationEvent {
    NotationEvent(
      id: NotationEventID(rawValue: id),
      content: rest
        ? .rest
        : .notes([NotatedPitch(midi: MIDIPitch(rawValue: 60), step: .c, octave: 4)]),
      duration: duration,
      staffID: "staff"
    )
  }
}
