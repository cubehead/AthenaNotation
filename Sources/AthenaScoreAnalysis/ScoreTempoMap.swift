#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif

/// Piecewise-constant tempo over exact score time. It integrates wall time
/// across tempo boundaries so playback and other timeline consumers agree when
/// a score accelerates or slows down.
public struct ScoreTempoMap: Hashable, Sendable {
  public let changes: [NotationTempoChange]
  public let defaultBeatsPerMinute: Double

  public init(score: NotationScore, defaultBeatsPerMinute: Double = 80) {
    precondition(defaultBeatsPerMinute > 0)
    self.defaultBeatsPerMinute = defaultBeatsPerMinute

    var byOnset: [Rational: NotationTempoChange] = [:]
    for change in score.tempoChanges {
      byOnset[change.onset] = change
    }
    changes = byOnset.values.sorted { $0.onset < $1.onset }
  }

  public var hasMidScoreChanges: Bool {
    changes.contains { $0.onset > .zero }
  }

  public func beatsPerMinute(at position: Double) -> Double {
    let target = max(0, position)
    return changes.last { $0.onset.doubleValue <= target + 0.000_000_001 }?.beatsPerMinute
      ?? defaultBeatsPerMinute
  }

  public func seconds(to position: Double, rate: Double = 1) -> Double {
    precondition(rate > 0)
    let target = max(0, position)
    var cursor = 0.0
    var bpm = defaultBeatsPerMinute
    var result = 0.0

    for change in changes {
      let onset = change.onset.doubleValue
      guard onset <= target else { break }
      if onset > cursor {
        result += ScoreTimeline.seconds(scoreTime: onset - cursor, beatsPerMinute: bpm) / rate
        cursor = onset
      }
      bpm = change.beatsPerMinute
    }
    if target > cursor {
      result += ScoreTimeline.seconds(scoreTime: target - cursor, beatsPerMinute: bpm) / rate
    }
    return result
  }

  public func advance(
    position: Double,
    duration: Double,
    elapsedSeconds: Double,
    rate: Double,
    loops: Bool
  ) -> PlaybackAdvanceResult {
    advance(
      position: position,
      duration: duration,
      elapsedSeconds: elapsedSeconds,
      rate: rate,
      loops: loops,
      loopRange: nil
    )
  }

  public func advance(
    position: Double,
    duration: Double,
    elapsedSeconds: Double,
    rate: Double,
    loops: Bool,
    loopRange: Range<Double>?
  ) -> PlaybackAdvanceResult {
    precondition(duration >= 0)
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
    var didLoop = false
    if loops && (current < loopStart || current >= playbackEnd) {
      didLoop = current >= playbackEnd
      current = loopStart
    }
    var remaining = max(0, elapsedSeconds)

    while remaining > 0 {
      let nextTempoOnset = changes
        .map(\.onset.doubleValue)
        .first { $0 > current + 0.000_000_001 && $0 < playbackEnd }
      let boundary = nextTempoOnset ?? playbackEnd
      let bpm = beatsPerMinute(at: current)
      let secondsToBoundary =
        ScoreTimeline.seconds(scoreTime: boundary - current, beatsPerMinute: bpm) / rate

      if remaining < secondsToBoundary {
        current += ScoreTimeline.scoreTime(
          seconds: remaining * rate,
          beatsPerMinute: bpm
        )
        remaining = 0
      } else {
        current = boundary
        remaining = max(0, remaining - secondsToBoundary)
        if current >= playbackEnd {
          guard loops else {
            return PlaybackAdvanceResult(position: duration, didLoop: didLoop, didFinish: true)
          }
          current = loopStart
          didLoop = true
        }
      }
    }

    return PlaybackAdvanceResult(position: current, didLoop: didLoop, didFinish: false)
  }
}
