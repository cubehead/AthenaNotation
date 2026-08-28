#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif

/// One notation event placed on the score's exact, whole-note-based timeline.
/// The same value is suitable for highlighting and other timeline consumers.
public struct TimedNotationEvent: Identifiable, Hashable, Sendable {
  public let voiceID: String
  public let event: NotationEvent
  public let onset: Rational

  public var id: NotationEventID { event.id }
  public var end: Rational { onset + event.duration }

  public init(voiceID: String, event: NotationEvent, onset: Rational) {
    self.voiceID = voiceID
    self.event = event
    self.onset = onset
  }
}

/// A deterministic view of every voice on one shared musical timeline.
public struct ScoreTimeline: Hashable, Sendable {
  public let events: [TimedNotationEvent]
  public let duration: Rational

  public init(score: NotationScore) {
    var result: [TimedNotationEvent] = []
    var scoreEnd = Rational.zero

    for voice in score.voices {
      var onset = Rational.zero
      for event in voice.events {
        result.append(TimedNotationEvent(voiceID: voice.id, event: event, onset: onset))
        onset = onset + event.duration
      }
      scoreEnd = max(scoreEnd, onset)
    }

    events = result.sorted {
      if $0.onset != $1.onset { return $0.onset < $1.onset }
      if $0.voiceID != $1.voiceID { return $0.voiceID < $1.voiceID }
      return $0.id.rawValue < $1.id.rawValue
    }
    duration = scoreEnd
  }

  public func activeEvents(
    at position: Rational,
    hand: Hand? = nil,
    includeRests: Bool = false
  )
    -> [TimedNotationEvent]
  {
    guard position >= .zero && position < duration else { return [] }
    return events.filter { item in
      let isActive = item.onset <= position && position < item.end
      guard isActive else { return false }
      if let hand, item.event.hand != hand { return false }
      if includeRests { return true }
      if case .rest = item.event.content { return false }
      return true
    }
  }

  /// Event IDs at the most recent notation onset. This is intentionally distinct
  /// from sustained active notes so a long bass note cannot leave an old score
  /// cursor visible while the upper voice moves forward.
  public func cursorEventIDs(at position: Rational, hand: Hand? = nil) -> Set<NotationEventID> {
    guard position >= .zero && position < duration else { return [] }
    let eligible = events.lazy.filter { item in
      item.onset <= position && (hand == nil || item.event.hand == hand)
    }
    guard let onset = eligible.map(\.onset).max() else {
      return []
    }
    return Set(eligible.filter { $0.onset == onset }.map(\.id))
  }

  public func events(
    overlapping range: Range<Rational>,
    hand: Hand? = nil,
    includeRests: Bool = false
  )
    -> [TimedNotationEvent]
  {
    events.filter { item in
      let overlaps = item.onset < range.upperBound && item.end > range.lowerBound
      guard overlaps else { return false }
      if let hand, item.event.hand != hand { return false }
      if includeRests { return true }
      if case .rest = item.event.content { return false }
      return true
    }
  }

  /// Converts wall-clock seconds to the score's whole-note time unit.
  public static func scoreTime(seconds: Double, beatsPerMinute: Double) -> Double {
    precondition(beatsPerMinute > 0)
    return max(0, seconds) * beatsPerMinute / 240
  }

  /// Converts the score's whole-note time unit to wall-clock seconds.
  public static func seconds(scoreTime: Double, beatsPerMinute: Double) -> Double {
    precondition(beatsPerMinute > 0)
    return max(0, scoreTime) * 240 / beatsPerMinute
  }
}

public struct PlaybackAdvanceResult: Hashable, Sendable {
  public let position: Double
  public let didLoop: Bool
  public let didFinish: Bool

  public init(position: Double, didLoop: Bool, didFinish: Bool) {
    self.position = position
    self.didLoop = didLoop
    self.didFinish = didFinish
  }
}

/// Stateless clock arithmetic shared by playback and visualization consumers.
public enum ScorePlaybackClock {
  public static func advance(
    position: Double,
    duration: Double,
    elapsedSeconds: Double,
    beatsPerMinute: Double,
    rate: Double,
    loops: Bool
  ) -> PlaybackAdvanceResult {
    advance(
      position: position,
      duration: duration,
      elapsedSeconds: elapsedSeconds,
      beatsPerMinute: beatsPerMinute,
      rate: rate,
      loops: loops,
      loopRange: nil
    )
  }

  public static func advance(
    position: Double,
    duration: Double,
    elapsedSeconds: Double,
    beatsPerMinute: Double,
    rate: Double,
    loops: Bool,
    loopRange: Range<Double>?
  ) -> PlaybackAdvanceResult {
    precondition(duration >= 0)
    precondition(beatsPerMinute > 0)
    precondition(rate > 0)
    guard duration > 0 else {
      return PlaybackAdvanceResult(position: 0, didLoop: false, didFinish: true)
    }

    let requestedStart = min(max(0, loopRange?.lowerBound ?? 0), duration)
    let requestedEnd = min(max(requestedStart, loopRange?.upperBound ?? duration), duration)
    let hasValidLoopRange = loops && requestedEnd > requestedStart + 0.000_000_001
    let loopStart = hasValidLoopRange ? requestedStart : 0
    let playbackEnd = hasValidLoopRange ? requestedEnd : duration
    var current = min(max(0, position), duration)
    if loops && (current < loopStart || current >= playbackEnd) {
      current = loopStart
    }

    let increment = ScoreTimeline.scoreTime(
      seconds: max(0, elapsedSeconds) * rate,
      beatsPerMinute: beatsPerMinute
    )
    let next = current + increment
    guard next >= playbackEnd else {
      return PlaybackAdvanceResult(position: next, didLoop: false, didFinish: false)
    }
    if loops {
      let loopDuration = playbackEnd - loopStart
      return PlaybackAdvanceResult(
        position: loopStart + (next - loopStart).truncatingRemainder(dividingBy: loopDuration),
        didLoop: true,
        didFinish: false
      )
    }
    return PlaybackAdvanceResult(position: duration, didLoop: false, didFinish: true)
  }
}
