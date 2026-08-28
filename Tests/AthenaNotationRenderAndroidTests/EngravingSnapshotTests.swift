import AthenaNotationCore
import AthenaNotationRenderAndroid
import Foundation
import Testing

@Test func grandStaffEngravingMatchesVisualFixture() throws {
  try assertSVGSnapshot(
    named: "grand-staff",
    scene: AndroidScoreRenderer(
      options: .init(width: 960, height: 520, preferredSystemCount: 1)
    ).render(
      score: snapshotGrandStaffScore(),
      playbackEventIDs: [NotationEventID(rawValue: "upper-2")]
    )
  )
}

@Test func expressiveEngravingMatchesVisualFixture() throws {
  try assertSVGSnapshot(
    named: "expressive-notation",
    scene: AndroidScoreRenderer(
      options: .init(width: 960, height: 720, preferredSystemCount: 2)
    ).render(score: snapshotExpressiveScore())
  )
}

private func assertSVGSnapshot(named name: String, scene: AndroidRenderScene) throws {
  let rendered = SVGSnapshotEncoder().encode(scene)
  let fixture = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("__Snapshots__")
    .appendingPathComponent("\(name).svg")
  if ProcessInfo.processInfo.environment["ATHENA_RECORD_SNAPSHOTS"] == "1" {
    try FileManager.default.createDirectory(
      at: fixture.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data(rendered.utf8).write(to: fixture)
  }
  let expected = try String(contentsOf: fixture, encoding: .utf8)
    .replacingOccurrences(of: "\r\n", with: "\n")
  #expect(rendered == expected, "Visual fixture changed: \(fixture.path)")
}

private struct SVGSnapshotEncoder {
  func encode(_ scene: AndroidRenderScene) -> String {
    var lines = [
      #"<?xml version="1.0" encoding="UTF-8"?>"#,
      #"<svg xmlns="http://www.w3.org/2000/svg" width="\#(number(scene.width))" height="\#(number(scene.height))" viewBox="0 0 \#(number(scene.width)) \#(number(scene.height))">"#,
      #"  <style>@font-face { font-family: Bravura; src: url('../../../Sources/AthenaNotationRenderAndroid/Resources/Bravura.otf'); }</style>"#,
    ]
    lines.append(contentsOf: scene.commands.map(element))
    lines.append("</svg>")
    return lines.joined(separator: "\n") + "\n"
  }

  private func element(_ command: AndroidRenderCommand) -> String {
    let metadata = #"data-role="\#(escape(command.role))""#
      + (command.eventID.map { #" data-event="\#(escape($0))""# } ?? "")
    let style = paint(command)
    switch command.kind {
    case .line:
      guard command.points.count >= 2 else { return "<!-- invalid line -->" }
      return #"  <line \#(metadata) x1="\#(number(command.points[0].x))" y1="\#(number(command.points[0].y))" x2="\#(number(command.points[1].x))" y2="\#(number(command.points[1].y))" \#(style)/>"#
    case .rectangle:
      return #"  <rect \#(metadata) x="\#(number(command.x))" y="\#(number(command.y))" width="\#(number(command.width))" height="\#(number(command.height))" \#(style)/>"#
    case .ellipse:
      let width = command.width ?? 0
      let height = command.height ?? 0
      return #"  <ellipse \#(metadata) cx="\#(number((command.x ?? 0) + width / 2))" cy="\#(number((command.y ?? 0) + height / 2))" rx="\#(number(width / 2))" ry="\#(number(height / 2))" \#(style)/>"#
    case .polygon:
      let points = command.points.map { "\(number($0.x)),\(number($0.y))" }.joined(separator: " ")
      return #"  <polygon \#(metadata) points="\#(points)" \#(style)/>"#
    case .path:
      let data = command.path.map(pathElement).joined(separator: " ")
      return #"  <path \#(metadata) d="\#(data)" \#(style)/>"#
    case .glyph, .text:
      let family = command.kind == .glyph ? #" font-family="Bravura""# : ""
      return #"  <text \#(metadata) x="\#(number(command.x))" y="\#(number(command.y))" font-size="\#(number(command.fontSize))" text-anchor="middle" dominant-baseline="central"\#(family) \#(style)>\#(escape(command.text ?? ""))</text>"#
    }
  }

  private func pathElement(_ element: AndroidPathElement) -> String {
    switch element.verb {
    case .move:
      guard let point = element.points.first else { return "" }
      return "M \(number(point.x)) \(number(point.y))"
    case .line:
      guard let point = element.points.first else { return "" }
      return "L \(number(point.x)) \(number(point.y))"
    case .quadratic:
      guard element.points.count >= 2 else { return "" }
      return "Q \(number(element.points[0].x)) \(number(element.points[0].y)) \(number(element.points[1].x)) \(number(element.points[1].y))"
    case .close:
      return "Z"
    }
  }

  private func paint(_ command: AndroidRenderCommand) -> String {
    let color = command.color.count == 9 ? "#" + command.color.dropFirst(3) : command.color
    let alpha: Double = command.color.count == 9
      ? Double(Int(command.color.dropFirst().prefix(2), radix: 16) ?? 255) / 255
      : 1
    let opacity = alpha < 1 ? #" opacity="\#(number(alpha))""# : ""
    if command.fill {
      return #"fill="\#(color)" stroke="none"\#(opacity)"#
    }
    return #"fill="none" stroke="\#(color)" stroke-width="\#(number(command.lineWidth))" stroke-linecap="round" stroke-linejoin="round"\#(opacity)"#
  }

  private func number(_ value: Double?) -> String {
    guard let value else { return "0" }
    let rendered = String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), value)
    return rendered.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
  }

  private func escape(_ value: String) -> String {
    value
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
  }
}

private func snapshotGrandStaffScore() -> NotationScore {
  let upper: [NotationEvent] = [
    snapshotEvent(
      "upper-1", pitches: [(60, .c, 4)], duration: Rational(1, 8), staff: "treble",
      attachments: [NotationAttachment(id: "finger", content: .fingering(.thumb))]
    ),
    snapshotEvent(
      "upper-2", pitches: [(64, .e, 4), (65, .f, 4)],
      duration: Rational(1, 8), staff: "treble"
    ),
    snapshotEvent(
      "upper-3", pitches: [(64, .e, 4)], duration: Rational(1, 8), staff: "treble"
    ),
    snapshotEvent(
      "upper-4", pitches: [(66, .f, 4)], duration: Rational(1, 8), staff: "treble"
    ),
  ]
  let lower = [
    snapshotEvent("lower-1", pitches: [(48, .c, 3)], duration: Rational(1, 2), staff: "bass"),
    snapshotEvent("lower-2", pitches: [(50, .d, 3)], duration: Rational(1, 2), staff: "bass"),
  ]
  return NotationScore(
    staves: [
      NotationStaff(id: "treble", clef: .treble, keySignature: .gMajor),
      NotationStaff(id: "bass", clef: .bass, keySignature: .gMajor),
    ],
    voices: [NotationVoice(id: "upper", events: upper), NotationVoice(id: "lower", events: lower)],
    barlines: [NotationBarline(onset: .one, style: .final)]
  )
}

private func snapshotExpressiveScore() -> NotationScore {
  let steps: [DiatonicStep] = [.c, .d, .e, .f, .g, .a, .b, .c]
  var events: [NotationEvent] = []
  for index in 0..<8 {
    let attachments: [NotationAttachment] = index == 0
      ? [
          NotationAttachment(
            id: "mf", placement: .below,
            content: .dynamic(label: "mf", velocity: 72)
          ),
          NotationAttachment(
            id: "staccato", placement: .above,
            content: .smuflGlyph(name: "articStaccatoAbove")
          ),
        ] : []
    events.append(
      snapshotEvent(
        "expression-\(index + 1)",
        pitches: [(UInt8(60 + index), steps[index], index == 7 ? 5 : 4)],
        duration: Rational(1, 8),
        staff: "treble",
        attachments: attachments
      )
    )
  }
  return NotationScore(
    staves: [NotationStaff(id: "treble", clef: .treble)],
    voices: [NotationVoice(id: "voice", events: events)],
    spanners: [
      NotationSpanner(id: "slur", kind: .slur, startEventID: events[0].id, endEventID: events[3].id),
      NotationSpanner(id: "hairpin", kind: .crescendo, startEventID: events[1].id, endEventID: events[5].id, placement: .below),
      NotationSpanner(id: "pedal", kind: .pedal, startEventID: events[0].id, endEventID: events[7].id, placement: .below),
    ],
    tuplets: [NotationTuplet(
      id: "triplet",
      eventIDs: [events[0].id, events[1].id, events[2].id],
      actualCount: 3,
      normalCount: 2
    )],
    barlines: [
      NotationBarline(onset: .zero, style: .repeatStart),
      NotationBarline(onset: .one, style: .repeatEnd),
    ],
    voltas: [NotationVolta(id: "ending", startOnset: .zero, endOnset: Rational(1, 2), numbers: [1])]
  )
}

private func snapshotEvent(
  _ id: String,
  pitches: [(UInt8, DiatonicStep, Int)],
  duration: Rational,
  staff: String,
  attachments: [NotationAttachment] = []
) -> NotationEvent {
  NotationEvent(
    id: .init(rawValue: id),
    content: .notes(pitches.map {
      NotatedPitch(midi: .init(rawValue: $0.0), step: $0.1, octave: $0.2)
    }),
    duration: duration,
    staffID: staff,
    attachments: attachments
  )
}
