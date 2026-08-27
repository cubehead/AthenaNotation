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

  public init(
    spanner: NotationSpanner,
    systemIndex: Int,
    start: SpannerSystemEndpoint,
    end: SpannerSystemEndpoint
  ) {
    self.spanner = spanner
    self.systemIndex = systemIndex
    self.start = start
    self.end = end
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
            end: .event(spanner.endEventID)
          )
        ]
      }

      return (startSystem...endSystem).map { systemIndex in
        SpannerSystemSegment(
          spanner: spanner,
          systemIndex: systemIndex,
          start: systemIndex == startSystem ? .event(spanner.startEventID) : .leadingSystemEdge,
          end: systemIndex == endSystem ? .event(spanner.endEventID) : .trailingSystemEdge
        )
      }
    }
  }
}
