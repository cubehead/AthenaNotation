import Foundation

/// Platform-neutral drawing output consumed by the Android Compose adapter.
/// Coordinates use density-independent scene units with the origin at top-left.
public struct AndroidRenderScene: Hashable, Sendable, Codable {
  public let width: Double
  public let height: Double
  public let commands: [AndroidRenderCommand]

  public init(width: Double, height: Double, commands: [AndroidRenderCommand]) {
    precondition(width > 0 && height > 0)
    self.width = width
    self.height = height
    self.commands = commands
  }

  public func jsonString(prettyPrinted: Bool = false) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : []
    let data = try encoder.encode(self)
    guard let value = String(data: data, encoding: .utf8) else {
      throw AndroidRenderSceneError.invalidUTF8
    }
    return value
  }
}

public enum AndroidRenderSceneError: Error {
  case invalidUTF8
}

public struct AndroidRenderPoint: Hashable, Sendable, Codable {
  public let x: Double
  public let y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

public enum AndroidPathVerb: String, Hashable, Sendable, Codable {
  case move
  case line
  case quadratic
  case close
}

public struct AndroidPathElement: Hashable, Sendable, Codable {
  public let verb: AndroidPathVerb
  public let points: [AndroidRenderPoint]

  public init(verb: AndroidPathVerb, points: [AndroidRenderPoint] = []) {
    self.verb = verb
    self.points = points
  }
}

public enum AndroidRenderCommandKind: String, Hashable, Sendable, Codable {
  case line
  case rectangle
  case ellipse
  case polygon
  case path
  case glyph
  case text
}

/// A deliberately flat wire model so Kotlin can decode it with Android's
/// built-in JSONObject without requiring a serialization dependency.
public struct AndroidRenderCommand: Hashable, Sendable, Codable {
  public let kind: AndroidRenderCommandKind
  public let role: String
  public let eventID: String?
  public let color: String
  public let fill: Bool
  public let lineWidth: Double
  public let x: Double?
  public let y: Double?
  public let width: Double?
  public let height: Double?
  public let points: [AndroidRenderPoint]
  public let path: [AndroidPathElement]
  public let text: String?
  public let fontSize: Double?

  public init(
    kind: AndroidRenderCommandKind,
    role: String,
    eventID: String? = nil,
    color: String = "#FF000000",
    fill: Bool = false,
    lineWidth: Double = 1,
    x: Double? = nil,
    y: Double? = nil,
    width: Double? = nil,
    height: Double? = nil,
    points: [AndroidRenderPoint] = [],
    path: [AndroidPathElement] = [],
    text: String? = nil,
    fontSize: Double? = nil
  ) {
    self.kind = kind
    self.role = role
    self.eventID = eventID
    self.color = color
    self.fill = fill
    self.lineWidth = lineWidth
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.points = points
    self.path = path
    self.text = text
    self.fontSize = fontSize
  }
}

