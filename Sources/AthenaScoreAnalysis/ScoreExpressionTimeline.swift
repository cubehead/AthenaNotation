#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif
import Foundation

/// Playback controls derived from semantic score markings at one exact score position.
public struct PlaybackExpressionState: Hashable, Sendable {
  public let velocity: UInt8
  public let sustainPedalDown: Bool

  public init(velocity: UInt8 = 96, sustainPedalDown: Bool = false) {
    self.velocity = velocity
    self.sustainPedalDown = sustainPedalDown
  }
}

/// Resolves dynamics, hairpins and pedal spanners on the same rational timeline
/// used by notation highlighting and LED scheduling.
public struct ScoreExpressionTimeline: Hashable, Sendable {
  private struct DynamicPoint: Hashable, Sendable {
    let onset: Rational
    let velocity: UInt8
  }

  private struct Range: Hashable, Sendable {
    let start: Rational
    let end: Rational
    let kind: NotationSpannerKind
  }

  private let dynamics: [DynamicPoint]
  private let hairpins: [Range]
  private let pedals: [Range]

  public init(score: NotationScore) {
    let timeline = ScoreTimeline(score: score)
    let onsetByID = Dictionary(uniqueKeysWithValues: timeline.events.map { ($0.id, $0.onset) })

    dynamics = timeline.events.flatMap { item in
      item.event.attachments.compactMap { attachment -> DynamicPoint? in
        guard case .dynamic(let label, let explicitVelocity) = attachment.content else {
          return nil
        }
        let velocity = explicitVelocity ?? Self.standardVelocity(for: label)
        return DynamicPoint(onset: item.onset, velocity: velocity)
      }
    }.sorted { $0.onset < $1.onset }

    let ranges = score.spanners.compactMap { spanner -> Range? in
      guard let rawStart = onsetByID[spanner.startEventID],
        let rawEnd = onsetByID[spanner.endEventID]
      else { return nil }
      return Range(start: min(rawStart, rawEnd), end: max(rawStart, rawEnd), kind: spanner.kind)
    }
    hairpins = ranges.filter {
      $0.kind == .crescendo || $0.kind == .diminuendo || $0.kind.rawValue == "hairpin.swell"
    }.sorted { $0.start < $1.start }
    pedals = ranges.filter { $0.kind == .pedal }.sorted { $0.start < $1.start }
  }

  public func state(at position: Rational) -> PlaybackExpressionState {
    let velocity = resolvedVelocity(at: position)
    let pedalDown = pedals.contains { $0.start <= position && position < $0.end }
    return PlaybackExpressionState(velocity: velocity, sustainPedalDown: pedalDown)
  }
}

private extension ScoreExpressionTimeline {
  func resolvedVelocity(at position: Rational) -> UInt8 {
    let explicit = dynamics.last(where: { $0.onset <= position })
    var velocity = explicit?.velocity ?? 96
    let explicitOnset = explicit?.onset ?? Rational.zero

    if let completed = hairpins.last(where: {
      $0.end <= position && $0.end > explicitOnset && $0.kind.rawValue != "hairpin.swell"
    }) {
      velocity = endpointVelocity(for: completed)
    }

    guard let active = hairpins.last(where: { $0.start <= position && position < $0.end }),
      active.end > active.start
    else { return velocity }

    let startVelocity = dynamics.last(where: { $0.onset <= active.start })?.velocity ?? velocity
    if active.kind.rawValue == "hairpin.swell" {
      let progress = fraction(position - active.start, over: active.end - active.start)
      let triangular = progress <= 0.5 ? progress * 2 : (1 - progress) * 2
      return clampedVelocity(Double(startVelocity) + 20 * triangular)
    }

    let endVelocity = endpointVelocity(for: active)
    let progress = fraction(position - active.start, over: active.end - active.start)
    return clampedVelocity(
      Double(startVelocity) + (Double(endVelocity) - Double(startVelocity)) * progress
    )
  }

  private func endpointVelocity(for hairpin: Range) -> UInt8 {
    let startVelocity = dynamics.last(where: { $0.onset <= hairpin.start })?.velocity ?? 96
    if let explicitEnd = dynamics.first(where: {
      $0.onset > hairpin.start && $0.onset <= hairpin.end
    }) {
      return explicitEnd.velocity
    }
    if hairpin.kind == .crescendo {
      return clampedVelocity(Double(startVelocity) + 20)
    }
    if hairpin.kind == .diminuendo {
      return clampedVelocity(Double(startVelocity) - 20)
    }
    return startVelocity
  }

  func fraction(_ numerator: Rational, over denominator: Rational) -> Double {
    min(1, max(0, numerator.doubleValue / denominator.doubleValue))
  }

  func clampedVelocity(_ value: Double) -> UInt8 {
    UInt8(min(127, max(1, Int(value.rounded()))))
  }

  static func standardVelocity(for rawLabel: String) -> UInt8 {
    switch rawLabel.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
    case "pppp": 20
    case "ppp": 28
    case "pp": 36
    case "p": 48
    case "mp": 60
    case "mf": 72
    case "f": 84
    case "ff": 96
    case "fff": 108
    case "ffff": 116
    case "sf", "fz", "sfz", "sffz": 110
    case "fp": 76
    case "sfp": 82
    default: 96
    }
  }
}
