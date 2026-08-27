#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif

public struct TupletSystemSegment: Hashable, Sendable {
  public let tuplet: NotationTuplet
  public let systemIndex: Int
  public let eventIDs: [NotationEventID]
  public let beginsTuplet: Bool
  public let endsTuplet: Bool

  public init(
    tuplet: NotationTuplet,
    systemIndex: Int,
    eventIDs: [NotationEventID],
    beginsTuplet: Bool,
    endsTuplet: Bool
  ) {
    precondition(!eventIDs.isEmpty)
    self.tuplet = tuplet
    self.systemIndex = systemIndex
    self.eventIDs = eventIDs
    self.beginsTuplet = beginsTuplet
    self.endsTuplet = endsTuplet
  }
}

/// Maps semantic tuplet groups onto formatted systems without changing their
/// exact performed durations.
public struct TupletPlanner: Sendable {
  public init() {}

  public func segments(
    tuplets: [NotationTuplet],
    layouts: [HorizontalLayout]
  ) -> [TupletSystemSegment] {
    let systemByEvent = Dictionary(
      uniqueKeysWithValues: layouts.enumerated().flatMap { systemIndex, layout in
        layout.events.map { ($0.input.event.id, systemIndex) }
      })

    return tuplets.flatMap { tuplet -> [TupletSystemSegment] in
      let located = tuplet.eventIDs.compactMap { eventID -> (NotationEventID, Int)? in
        guard let systemIndex = systemByEvent[eventID] else { return nil }
        return (eventID, systemIndex)
      }
      guard located.count == tuplet.eventIDs.count,
        let firstSystem = located.first?.1,
        let lastSystem = located.last?.1
      else { return [] }

      return (firstSystem...lastSystem).compactMap { systemIndex in
        let eventIDs = located.filter { $0.1 == systemIndex }.map(\.0)
        guard !eventIDs.isEmpty else { return nil }
        return TupletSystemSegment(
          tuplet: tuplet,
          systemIndex: systemIndex,
          eventIDs: eventIDs,
          beginsTuplet: systemIndex == firstSystem,
          endsTuplet: systemIndex == lastSystem
        )
      }
    }
  }
}
