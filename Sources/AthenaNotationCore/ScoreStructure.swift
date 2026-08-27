public enum Hand: String, Hashable, Sendable, Codable {
  case left
  case right
}

public struct StaffClef: RawRepresentable, Hashable, Sendable, Codable {
  public let rawValue: String

  public init(rawValue: String) {
    precondition(!rawValue.isEmpty, "A clef cannot be empty")
    self.rawValue = rawValue
  }

  public static let treble = Self(rawValue: "treble")
  public static let bass = Self(rawValue: "bass")
}

public struct TimeSignature: Hashable, Sendable, Codable {
  public let numerator: UInt8
  public let denominator: UInt8

  public init(numerator: UInt8, denominator: UInt8) {
    precondition(numerator > 0 && denominator > 0)
    self.numerator = numerator
    self.denominator = denominator
  }

  public static let commonTime = Self(numerator: 4, denominator: 4)
}

public struct KeySignature: Hashable, Sendable, Codable {
  /// Circle-of-fifths value: positive values are sharps, negative values are flats.
  public let fifths: Int8

  public init(fifths: Int8) {
    precondition((-7...7).contains(fifths), "Key signatures must use -7...7 fifths")
    self.fifths = fifths
  }

  public static let cMajor = Self(fifths: 0)
  public static let gMajor = Self(fifths: 1)
  public static let fMajor = Self(fifths: -1)

  public var accidentalCount: Int {
    abs(Int(fifths))
  }

  public func accidental(for step: DiatonicStep) -> AccidentalKind? {
    let order: [DiatonicStep] =
      fifths >= 0
      ? [.f, .c, .g, .d, .a, .e, .b]
      : [.b, .e, .a, .d, .g, .c, .f]
    guard let index = order.firstIndex(of: step), index < accidentalCount else { return nil }
    return fifths > 0 ? .sharp : .flat
  }
}

public struct NotationStaff: Identifiable, Hashable, Sendable, Codable {
  public let id: String
  public let clef: StaffClef
  public let timeSignature: TimeSignature
  public let keySignature: KeySignature

  public init(
    id: String,
    clef: StaffClef,
    timeSignature: TimeSignature = .commonTime,
    keySignature: KeySignature = .cMajor
  ) {
    self.id = id
    self.clef = clef
    self.timeSignature = timeSignature
    self.keySignature = keySignature
  }
}

public struct NotationVoice: Hashable, Sendable, Codable {
  public let id: String
  public let events: [NotationEvent]

  public init(id: String, events: [NotationEvent]) {
    self.id = id
    self.events = events
  }
}

public struct NotationScore: Hashable, Sendable, Codable {
  public let staves: [NotationStaff]
  public let voices: [NotationVoice]
  public let spanners: [NotationSpanner]
  public let tuplets: [NotationTuplet]
  public let barlines: [NotationBarline]
  public let voltas: [NotationVolta]
  public let tempoChanges: [NotationTempoChange]

  public init(
    staves: [NotationStaff],
    voices: [NotationVoice],
    spanners: [NotationSpanner] = [],
    tuplets: [NotationTuplet] = [],
    barlines: [NotationBarline] = [],
    voltas: [NotationVolta] = [],
    tempoChanges: [NotationTempoChange] = []
  ) {
    self.staves = staves
    self.voices = voices
    self.spanners = spanners
    self.tuplets = tuplets
    self.barlines = barlines
    self.voltas = voltas
    self.tempoChanges = tempoChanges.sorted { $0.onset < $1.onset }
  }
}
