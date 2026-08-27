public enum TupletBracketDisplay: String, Hashable, Sendable, Codable {
  case automatic
  case always
  case never
}

public struct NotationTuplet: Identifiable, Hashable, Sendable, Codable {
  public let id: String
  public let eventIDs: [NotationEventID]
  /// Number of written notes that are performed.
  public let actualCount: UInt8
  /// Number of normal written notes occupying the same time.
  public let normalCount: UInt8
  public let bracket: TupletBracketDisplay
  public let placement: AttachmentPlacement

  public init(
    id: String,
    eventIDs: [NotationEventID],
    actualCount: UInt8,
    normalCount: UInt8,
    bracket: TupletBracketDisplay = .automatic,
    placement: AttachmentPlacement = .automatic
  ) {
    precondition(!id.isEmpty)
    precondition(eventIDs.count >= 2)
    precondition(actualCount >= 2 && normalCount >= 1)
    self.id = id
    self.eventIDs = eventIDs
    self.actualCount = actualCount
    self.normalCount = normalCount
    self.bracket = bracket
    self.placement = placement
  }
}

/// Raw-value kinds allow MusicXML/SMuFL importers to preserve new spanner types
/// without waiting for a library release that adds a closed enum case.
public struct NotationSpannerKind: RawRepresentable, Hashable, Sendable, Codable {
  public let rawValue: String

  public init(rawValue: String) {
    precondition(!rawValue.isEmpty, "A spanner kind cannot be empty")
    self.rawValue = rawValue
  }

  public static let slur = Self(rawValue: "slur")
  public static let tie = Self(rawValue: "tie")
  public static let crescendo = Self(rawValue: "hairpin.crescendo")
  public static let diminuendo = Self(rawValue: "hairpin.diminuendo")
  public static let pedal = Self(rawValue: "pedal")
  public static let glissando = Self(rawValue: "glissando")
  public static let ottava = Self(rawValue: "ottava")
}

public struct NotationSpanner: Identifiable, Hashable, Sendable, Codable {
  public let id: String
  public let kind: NotationSpannerKind
  public let startEventID: NotationEventID
  public let endEventID: NotationEventID
  public let placement: AttachmentPlacement

  public init(
    id: String,
    kind: NotationSpannerKind,
    startEventID: NotationEventID,
    endEventID: NotationEventID,
    placement: AttachmentPlacement = .automatic
  ) {
    self.id = id
    self.kind = kind
    self.startEventID = startEventID
    self.endEventID = endEventID
    self.placement = placement
  }
}

public enum NotationBarlineStyle: String, Hashable, Sendable, Codable {
  case regular
  case double
  case final
  case repeatStart
  case repeatEnd
  case repeatBoth
}

/// A structural barline at an exact score time. `repeatCount` is meaningful for
/// repeat-end and repeat-both barlines; two means the enclosed passage is played twice.
public struct NotationBarline: Hashable, Sendable, Codable {
  public let onset: Rational
  public let style: NotationBarlineStyle
  public let repeatCount: UInt8

  public init(onset: Rational, style: NotationBarlineStyle, repeatCount: UInt8 = 2) {
    precondition(onset >= .zero, "A barline onset cannot be negative")
    precondition(repeatCount >= 2, "A repeated passage must be played at least twice")
    self.onset = onset
    self.style = style
    self.repeatCount = repeatCount
  }
}

/// A numbered alternate ending (volta / first and second ending) expressed on
/// the exact score timeline. The range is start-inclusive and end-exclusive.
public struct NotationVolta: Identifiable, Hashable, Sendable, Codable {
  public let id: String
  public let startOnset: Rational
  public let endOnset: Rational
  public let numbers: [UInt8]
  public let hasEndHook: Bool

  public init(
    id: String,
    startOnset: Rational,
    endOnset: Rational,
    numbers: [UInt8],
    hasEndHook: Bool = true
  ) {
    precondition(!id.isEmpty)
    precondition(startOnset >= .zero && endOnset > startOnset)
    precondition(!numbers.isEmpty && numbers.allSatisfy { $0 > 0 })
    self.id = id
    self.startOnset = startOnset
    self.endOnset = endOnset
    self.numbers = numbers
    self.hasEndHook = hasEndHook
  }
}

/// An instantaneous metronome change on the exact score timeline. BPM is
/// normalized to quarter-note beats, matching MusicXML's `sound tempo` value.
public struct NotationTempoChange: Hashable, Sendable, Codable {
  public let onset: Rational
  public let beatsPerMinute: Double

  public init(onset: Rational, beatsPerMinute: Double) {
    precondition(onset >= .zero)
    precondition(beatsPerMinute > 0 && beatsPerMinute.isFinite)
    self.onset = onset
    self.beatsPerMinute = beatsPerMinute
  }
}
