// This formatter ports the first-pass concepts from VexFlow 5.0.0's
// TickContext and Formatter. It intentionally omits VexFlow's iterative tuning
// until collision metrics and modifiers have been ported.
// See ThirdPartyNotices/VEXFLOW.md.

#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif
import Foundation

public struct EventLayoutMetrics: Hashable, Sendable {
  public var noteWidth: Double
  public var leftExtent: Double
  public var rightExtent: Double

  public init(noteWidth: Double = 10, leftExtent: Double = 0, rightExtent: Double = 0) {
    precondition(noteWidth >= 0 && leftExtent >= 0 && rightExtent >= 0)
    self.noteWidth = noteWidth
    self.leftExtent = leftExtent
    self.rightExtent = rightExtent
  }

  public var collisionWidth: Double {
    leftExtent + noteWidth + rightExtent
  }
}

public struct LayoutInput: Hashable, Sendable {
  public let event: NotationEvent
  public let voiceID: String
  public let onset: Rational
  public let metrics: EventLayoutMetrics

  public init(
    event: NotationEvent,
    voiceID: String,
    onset: Rational,
    metrics: EventLayoutMetrics = .init()
  ) {
    self.event = event
    self.voiceID = voiceID
    self.onset = onset
    self.metrics = metrics
  }
}

public struct PositionedEvent: Hashable, Sendable {
  public let input: LayoutInput
  public let x: Double

  public init(input: LayoutInput, x: Double) {
    self.input = input
    self.x = x
  }
}

public struct TickContext: Hashable, Sendable {
  public let onset: Rational
  public let inputs: [LayoutInput]
  public let x: Double
  public let maxDuration: Rational
}

public struct HorizontalLayout: Hashable, Sendable {
  public let contexts: [TickContext]
  public let events: [PositionedEvent]
  public let minimumWidth: Double
  public let width: Double
}

public struct HorizontalFormatter: Sendable {
  public struct Options: Hashable, Sendable {
    public var minimumContextGap: Double
    public var softmaxFactor: Double

    public init(minimumContextGap: Double = 8, softmaxFactor: Double = 2) {
      precondition(minimumContextGap >= 0)
      precondition(softmaxFactor > 0)
      self.minimumContextGap = minimumContextGap
      self.softmaxFactor = softmaxFactor
    }
  }

  public let options: Options

  public init(options: Options = .init()) {
    self.options = options
  }

  public func makeInputs(
    voices: [NotationVoice],
    metrics: [NotationEventID: EventLayoutMetrics] = [:]
  ) -> [LayoutInput] {
    voices.flatMap { voice in
      var onset = Rational.zero
      return voice.events.map { event in
        defer { onset = onset + event.duration }
        return LayoutInput(
          event: event,
          voiceID: voice.id,
          onset: onset,
          metrics: metrics[event.id] ?? .init()
        )
      }
    }
  }

  /// Aligns events sharing an exact onset, reserves collision widths, then
  /// distributes remaining width using duration-weighted softmax spacing.
  public func format(inputs: [LayoutInput], justifyTo requestedWidth: Double = 0)
    -> HorizontalLayout
  {
    guard !inputs.isEmpty else {
      return HorizontalLayout(contexts: [], events: [], minimumWidth: 0, width: 0)
    }

    let grouped = Dictionary(grouping: inputs, by: \.onset)
    let onsets = grouped.keys.sorted()
    let groups = onsets.map { onset in
      let values = grouped[onset, default: []]
      let left = values.map(\.metrics.leftExtent).max() ?? 0
      let right = values.map { $0.metrics.noteWidth + $0.metrics.rightExtent }.max() ?? 0
      let duration = values.map(\.event.duration).max() ?? .zero
      return (onset: onset, inputs: values, left: left, right: right, duration: duration)
    }

    var baseX: [Double] = []
    var cursor = 0.0

    for (index, group) in groups.enumerated() {
      baseX.append(cursor + group.left)
      cursor += group.left + group.right
      if index < groups.count - 1 {
        cursor += options.minimumContextGap
      }
    }

    let minimumWidth = cursor
    let width = max(minimumWidth, requestedWidth)
    let extra = width - minimumWidth

    var gapExtras = Array(repeating: 0.0, count: max(groups.count - 1, 0))
    if extra > 0, !gapExtras.isEmpty {
      let totalDuration = groups.dropLast().reduce(0.0) { $0 + $1.duration.doubleValue }
      let safeTotalDuration = max(totalDuration, Double.leastNonzeroMagnitude)
      let weights = groups.dropLast().map {
        pow(options.softmaxFactor, $0.duration.doubleValue / safeTotalDuration)
      }
      let totalWeight = weights.reduce(0, +)
      gapExtras = weights.map { extra * $0 / totalWeight }
    }

    var accumulatedExtra = 0.0
    var contexts: [TickContext] = []
    var positioned: [PositionedEvent] = []

    for (index, group) in groups.enumerated() {
      let x = baseX[index] + accumulatedExtra
      contexts.append(
        TickContext(
          onset: group.onset,
          inputs: group.inputs,
          x: x,
          maxDuration: group.duration
        )
      )
      positioned.append(contentsOf: group.inputs.map { PositionedEvent(input: $0, x: x) })

      if index < gapExtras.count {
        accumulatedExtra += gapExtras[index]
      }
    }

    return HorizontalLayout(
      contexts: contexts,
      events: positioned,
      minimumWidth: minimumWidth,
      width: width
    )
  }
}
