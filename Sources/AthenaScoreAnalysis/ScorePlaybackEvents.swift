#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif

/// Why a playback update was produced. Clients can route the same semantic
/// event to any playback consumer.
public enum ScorePlaybackEventReason: Hashable, Sendable {
  case started
  case advanced
  case seeked
  case looped
  case countInStarted
  case countInBeat(Int)
  case paused
  case finished
}

/// A complete, device-independent view of the score at one playback position.
public struct ScorePlaybackSnapshot: Hashable, Sendable {
  public let position: Rational
  public let beatsPerMinute: Double
  public let cursorEventIDs: Set<NotationEventID>
  public let activeEvents: [TimedNotationEvent]
  public let activeMIDINotes: Set<UInt8>
  public let expression: PlaybackExpressionState

  public init(
    position: Rational,
    beatsPerMinute: Double,
    cursorEventIDs: Set<NotationEventID>,
    activeEvents: [TimedNotationEvent],
    activeMIDINotes: Set<UInt8>,
    expression: PlaybackExpressionState
  ) {
    self.position = position
    self.beatsPerMinute = beatsPerMinute
    self.cursorEventIDs = cursorEventIDs
    self.activeEvents = activeEvents
    self.activeMIDINotes = activeMIDINotes
    self.expression = expression
  }
}

/// Callback payload for one transport change, including exact note-on/note-off
/// deltas so consumers do not need to duplicate timeline analysis.
public struct ScorePlaybackEvent: Hashable, Sendable {
  public let reason: ScorePlaybackEventReason
  public let previousPosition: Rational?
  public let snapshot: ScorePlaybackSnapshot
  public let noteTransition: PianoNoteTransition

  public init(
    reason: ScorePlaybackEventReason,
    previousPosition: Rational?,
    snapshot: ScorePlaybackSnapshot,
    noteTransition: PianoNoteTransition
  ) {
    self.reason = reason
    self.previousPosition = previousPosition
    self.snapshot = snapshot
    self.noteTransition = noteTransition
  }
}

/// Standard callback signature shared by playback consumers.
public typealias ScorePlaybackEventHandler = @Sendable (ScorePlaybackEvent) -> Void

/// Produces playback callback payloads without importing a UI framework or
/// concrete runtime service.
public struct ScorePlaybackEventPlanner: Hashable, Sendable {
  private let timeline: ScoreTimeline
  private let tempoMap: ScoreTempoMap
  private let expressionTimeline: ScoreExpressionTimeline

  public init(score: NotationScore, defaultBeatsPerMinute: Double = 80) {
    timeline = ScoreTimeline(score: score)
    tempoMap = ScoreTempoMap(score: score, defaultBeatsPerMinute: defaultBeatsPerMinute)
    expressionTimeline = ScoreExpressionTimeline(score: score)
  }

  public func snapshot(
    at position: Rational,
    hand: Hand? = nil
  ) -> ScorePlaybackSnapshot {
    let activeEvents = timeline.activeEvents(at: position, hand: hand)
    return ScorePlaybackSnapshot(
      position: position,
      beatsPerMinute: tempoMap.beatsPerMinute(at: position.doubleValue),
      cursorEventIDs: timeline.cursorEventIDs(at: position, hand: hand),
      activeEvents: activeEvents,
      activeMIDINotes: Self.midiNotes(in: activeEvents),
      expression: expressionTimeline.state(at: position)
    )
  }

  public func event(
    reason: ScorePlaybackEventReason,
    from previousPosition: Rational?,
    to position: Rational,
    hand: Hand? = nil
  ) -> ScorePlaybackEvent {
    let previousNotes = previousPosition.map {
      Self.midiNotes(in: timeline.activeEvents(at: $0, hand: hand))
    } ?? []
    let current = snapshot(at: position, hand: hand)
    return ScorePlaybackEvent(
      reason: reason,
      previousPosition: previousPosition,
      snapshot: current,
      noteTransition: PianoNoteStatePlanner.transition(
        from: previousNotes,
        to: current.activeMIDINotes
      )
    )
  }

  private static func midiNotes(in events: [TimedNotationEvent]) -> Set<UInt8> {
    Set(events.flatMap { item -> [UInt8] in
      guard case .notes(let pitches) = item.event.content else { return [] }
      return pitches.map(\.midi.rawValue)
    })
  }
}
