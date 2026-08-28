#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif

/// A validated A–B range expressed in the score's whole-note time unit.
public struct ScoreABLoopRange: Hashable, Sendable {
  public let start: Double
  public let end: Double

  public var range: Range<Double> { start..<end }

  public init?(start: Double, end: Double, scoreDuration: Double) {
    guard scoreDuration > 0 else { return nil }
    let lower = min(max(0, start), scoreDuration)
    let upper = min(max(0, end), scoreDuration)
    guard upper > lower + 0.000_000_001 else { return nil }
    self.start = lower
    self.end = upper
  }
}

/// What a client should do after advancing the shared playback clock.
public enum ScorePlaybackNextAction: Hashable, Sendable {
  case continuePlayback
  case beginCountIn(at: Double)
  case finish
}

/// A policy-resolved playback step. It keeps A–B repeat behavior out of app UI
/// code while leaving timers and concrete runtime effects client-owned.
public struct ScorePlaybackStep: Hashable, Sendable {
  public let position: Double
  public let reason: ScorePlaybackEventReason
  public let nextAction: ScorePlaybackNextAction

  public init(
    position: Double,
    reason: ScorePlaybackEventReason,
    nextAction: ScorePlaybackNextAction
  ) {
    self.position = position
    self.reason = reason
    self.nextAction = nextAction
  }
}

public enum ScorePlaybackStepPlanner {
  /// Resolves clock output into one of three host actions. When count-in is
  /// enabled for repeats, a loop always restarts exactly at A after the count-in.
  public static func resolve(
    _ advance: PlaybackAdvanceResult,
    loopRange: ScoreABLoopRange?,
    countInOnLoop: Bool = true
  ) -> ScorePlaybackStep {
    if advance.didFinish {
      return ScorePlaybackStep(
        position: advance.position,
        reason: .finished,
        nextAction: .finish
      )
    }
    if advance.didLoop {
      let restart = loopRange?.start ?? 0
      return ScorePlaybackStep(
        position: countInOnLoop ? restart : advance.position,
        reason: .looped,
        nextAction: countInOnLoop ? .beginCountIn(at: restart) : .continuePlayback
      )
    }
    return ScorePlaybackStep(
      position: advance.position,
      reason: .advanced,
      nextAction: .continuePlayback
    )
  }
}
