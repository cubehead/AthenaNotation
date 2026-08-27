#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif

public struct VoltaSystemSegment: Hashable, Sendable {
  public let volta: NotationVolta
  public let systemIndex: Int
  public let startsHere: Bool
  public let endsHere: Bool

  public init(
    volta: NotationVolta,
    systemIndex: Int,
    startsHere: Bool,
    endsHere: Bool
  ) {
    self.volta = volta
    self.systemIndex = systemIndex
    self.startsHere = startsHere
    self.endsHere = endsHere
  }
}

/// Splits alternate-ending brackets at system boundaries without changing
/// their semantic timeline range.
public struct VoltaPlanner: Sendable {
  public init() {}

  public func segments(
    voltas: [NotationVolta],
    layouts: [HorizontalLayout],
    scoreEnd: Rational
  ) -> [VoltaSystemSegment] {
    let starts = layouts.map { $0.contexts.first?.onset ?? scoreEnd }

    return voltas.flatMap { volta in
      layouts.indices.compactMap { systemIndex -> VoltaSystemSegment? in
        let systemStart = starts[systemIndex]
        let systemEnd =
          systemIndex + 1 < starts.count ? starts[systemIndex + 1] : scoreEnd
        guard volta.startOnset < systemEnd, volta.endOnset > systemStart else { return nil }
        return VoltaSystemSegment(
          volta: volta,
          systemIndex: systemIndex,
          startsHere: volta.startOnset >= systemStart,
          endsHere: volta.endOnset <= systemEnd
        )
      }
    }
  }
}
