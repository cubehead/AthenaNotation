#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif

public enum SpannerSystemEndpoint: Hashable, Sendable {
  case event(NotationEventID)
  case leadingSystemEdge
  case trailingSystemEdge
}

public struct SpannerSystemSegment: Hashable, Sendable {
  public let spanner: NotationSpanner
  public let systemIndex: Int
  public let start: SpannerSystemEndpoint
  public let end: SpannerSystemEndpoint
  /// Whether this segment begins a newly pressed pedal and should show `Ped.`.
  public let showsPedalLabel: Bool
  /// Whether this segment contains the actual pedal release and should draw its end hook.
  public let showsPedalReleaseHook: Bool

  public init(
    spanner: NotationSpanner,
    systemIndex: Int,
    start: SpannerSystemEndpoint,
    end: SpannerSystemEndpoint,
    showsPedalLabel: Bool = true,
    showsPedalReleaseHook: Bool = true
  ) {
    self.spanner = spanner
    self.systemIndex = systemIndex
    self.start = start
    self.end = end
    self.showsPedalLabel = showsPedalLabel
    self.showsPedalReleaseHook = showsPedalReleaseHook
  }
}

/// Converts semantic ties and slurs into per-system segments. A spanner that
/// crosses a line break ends at one system edge and resumes at the next.
public struct SpannerPlanner: Sendable {
  public init() {}

  public func segments(
    spanners: [NotationSpanner],
    layouts: [HorizontalLayout]
  ) -> [SpannerSystemSegment] {
    let systemByEvent = Dictionary(
      uniqueKeysWithValues: layouts.enumerated().flatMap { systemIndex, layout in
        layout.events.map { ($0.input.event.id, systemIndex) }
      })
    let eventByID = Dictionary(
      uniqueKeysWithValues: layouts.flatMap { layout in
        layout.events.map { ($0.input.event.id, $0.input) }
      })
    let continuingPedalIDs = Set<String>(spanners.compactMap { spanner in
      guard spanner.kind == .pedal,
        let startInput = eventByID[spanner.startEventID]
      else { return nil }

      let continuesPreviousPedal = spanners.contains { previous in
        guard previous.kind == .pedal,
          previous.id != spanner.id,
          let endInput = eventByID[previous.endEventID],
          endInput.event.staffID == startInput.event.staffID
        else { return false }
        return previous.endEventID == spanner.startEventID
          || endInput.onset + endInput.event.duration == startInput.onset
      }
      return continuesPreviousPedal ? spanner.id : nil
    })

    return spanners.flatMap { spanner -> [SpannerSystemSegment] in
      guard let startSystem = systemByEvent[spanner.startEventID],
        let endSystem = systemByEvent[spanner.endEventID],
        startSystem <= endSystem
      else { return [] }

      if startSystem == endSystem {
        return [
          SpannerSystemSegment(
            spanner: spanner,
            systemIndex: startSystem,
            start: .event(spanner.startEventID),
            end: .event(spanner.endEventID),
            showsPedalLabel: spanner.kind != .pedal || !continuingPedalIDs.contains(spanner.id)
          )
        ]
      }

      return (startSystem...endSystem).map { systemIndex in
        SpannerSystemSegment(
          spanner: spanner,
          systemIndex: systemIndex,
          start: systemIndex == startSystem ? .event(spanner.startEventID) : .leadingSystemEdge,
          end: systemIndex == endSystem ? .event(spanner.endEventID) : .trailingSystemEdge,
          showsPedalLabel: spanner.kind != .pedal
            || (systemIndex == startSystem && !continuingPedalIDs.contains(spanner.id)),
          showsPedalReleaseHook: spanner.kind != .pedal || systemIndex == endSystem
        )
      }
    }
  }
}
