/// Stable identifiers are part of the product contract: the score renderer,
/// rendering, analysis, and external clients must refer to one note.
public struct NotationEventID: RawRepresentable, Hashable, Sendable, Codable {
  public let rawValue: String

  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

public struct MIDIPitch: RawRepresentable, Hashable, Sendable, Codable, Comparable {
  public let rawValue: UInt8

  public init(rawValue: UInt8) {
    precondition(rawValue <= 127, "MIDI pitches must be in 0...127")
    self.rawValue = rawValue
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

public enum DiatonicStep: Int, Hashable, Sendable, Codable, CaseIterable {
  case c = 0
  case d
  case e
  case f
  case g
  case a
  case b
}

/// Open raw values allow standard, microtonal, and future MusicXML accidentals
/// to survive import before they receive specialized engraving rules.
public struct AccidentalKind: RawRepresentable, Hashable, Sendable, Codable {
  public let rawValue: String

  public init(rawValue: String) {
    precondition(!rawValue.isEmpty, "An accidental kind cannot be empty")
    self.rawValue = rawValue
  }

  public static let flat = Self(rawValue: "flat")
  public static let natural = Self(rawValue: "natural")
  public static let sharp = Self(rawValue: "sharp")
  public static let doubleFlat = Self(rawValue: "double-flat")
  public static let doubleSharp = Self(rawValue: "double-sharp")
}

public struct NotatedPitch: Hashable, Sendable, Codable, Comparable {
  public let midi: MIDIPitch
  public let step: DiatonicStep
  public let octave: Int
  public let accidental: AccidentalKind?

  public init(
    midi: MIDIPitch,
    step: DiatonicStep,
    octave: Int,
    accidental: AccidentalKind? = nil
  ) {
    self.midi = midi
    self.step = step
    self.octave = octave
    self.accidental = accidental
  }

  public var diatonicIndex: Int {
    octave * 7 + step.rawValue
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.diatonicIndex < rhs.diatonicIndex
  }
}
