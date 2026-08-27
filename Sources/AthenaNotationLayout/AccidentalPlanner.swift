#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif

public struct VisibleAccidental: Hashable, Sendable {
  public let pitchIndex: Int
  public let accidental: AccidentalKind

  public init(pitchIndex: Int, accidental: AccidentalKind) {
    precondition(pitchIndex >= 0)
    self.pitchIndex = pitchIndex
    self.accidental = accidental
  }
}

/// Applies key signatures and per-measure accidental memory. `nil` on a pitch
/// means it inherits the current state; `.natural` explicitly cancels it.
public struct AccidentalPlanner: Sendable {
  public init() {}

  public func visibleAccidentals(
    inputs: [LayoutInput],
    staves: [NotationStaff]
  ) -> [NotationEventID: [VisibleAccidental]] {
    let staffByID = Dictionary(uniqueKeysWithValues: staves.map { ($0.id, $0) })
    let ordered = inputs.sorted {
      if $0.onset != $1.onset { return $0.onset < $1.onset }
      if $0.voiceID != $1.voiceID { return $0.voiceID < $1.voiceID }
      return $0.event.id.rawValue < $1.event.id.rawValue
    }
    var state: [StateKey: AccidentalKind] = [:]
    var result: [NotationEventID: [VisibleAccidental]] = [:]

    for input in ordered {
      guard let staff = staffByID[input.event.staffID],
        case .notes(let pitches) = input.event.content
      else { continue }
      let measureDuration = Rational(
        Int64(staff.timeSignature.numerator),
        Int64(staff.timeSignature.denominator)
      )
      let measure = input.onset / measureDuration
      let measureIndex = measure.numerator / measure.denominator

      for (pitchIndex, pitch) in pitches.enumerated() {
        guard let explicit = pitch.accidental else { continue }
        let key = StateKey(
          staffID: staff.id,
          measureIndex: measureIndex,
          diatonicIndex: pitch.diatonicIndex
        )
        let inherited = staff.keySignature.accidental(for: pitch.step)
        let current = state[key] ?? inherited
        if current != explicit {
          result[input.event.id, default: []].append(
            VisibleAccidental(pitchIndex: pitchIndex, accidental: explicit)
          )
        }
        state[key] = explicit
      }
    }
    return result
  }

  private struct StateKey: Hashable {
    let staffID: String
    let measureIndex: Int64
    let diatonicIndex: Int
  }
}
