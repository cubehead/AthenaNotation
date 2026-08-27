public enum NotationEventContent: Hashable, Sendable, Codable {
  case notes([NotatedPitch])
  case rest
}

public enum PianoFinger: UInt8, Hashable, Sendable, Codable, CaseIterable {
  case thumb = 1
  case index = 2
  case middle = 3
  case ring = 4
  case little = 5
}

public enum AttachmentAnchor: Hashable, Sendable, Codable {
  /// Attaches to the event as a whole, such as an articulation or text instruction.
  case event
  /// Attaches to one pitch in a chord. The index addresses `content.notes`.
  case notehead(index: Int)
}

public enum AttachmentPlacement: String, Hashable, Sendable, Codable {
  case automatic
  case above
  case below
  case left
  case right
}

/// Open-ended attachment content keeps uncommon and modern notation representable
/// before AthenaNotation has a specialized layout implementation for it.
public enum AttachmentContent: Hashable, Sendable, Codable {
  case fingering(PianoFinger)
  case smuflGlyph(name: String)
  case text(String)
  case technique(name: String)
  /// Standard engraved dynamic text such as p, mf, sfz or fp. Importers may
  /// preserve an explicit playback velocity when the source format supplies it.
  case dynamic(label: String, velocity: UInt8?)
}

public struct NotationAttachment: Identifiable, Hashable, Sendable, Codable {
  public let id: String
  public let anchor: AttachmentAnchor
  public let placement: AttachmentPlacement
  public let content: AttachmentContent

  public init(
    id: String,
    anchor: AttachmentAnchor = .event,
    placement: AttachmentPlacement = .automatic,
    content: AttachmentContent
  ) {
    if case .notehead(let index) = anchor {
      precondition(index >= 0, "A notehead attachment index cannot be negative")
    }
    self.id = id
    self.anchor = anchor
    self.placement = placement
    self.content = content
  }
}

public struct NotationEvent: Identifiable, Hashable, Sendable, Codable {
  public let id: NotationEventID
  public let content: NotationEventContent
  public let duration: Rational
  /// The engraved note value when it differs from performed time, as in tuplets.
  public let writtenDuration: Rational?
  public let dotCount: UInt8
  public let staffID: String
  public let hand: Hand?
  /// Optional performed MIDI velocity. Engraved scores may leave this unset;
  /// MIDI imports preserve it for downstream dynamics and visualization.
  public let velocity: UInt8?
  public let attachments: [NotationAttachment]

  public init(
    id: NotationEventID,
    content: NotationEventContent,
    duration: Rational,
    writtenDuration: Rational? = nil,
    dotCount: UInt8 = 0,
    staffID: String,
    hand: Hand? = nil,
    velocity: UInt8? = nil,
    attachments: [NotationAttachment] = []
  ) {
    precondition(duration > .zero, "Notation events must have positive duration")
    if let writtenDuration {
      precondition(writtenDuration > .zero, "Written durations must be positive")
    }
    precondition(dotCount <= 3, "AthenaNotation currently supports up to three dots")
    if let velocity {
      precondition((1...127).contains(velocity), "MIDI velocity must be in 1...127")
    }
    self.id = id
    self.content = content
    self.duration = duration
    self.writtenDuration = writtenDuration
    self.dotCount = dotCount
    self.staffID = staffID
    self.hand = hand
    self.velocity = velocity
    self.attachments = attachments
  }

  public var engravingDuration: Rational {
    writtenDuration ?? duration
  }

  /// Nominal written span before any tuplet scaling is applied.
  public var dottedWrittenDuration: Rational {
    var result = engravingDuration
    var addition = engravingDuration
    for _ in 0..<dotCount {
      addition = addition / Rational(2)
      result = result + addition
    }
    return result
  }
}
