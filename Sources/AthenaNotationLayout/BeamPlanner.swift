#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif

public struct BeamGroup: Hashable, Sendable {
  public let voiceID: String
  public let staffID: String
  public let eventIDs: [NotationEventID]
  public let eventBeamCounts: [Int]

  public var beamCount: Int {
    eventBeamCounts.max() ?? 0
  }

  public init(
    voiceID: String,
    staffID: String,
    eventIDs: [NotationEventID],
    eventBeamCounts: [Int]
  ) {
    precondition(eventIDs.count >= 2)
    precondition(eventIDs.count == eventBeamCounts.count)
    precondition(eventBeamCounts.allSatisfy { $0 > 0 })
    self.voiceID = voiceID
    self.staffID = staffID
    self.eventIDs = eventIDs
    self.eventBeamCounts = eventBeamCounts
  }
}

/// First beam-grouping slice, following VexFlow's idea that beaming is a
/// rhythmic planning pass rather than a glyph property.
public struct BeamPlanner: Sendable {
  public init() {}

  public func groups(
    inputs: [LayoutInput],
    beatDuration: Rational = Rational(1, 4)
  ) -> [BeamGroup] {
    precondition(beatDuration > .zero)

    return Dictionary(grouping: inputs, by: \.voiceID)
      .keys.sorted()
      .flatMap { voiceID in
        let voiceInputs =
          inputs
          .filter { $0.voiceID == voiceID }
          .sorted { $0.onset < $1.onset }
        return groups(in: voiceInputs, voiceID: voiceID, beatDuration: beatDuration)
      }
  }

  private func groups(
    in inputs: [LayoutInput],
    voiceID: String,
    beatDuration: Rational
  ) -> [BeamGroup] {
    var result: [BeamGroup] = []
    var current: [LayoutInput] = []
    var currentBeat: Int64?

    func appendCurrent() {
      guard current.count >= 2 else { return }
      result.append(
        BeamGroup(
          voiceID: voiceID,
          staffID: current[0].event.staffID,
          eventIDs: current.map(\.event.id),
          eventBeamCounts: current.compactMap { beamCount(for: $0.event) }
        ))
    }

    for input in inputs {
      guard beamCount(for: input.event) != nil else {
        appendCurrent()
        current = []
        currentBeat = nil
        continue
      }

      let beat = beatIndex(for: input.onset, beatDuration: beatDuration)
      let continuesGroup =
        currentBeat == beat
        && current.last?.event.staffID == input.event.staffID

      if !current.isEmpty, !continuesGroup {
        appendCurrent()
        current = []
      }
      current.append(input)
      currentBeat = beat
    }

    appendCurrent()
    return result
  }

  private func beamCount(for event: NotationEvent) -> Int? {
    guard case .notes(let pitches) = event.content, !pitches.isEmpty else { return nil }
    if event.engravingDuration == Rational(1, 8) { return 1 }
    if event.engravingDuration == Rational(1, 16) { return 2 }
    return nil
  }

  private func beatIndex(for onset: Rational, beatDuration: Rational) -> Int64 {
    let beat = onset / beatDuration
    return beat.numerator / beat.denominator
  }
}
