#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif
import CoreGraphics

/// Enables individual input behaviors without forcing applications to use
/// score taps for playback seeking.
public struct NativeScoreInteractionOptions: OptionSet, Hashable, Sendable {
  public let rawValue: UInt8

  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  /// Resolve a tap to the nearest semantic score event.
  public static let eventTap = Self(rawValue: 1 << 0)
  public static let `default`: Self = [.eventTap]
}

/// Device-independent semantic result of touching/clicking the score canvas.
public struct NativeScoreInteractionEvent: Hashable, Sendable {
  public let eventID: NotationEventID
  public let systemIndex: Int
  public let location: CGPoint

  public init(eventID: NotationEventID, systemIndex: Int, location: CGPoint) {
    self.eventID = eventID
    self.systemIndex = systemIndex
    self.location = location
  }
}

public typealias NativeScoreInteractionHandler = (NativeScoreInteractionEvent) -> Void
