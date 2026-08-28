#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif
import Foundation

public struct CountInAdvanceResult: Equatable, Sendable {
  public let remainingSeconds: Double
  public let didFinish: Bool

  public init(remainingSeconds: Double, didFinish: Bool) {
    self.remainingSeconds = remainingSeconds
    self.didFinish = didFinish
  }
}

/// Arithmetic for a one-measure count-in. During the count-in, a preview
/// timeline can run from a negative score position to zero before playback.
public enum ScoreCountInClock {
  public static func measureScoreDuration(timeSignature: TimeSignature) -> Double {
    Double(timeSignature.numerator) / Double(timeSignature.denominator)
  }

  public static func durationSeconds(
    timeSignature: TimeSignature,
    beatsPerMinute: Double,
    rate: Double
  ) -> Double {
    precondition(beatsPerMinute > 0)
    precondition(rate > 0)
    return ScoreTimeline.seconds(
      scoreTime: measureScoreDuration(timeSignature: timeSignature),
      beatsPerMinute: beatsPerMinute
    ) / rate
  }

  public static func displayedBeat(
    remainingSeconds: Double,
    timeSignature: TimeSignature,
    beatsPerMinute: Double,
    rate: Double
  ) -> Int {
    let duration = durationSeconds(
      timeSignature: timeSignature,
      beatsPerMinute: beatsPerMinute,
      rate: rate
    )
    let secondsPerBeat = duration / Double(timeSignature.numerator)
    return min(
      Int(timeSignature.numerator),
      max(1, Int(ceil(max(0, remainingSeconds) / secondsPerBeat)))
    )
  }

  public static func previewPosition(
    remainingSeconds: Double,
    timeSignature: TimeSignature,
    beatsPerMinute: Double,
    rate: Double
  ) -> Double {
    let duration = durationSeconds(
      timeSignature: timeSignature,
      beatsPerMinute: beatsPerMinute,
      rate: rate
    )
    guard duration > 0 else { return 0 }
    let progressRemaining = min(1, max(0, remainingSeconds / duration))
    return -measureScoreDuration(timeSignature: timeSignature) * progressRemaining
  }

  public static func advance(
    remainingSeconds: Double,
    elapsedSeconds: Double
  ) -> CountInAdvanceResult {
    let remaining = max(0, remainingSeconds - max(0, elapsedSeconds))
    return CountInAdvanceResult(remainingSeconds: remaining, didFinish: remaining == 0)
  }
}
