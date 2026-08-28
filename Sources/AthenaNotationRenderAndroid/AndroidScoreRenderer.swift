#if SWIFT_PACKAGE
  import AthenaNotationCore
  import AthenaNotationLayout
  import AthenaScoreAnalysis
#endif
import Foundation

private enum AndroidEngravingMetrics {
  static let stemWidth = 1.4
  static let filledNoteheadWidth = 11.8
  static let wholeNoteheadWidth = 16.88

  static func noteheadWidth(for glyph: AndroidSMuFLGlyph) -> Double {
    glyph == .noteheadWhole ? wholeNoteheadWidth : filledNoteheadWidth
  }

  static func flagBounds(for glyph: AndroidSMuFLGlyph) -> (width: Double, height: Double)? {
    switch glyph {
    case .flag8thUp: (10.56, 32.88)
    case .flag8thDown: (12.24, 32.88)
    case .flag16thUp: (11.16, 32.60)
    case .flag16thDown: (11.88, 32.88)
    default: nil
    }
  }
}

/// String-only facade intended for swift-java/JNI bindings. Keeping the wire
/// boundary as UTF-8 JSON avoids exposing Swift value-layout details to Kotlin.
public struct AndroidRenderBridge: Sendable {
  public init() {}

  public func renderScoreJSON(
    _ scoreJSON: String,
    width: Double,
    height: Double,
    preferredSystemCount: Int = 1,
    accessibilityLocaleIdentifier: String = "en_US",
    playbackEventIDs: [String] = []
  ) throws -> String {
    try renderScoreJSON(
      scoreJSON,
      width: width,
      height: height,
      preferredSystemCount: preferredSystemCount,
      accessibilityLocaleIdentifier: accessibilityLocaleIdentifier,
      playbackEventIDs: playbackEventIDs,
      showsPlaybackCursor: true
    )
  }

  public func renderScoreJSON(
    _ scoreJSON: String,
    width: Double,
    height: Double,
    preferredSystemCount: Int = 1,
    accessibilityLocaleIdentifier: String = "en_US",
    playbackEventIDs: [String] = [],
    showsPlaybackCursor: Bool
  ) throws -> String {
    try renderScoreJSON(
      scoreJSON,
      width: width,
      height: height,
      preferredSystemCount: preferredSystemCount,
      accessibilityLocaleIdentifier: accessibilityLocaleIdentifier,
      playbackEventIDs: playbackEventIDs,
      showsPlaybackCursor: showsPlaybackCursor,
      automaticSystemBreaks: false
    )
  }

  public func renderScoreJSON(
    _ scoreJSON: String,
    width: Double,
    height: Double,
    preferredSystemCount: Int = 1,
    accessibilityLocaleIdentifier: String = "en_US",
    playbackEventIDs: [String] = [],
    automaticSystemBreaks: Bool,
    minimumSystemHeight: Double = 220
  ) throws -> String {
    try renderScoreJSON(
      scoreJSON,
      width: width,
      height: height,
      preferredSystemCount: preferredSystemCount,
      accessibilityLocaleIdentifier: accessibilityLocaleIdentifier,
      playbackEventIDs: playbackEventIDs,
      showsPlaybackCursor: true,
      automaticSystemBreaks: automaticSystemBreaks,
      minimumSystemHeight: minimumSystemHeight
    )
  }

  public func renderScoreJSON(
    _ scoreJSON: String,
    width: Double,
    height: Double,
    preferredSystemCount: Int = 1,
    accessibilityLocaleIdentifier: String = "en_US",
    playbackEventIDs: [String] = [],
    showsPlaybackCursor: Bool,
    automaticSystemBreaks: Bool,
    minimumSystemHeight: Double = 220
  ) throws -> String {
    let score = try JSONDecoder().decode(NotationScore.self, from: Data(scoreJSON.utf8))
    let ids = Set(playbackEventIDs.map { NotationEventID(rawValue: $0) })
    return try AndroidScoreRenderer(options: .init(
      width: width,
      height: height,
      preferredSystemCount: preferredSystemCount,
      accessibilityLocaleIdentifier: accessibilityLocaleIdentifier,
      showsPlaybackCursor: showsPlaybackCursor,
      automaticSystemBreaks: automaticSystemBreaks,
      minimumSystemHeight: minimumSystemHeight
    )).renderJSON(score: score, playbackEventIDs: ids)
  }
}

/// Produces a deterministic, Codable display list for Jetpack Compose Canvas.
/// It contains no SwiftUI, CoreText, UIKit, or Android framework dependency.
public struct AndroidScoreRenderer: Sendable {
  public struct Options: Hashable, Sendable {
    public var width: Double
    public var height: Double
    public var preferredSystemCount: Int
    public var horizontalPadding: Double
    public var lineSpacing: Double
    public var interStaffGap: Double
    public var showsPlaybackCursor: Bool
    public var automaticSystemBreaks: Bool
    public var minimumSystemHeight: Double
    public var accessibilityLocaleIdentifier: String

    public init(
      width: Double = 1_024,
      height: Double = 720,
      preferredSystemCount: Int = 1,
      horizontalPadding: Double = 36,
      lineSpacing: Double = 12,
      interStaffGap: Double = 48,
      accessibilityLocaleIdentifier: String = "en_US"
    ) {
      self.init(
        width: width,
        height: height,
        preferredSystemCount: preferredSystemCount,
        horizontalPadding: horizontalPadding,
        lineSpacing: lineSpacing,
        interStaffGap: interStaffGap,
        accessibilityLocaleIdentifier: accessibilityLocaleIdentifier,
        showsPlaybackCursor: true
      )
    }

    public init(
      width: Double = 1_024,
      height: Double = 720,
      preferredSystemCount: Int = 1,
      horizontalPadding: Double = 36,
      lineSpacing: Double = 12,
      interStaffGap: Double = 48,
      accessibilityLocaleIdentifier: String = "en_US",
      showsPlaybackCursor: Bool
    ) {
      self.init(
        width: width,
        height: height,
        preferredSystemCount: preferredSystemCount,
        horizontalPadding: horizontalPadding,
        lineSpacing: lineSpacing,
        interStaffGap: interStaffGap,
        accessibilityLocaleIdentifier: accessibilityLocaleIdentifier,
        showsPlaybackCursor: showsPlaybackCursor,
        automaticSystemBreaks: false
      )
    }

    public init(
      width: Double = 1_024,
      height: Double = 720,
      preferredSystemCount: Int = 1,
      horizontalPadding: Double = 36,
      lineSpacing: Double = 12,
      interStaffGap: Double = 48,
      accessibilityLocaleIdentifier: String = "en_US",
      automaticSystemBreaks: Bool,
      minimumSystemHeight: Double = 220
    ) {
      self.init(
        width: width,
        height: height,
        preferredSystemCount: preferredSystemCount,
        horizontalPadding: horizontalPadding,
        lineSpacing: lineSpacing,
        interStaffGap: interStaffGap,
        accessibilityLocaleIdentifier: accessibilityLocaleIdentifier,
        showsPlaybackCursor: true,
        automaticSystemBreaks: automaticSystemBreaks,
        minimumSystemHeight: minimumSystemHeight
      )
    }

    public init(
      width: Double = 1_024,
      height: Double = 720,
      preferredSystemCount: Int = 1,
      horizontalPadding: Double = 36,
      lineSpacing: Double = 12,
      interStaffGap: Double = 48,
      accessibilityLocaleIdentifier: String = "en_US",
      showsPlaybackCursor: Bool,
      automaticSystemBreaks: Bool,
      minimumSystemHeight: Double = 220
    ) {
      precondition(width > 0 && height > 0)
      precondition(preferredSystemCount > 0)
      precondition(horizontalPadding >= 0 && lineSpacing > 0 && interStaffGap >= 0)
      precondition(minimumSystemHeight > 0)
      self.width = width
      self.height = height
      self.preferredSystemCount = preferredSystemCount
      self.horizontalPadding = horizontalPadding
      self.lineSpacing = lineSpacing
      self.interStaffGap = interStaffGap
      self.showsPlaybackCursor = showsPlaybackCursor
      self.automaticSystemBreaks = automaticSystemBreaks
      self.minimumSystemHeight = minimumSystemHeight
      self.accessibilityLocaleIdentifier = accessibilityLocaleIdentifier
    }
  }

  public let options: Options

  public init(options: Options = .init()) {
    self.options = options
  }

  public func render(
    score: NotationScore,
    playbackEventIDs: Set<NotationEventID> = []
  ) -> AndroidRenderScene {
    let staves = score.staves.isEmpty
      ? [NotationStaff(id: "treble", clef: .treble)] : score.staves
    let maximumKeyAccidentals = staves.map(\.keySignature.accidentalCount).max() ?? 0
    let notationStart = 150.0 + Double(maximumKeyAccidentals) * 9
    let endX = options.width - options.horizontalPadding
    let availableWidth = max(endX - notationStart, 1)
    let formatter = HorizontalFormatter()
    let timingInputs = formatter.makeInputs(voices: score.voices)
    let visibleAccidentals = AccidentalPlanner().visibleAccidentals(
      inputs: timingInputs,
      staves: staves
    )
    let metrics = Dictionary(
      uniqueKeysWithValues: score.voices.flatMap { voice in
        voice.events.map { event in
          let accidental = !(visibleAccidentals[event.id]?.isEmpty ?? true)
          return (
            event.id,
            EventLayoutMetrics(
              noteWidth: 16,
              leftExtent: accidental ? 20 : 2,
              rightExtent: max(
                event.engravingDuration <= Rational(1, 8) ? 18 : 2,
                event.dotCount > 0 ? 12 + Double(event.dotCount) * 8 : 2
              )
            )
          )
        }
      })
    let inputs = formatter.makeInputs(voices: score.voices, metrics: metrics)
    let measureDuration = Rational(
      Int64(staves.first?.timeSignature.numerator ?? 4),
      Int64(staves.first?.timeSignature.denominator ?? 4)
    )
    let systemFormatter = SystemFormatter(horizontalFormatter: formatter)
    let layouts = options.automaticSystemBreaks
      ? systemFormatter.format(
        inputs: inputs,
        fittingWidth: availableWidth,
        measureDuration: measureDuration
      )
      : systemFormatter.format(
        inputs: inputs,
        systemCount: options.preferredSystemCount,
        justifyTo: availableWidth,
        measureDuration: measureDuration
      )
    let stemDirections = voiceStemDirections(score.voices)
    let spanners = SpannerPlanner().segments(spanners: score.spanners, layouts: layouts)
    let tuplets = TupletPlanner().segments(tuplets: score.tuplets, layouts: layouts)
    let scoreEnd = score.voices.map { voice in
      voice.events.reduce(.zero) { $0 + $1.duration }
    }.max() ?? .zero
    let voltas = VoltaPlanner().segments(
      voltas: score.voltas,
      layouts: layouts,
      scoreEnd: scoreEnd
    )
    let systemGeometries = makeSystemVerticalGeometries(
      layouts: layouts,
      staves: staves,
      stemDirections: stemDirections,
      spannerSegments: spanners,
      tupletSegments: tuplets,
      voltaSegments: voltas
    )
    let measuredHeight = systemGeometries.reduce(0) { $0 + $1.height }
    let sceneHeight = options.automaticSystemBreaks
      ? max(options.height, measuredHeight)
      : options.height
    let leadingVerticalSpace = max(0, (sceneHeight - measuredHeight) / 2)

    var commands: [AndroidRenderCommand] = [
      rectangle(
        role: "background", x: 0, y: 0,
        width: options.width, height: sceneHeight,
        color: "#FFFFFFFF", fill: true
      )
    ]
    var systemTop = leadingVerticalSpace
    var sceneSystems: [AndroidRenderSystem] = []

    for (systemIndex, layout) in layouts.enumerated() {
      let geometry = systemGeometries[systemIndex]
      sceneSystems.append(AndroidRenderSystem(
        index: systemIndex,
        y: systemTop,
        height: geometry.height
      ))
      let firstStaffTop = systemTop + geometry.firstStaffTopOffset
      let staffTops = Dictionary(
        uniqueKeysWithValues: staves.enumerated().map { index, staff in
          (
            staff.id,
            firstStaffTop
              + Double(index) * (options.lineSpacing * 4 + options.interStaffGap)
          )
        })
      let beamGroups = BeamPlanner().groups(inputs: layout.events.map(\.input))
      let beamLayout = makeBeams(
        groups: beamGroups,
        layout: layout,
        staves: staves,
        staffTops: staffTops,
        notationStart: notationStart,
        stemDirections: stemDirections
      )

      for positioned in layout.events
      where options.showsPlaybackCursor
        && playbackEventIDs.contains(positioned.input.event.id)
      {
        let x = notationStart + positioned.x
        let bottom = (staffTops[staves.last?.id ?? ""] ?? firstStaffTop)
          + options.lineSpacing * 4
        commands.append(
          rectangle(
            role: "playbackHighlight",
            eventID: positioned.input.event.id.rawValue,
            x: x - 5,
            y: firstStaffTop - 22,
            width: 10,
            height: bottom - firstStaffTop + 44,
            color: "#333B82F6",
            fill: true
          ))
      }

      for staff in staves {
        let top = staffTops[staff.id] ?? firstStaffTop
        commands.append(contentsOf: staffCommands(top: top, endX: endX))
        commands.append(contentsOf: headerCommands(
          staff: staff,
          top: top,
          showTimeSignature: systemIndex == 0
        ))
      }
      commands.append(contentsOf: barlineCommands(
        score: score,
        layout: layout,
        nextSystemOnset: layouts.indices.contains(systemIndex + 1)
          ? layouts[systemIndex + 1].contexts.first?.onset : nil,
        staffTops: staves.compactMap { staffTops[$0.id] },
        notationStart: notationStart,
        endX: endX,
        measureDuration: measureDuration
      ))
      commands.append(contentsOf: beamLayout.commands)

      for positioned in layout.events {
        let event = positioned.input.event
        guard let staff = staves.first(where: { $0.id == event.staffID }) else { continue }
        let top = staffTops[staff.id] ?? firstStaffTop
        let x = notationStart + positioned.x
        switch event.content {
        case .rest:
          commands.append(contentsOf: restCommands(
            event: event,
            voiceStemUp: stemDirections[positioned.input.voiceID],
            x: x,
            top: top
          ))
        case .notes(let pitches):
          commands.append(contentsOf: noteCommands(
            pitches: pitches,
            event: event,
            staff: staff,
            x: x,
            top: top,
            beamStem: beamLayout.stems[event.id],
            voiceStemUp: stemDirections[positioned.input.voiceID],
            visibleAccidentals: visibleAccidentals[event.id, default: []]
          ))
        }
      }
      commands.append(contentsOf: tupletCommands(
        tuplets.filter { $0.systemIndex == systemIndex },
        layout: layout,
        notationStart: notationStart,
        firstStaffTop: firstStaffTop
      ))
      commands.append(contentsOf: spannerCommands(
        spanners.filter { $0.systemIndex == systemIndex },
        score: score,
        layout: layout,
        staves: staves,
        staffTops: staffTops,
        notationStart: notationStart,
        endX: endX,
        stemDirections: stemDirections
      ))
      commands.append(contentsOf: voltaCommands(
        voltas.filter { $0.systemIndex == systemIndex },
        layout: layout,
        notationStart: notationStart,
        endX: endX,
        top: firstStaffTop
      ))
      systemTop += geometry.height
    }
    let accessibilityFormatter = ScoreAccessibilityFormatter(
      localeIdentifier: options.accessibilityLocaleIdentifier
    )
    let accessibility = ScoreNavigator(score: score).entries.map { entry in
      AndroidAccessibilityElement(
        eventID: entry.id.rawValue,
        label: accessibilityFormatter.label(for: entry),
        measureNumber: entry.measureNumber,
        beat: entry.beat.description,
        onset: entry.onset.description
      )
    }
    return AndroidRenderScene(
      width: options.width,
      height: sceneHeight,
      commands: commands,
      accessibility: accessibility,
      systems: sceneSystems
    )
  }

  public func renderJSON(
    score: NotationScore,
    playbackEventIDs: Set<NotationEventID> = [],
    prettyPrinted: Bool = false
  ) throws -> String {
    try render(score: score, playbackEventIDs: playbackEventIDs)
      .jsonString(prettyPrinted: prettyPrinted)
  }

  private func staffCommands(top: Double, endX: Double) -> [AndroidRenderCommand] {
    (0..<5).map { index in
      line(
        role: "staffLine",
        x1: options.horizontalPadding,
        y1: top + Double(index) * options.lineSpacing,
        x2: endX,
        y2: top + Double(index) * options.lineSpacing
      )
    }
  }

  private func headerCommands(
    staff: NotationStaff,
    top: Double,
    showTimeSignature: Bool
  ) -> [AndroidRenderCommand] {
    var result = [glyph(
      role: "clef",
      value: staff.clef == .bass ? .fClef : .gClef,
      x: options.horizontalPadding + 28,
      y: top + options.lineSpacing * 2,
      size: staff.clef == .bass ? 42 : 58
    )]
    let count = staff.keySignature.accidentalCount
    if count > 0 {
      let value: AndroidSMuFLGlyph = staff.keySignature.fifths > 0
        ? .accidentalSharp : .accidentalFlat
      let positions = staff.keySignature.fifths > 0
        ? (staff.clef == .bass ? [6, 3, 7, 4, 1, 5, 2] : [8, 5, 9, 6, 3, 7, 4])
        : (staff.clef == .bass ? [2, 5, 1, 4, 0, 3, -1] : [4, 7, 3, 6, 2, 5, 1])
      for index in 0..<count {
        result.append(glyph(
          role: "keySignature",
          value: value,
          x: options.horizontalPadding + 58 + Double(index) * 9,
          y: top + options.lineSpacing * 4
            - Double(positions[index]) * options.lineSpacing / 2,
          size: 27
        ))
      }
    }
    if showTimeSignature,
      let numerator = AndroidSMuFLGlyph.timeSignatureDigit(staff.timeSignature.numerator),
      let denominator = AndroidSMuFLGlyph.timeSignatureDigit(staff.timeSignature.denominator)
    {
      let x = options.horizontalPadding + 76 + Double(count) * 9
      result.append(glyph(
        role: "timeSignature", value: numerator,
        x: x, y: top + options.lineSpacing, size: 27
      ))
      result.append(glyph(
        role: "timeSignature", value: denominator,
        x: x, y: top + options.lineSpacing * 3, size: 27
      ))
    }
    return result
  }

  private func noteCommands(
    pitches: [NotatedPitch],
    event: NotationEvent,
    staff: NotationStaff,
    x: Double,
    top: Double,
    beamStem: BeamStem?,
    voiceStemUp: Bool?,
    visibleAccidentals: [VisibleAccidental]
  ) -> [AndroidRenderCommand] {
    guard !pitches.isEmpty else { return [] }
    let head: AndroidSMuFLGlyph = event.engravingDuration >= .one
      ? .noteheadWhole
      : (event.engravingDuration >= Rational(1, 2) ? .noteheadHalf : .noteheadBlack)
    let positions = pitches.map { staffPosition(for: $0, clef: staff.clef) }
    let ys = positions.map { top + options.lineSpacing * 4
      - Double($0) * options.lineSpacing / 2 }
    let automaticUp = Double(positions.reduce(0, +)) / Double(positions.count) < 4
    let stemUp = beamStem?.isUp ?? voiceStemUp ?? automaticUp
    let accidentalIndices = Set(visibleAccidentals.map(\.pitchIndex))
    let placements = ChordPlanner().placements(
      staffPositions: positions,
      stemUp: stemUp,
      accidentalPitchIndices: accidentalIndices
    )
    let stemWidth = AndroidEngravingMetrics.stemWidth
    let noteheadWidth = AndroidEngravingMetrics.noteheadWidth(for: head)
    let noteAdvance = ChordPlanner().horizontalAdvance(
      noteheadWidth: noteheadWidth,
      stemWidth: stemWidth
    )
    let noteXs = placements.map { x + Double($0.noteheadColumn) * noteAdvance }
    var result: [AndroidRenderCommand] = []

    var stemEnd: Double?
    if event.engravingDuration < .one, let low = ys.max(), let high = ys.min() {
      let stemX = x + (stemUp
        ? noteheadWidth / 2 - stemWidth / 2
        : -noteheadWidth / 2 + stemWidth / 2)
      let start = stemUp ? low : high
      let fallback = (stemUp ? high : low)
        + (stemUp ? -options.lineSpacing * 3.5 : options.lineSpacing * 3.5)
      let end = beamStem?.endY ?? fallback
      stemEnd = end
      result.append(line(
        role: "stem", eventID: event.id.rawValue,
        x1: stemX, y1: start, x2: stemX, y2: end, lineWidth: stemWidth
      ))
      if beamStem == nil,
        let flag = flagGlyph(event.engravingDuration, stemUp: stemUp),
        let flagBounds = AndroidEngravingMetrics.flagBounds(for: flag)
      {
        result.append(glyph(
          role: "flag", eventID: event.id.rawValue,
          value: flag,
          x: stemX - stemWidth / 2 + flagBounds.width / 2,
          y: stemUp ? end + flagBounds.height / 2 : end - flagBounds.height / 2,
          size: 40
        ))
      }
    }

    let leftmost = noteXs.min() ?? x
    for placement in placements {
      let index = placement.pitchIndex
      let noteX = noteXs[index]
      let y = ys[index]
      result.append(contentsOf: ledgerLineCommands(
        staffPosition: placement.staffPosition,
        x: noteX,
        top: top
      ))
      if let column = placement.accidentalColumn,
        let visible = visibleAccidentals.first(where: { $0.pitchIndex == index }),
        let accidental = AndroidSMuFLGlyph.accidental(visible.accidental)
      {
        result.append(glyph(
          role: "accidental", eventID: event.id.rawValue,
          value: accidental,
          x: leftmost - noteheadWidth / 2 - 8 - Double(column) * 11,
          y: y,
          size: 28
        ))
      }
      result.append(glyph(
        role: "notehead", eventID: event.id.rawValue,
        value: head, x: noteX, y: y, size: 40
      ))
      let dotY = placement.staffPosition.isMultiple(of: 2)
        ? y - options.lineSpacing / 2 : y
      for dotIndex in 0..<Int(event.dotCount) {
        result.append(glyph(
          role: "augmentationDot", eventID: event.id.rawValue,
          value: .augmentationDot,
          x: noteX + noteheadWidth / 2 + 6 + Double(dotIndex) * 8,
          y: dotY,
          size: 40
        ))
      }
      result.append(contentsOf: attachmentCommands(
        event.attachments,
        noteheadIndex: index,
        eventID: event.id.rawValue,
        x: noteX,
        y: y,
        stemEndY: stemEnd
      ))
    }
    return result
  }

  private func restCommands(
    event: NotationEvent,
    voiceStemUp: Bool?,
    x: Double,
    top: Double
  ) -> [AndroidRenderCommand] {
    let value: AndroidSMuFLGlyph = event.engravingDuration >= .one
      ? .restWhole
      : (event.engravingDuration >= Rational(1, 2)
        ? .restHalf
        : (event.engravingDuration >= Rational(1, 4) ? .restQuarter : .restEighth))
    let y = top + options.lineSpacing * 2
      + (voiceStemUp.map { $0 ? -options.lineSpacing : options.lineSpacing } ?? 0)
    var result = [glyph(
      role: "rest", eventID: event.id.rawValue,
      value: value, x: x, y: y, size: 32
    )]
    for index in 0..<Int(event.dotCount) {
      result.append(glyph(
        role: "augmentationDot", eventID: event.id.rawValue,
        value: .augmentationDot, x: x + 15 + Double(index) * 8, y: y, size: 40
      ))
    }
    return result
  }

  private func ledgerLineCommands(staffPosition: Int, x: Double, top: Double)
    -> [AndroidRenderCommand]
  {
    var positions: [Int] = []
    if staffPosition < 0 {
      positions = Array(stride(from: -2, through: staffPosition, by: -2))
    } else if staffPosition > 8 {
      positions = Array(stride(from: 10, through: staffPosition, by: 2))
    }
    return positions.map { position in
      let y = top + options.lineSpacing * 4 - Double(position) * options.lineSpacing / 2
      return line(role: "ledgerLine", x1: x - 10, y1: y, x2: x + 10, y2: y, lineWidth: 1.2)
    }
  }

  private func attachmentCommands(
    _ attachments: [NotationAttachment],
    noteheadIndex: Int,
    eventID: String,
    x: Double,
    y: Double,
    stemEndY: Double?
  ) -> [AndroidRenderCommand] {
    attachments.compactMap { attachment in
      if attachment.anchor == .event, noteheadIndex != 0 { return nil }
      if case .notehead(let index) = attachment.anchor, index != noteheadIndex { return nil }
      let attachmentY = attachment.placement == .below
        ? max(y + 27, (stemEndY ?? y) + 13)
        : min(y - 27, (stemEndY ?? y) - 13)
      switch attachment.content {
      case .fingering(let finger):
        return text(role: "fingering", eventID: eventID, value: String(finger.rawValue), x: x, y: attachmentY, size: 13)
      case .smuflGlyph(let name):
        guard let value = AndroidSMuFLGlyph.named(name) else { return nil }
        return glyph(role: "attachment", eventID: eventID, value: value, x: x, y: attachmentY, size: 24)
      case .text(let value), .technique(let value):
        return text(role: "annotation", eventID: eventID, value: value, x: x, y: attachmentY, size: 12)
      case .dynamic(let label, _):
        return text(role: "dynamic", eventID: eventID, value: label, x: x, y: attachmentY, size: 16)
      }
    }
  }

  private func makeBeams(
    groups: [BeamGroup],
    layout: HorizontalLayout,
    staves: [NotationStaff],
    staffTops: [String: Double],
    notationStart: Double,
    stemDirections: [String: Bool]
  ) -> BeamLayout {
    let stemWidth = AndroidEngravingMetrics.stemWidth
    let noteheadHalfWidth = AndroidEngravingMetrics.filledNoteheadWidth / 2
    let positioned = Dictionary(uniqueKeysWithValues: layout.events.map { ($0.input.event.id, $0) })
    var stems: [NotationEventID: BeamStem] = [:]
    var commands: [AndroidRenderCommand] = []
    for group in groups {
      guard let staff = staves.first(where: { $0.id == group.staffID }),
        let top = staffTops[staff.id]
      else { continue }
      let nodes: [BeamNode] = group.eventIDs.compactMap { id in
        guard let item = positioned[id], case .notes(let pitches) = item.input.event.content,
          !pitches.isEmpty
        else { return nil }
        let positions = pitches.map { staffPosition(for: $0, clef: staff.clef) }
        let ys = positions.map { top + options.lineSpacing * 4
          - Double($0) * options.lineSpacing / 2 }
        return BeamNode(
          id: id,
          x: notationStart + item.x,
          topY: ys.min() ?? top,
          bottomY: ys.max() ?? top,
          averagePosition: Double(positions.reduce(0, +)) / Double(positions.count)
        )
      }
      guard nodes.count == group.eventIDs.count, let first = nodes.first, let last = nodes.last else {
        continue
      }
      let isUp = stemDirections[group.voiceID]
        ?? (nodes.map(\.averagePosition).reduce(0, +) / Double(nodes.count) < 4)
      let stemXs = nodes.map {
        $0.x + (isUp
          ? noteheadHalfWidth - stemWidth / 2
          : -noteheadHalfWidth + stemWidth / 2)
      }
      let references = nodes.map { isUp ? $0.topY : $0.bottomY }
      let dx = max((stemXs.last ?? first.x) - (stemXs.first ?? last.x), 1)
      let slopeRise = min(max((references.last! - references.first!) * 0.25, -options.lineSpacing), options.lineSpacing)
      let slope = slopeRise / dx
      let firstX = stemXs.first!
      let outerY: Double = isUp
        ? zip(references, stemXs).map { $0 - options.lineSpacing * 3.5 - slope * ($1 - firstX) }.min()!
        : zip(references, stemXs).map { $0 + options.lineSpacing * 3.5 - slope * ($1 - firstX) }.max()!
      for (node, stemX) in zip(nodes, stemXs) {
        let beamEdgeY = outerY + slope * (stemX - firstX)
        stems[node.id] = BeamStem(
          isUp: isUp,
          endY: beamEdgeY + (isUp ? stemWidth / 2 : -stemWidth / 2)
        )
      }
      for level in 0..<(group.eventBeamCounts.max() ?? 0) {
        let indices = group.eventBeamCounts.indices.filter { group.eventBeamCounts[$0] > level }
        guard let startIndex = indices.first, let endIndex = indices.last else { continue }
        let startX = stemXs[startIndex]
        var endX = stemXs[endIndex]
        if startIndex == endIndex {
          endX += startIndex == 0 ? 10 : -10
        }
        let offset = Double(level) * 7.5 * (isUp ? 1 : -1)
        let startY = outerY + slope * (startX - firstX) + offset
        let endY = outerY + slope * (endX - firstX) + offset
        let thickness = 5.0 * (isUp ? 1 : -1)
        commands.append(AndroidRenderCommand(
          kind: .polygon,
          role: "beam",
          fill: true,
          points: [
            .init(x: startX, y: startY), .init(x: endX, y: endY),
            .init(x: endX, y: endY + thickness), .init(x: startX, y: startY + thickness),
          ]
        ))
      }
    }
    return BeamLayout(stems: stems, commands: commands)
  }

  private func barlineCommands(
    score: NotationScore,
    layout: HorizontalLayout,
    nextSystemOnset: Rational?,
    staffTops: [Double],
    notationStart: Double,
    endX: Double,
    measureDuration: Rational
  ) -> [AndroidRenderCommand] {
    guard let top = staffTops.first, let last = staffTops.last else { return [] }
    let bottom = last + options.lineSpacing * 4
    func style(_ onset: Rational) -> NotationBarlineStyle? {
      score.barlines.first(where: { $0.onset == onset })?.style
    }
    var result = barline(.regular, x: options.horizontalPadding, top: top, bottom: bottom, staffTops: staffTops)
    if let onset = layout.contexts.first?.onset,
      style(onset) == .repeatStart || style(onset) == .repeatBoth
    {
      result += barline(.repeatStart, x: notationStart - 28, top: top, bottom: bottom, staffTops: staffTops)
    }
    for index in layout.contexts.indices.dropFirst() {
      let context = layout.contexts[index]
      let measure = context.onset / measureDuration
      guard measure.denominator == 1 else { continue }
      let x = notationStart + (layout.contexts[index - 1].x + context.x) / 2
      result += barline(style(context.onset) ?? .regular, x: x, top: top, bottom: bottom, staffTops: staffTops)
    }
    let trailing: NotationBarlineStyle
    if let nextSystemOnset {
      let nextStyle = style(nextSystemOnset)
      trailing = nextStyle == .repeatEnd || nextStyle == .repeatBoth ? .repeatEnd : .regular
    } else {
      let end = score.voices.map { $0.events.reduce(.zero) { $0 + $1.duration } }.max() ?? .zero
      trailing = style(end) ?? .regular
    }
    result += barline(trailing, x: endX, top: top, bottom: bottom, staffTops: staffTops)
    return result
  }

  private func barline(
    _ style: NotationBarlineStyle,
    x: Double,
    top: Double,
    bottom: Double,
    staffTops: [Double]
  ) -> [AndroidRenderCommand] {
    func stroke(_ offset: Double, _ width: Double) -> AndroidRenderCommand {
      line(role: "barline", x1: x + offset, y1: top, x2: x + offset, y2: bottom, lineWidth: width)
    }
    func dots(_ offset: Double) -> [AndroidRenderCommand] {
      staffTops.flatMap { staffTop in [1.5, 2.5].map { position in
        ellipse(role: "repeatDot", x: x + offset - 2.25, y: staffTop + options.lineSpacing * position - 2.25, width: 4.5, height: 4.5)
      }}
    }
    switch style {
    case .regular: return [stroke(0, 1.2)]
    case .double: return [stroke(-3, 1.2), stroke(3, 1.2)]
    case .final: return [stroke(-5, 1.2), stroke(0, 4)]
    case .repeatStart: return [stroke(0, 4), stroke(6, 1.2)] + dots(13)
    case .repeatEnd: return dots(-13) + [stroke(-6, 1.2), stroke(0, 4)]
    case .repeatBoth: return dots(-13) + [stroke(-6, 1.2), stroke(0, 4), stroke(6, 1.2)] + dots(13)
    }
  }

  private func tupletCommands(
    _ segments: [TupletSystemSegment],
    layout: HorizontalLayout,
    notationStart: Double,
    firstStaffTop: Double
  ) -> [AndroidRenderCommand] {
    let xs = Dictionary(uniqueKeysWithValues: layout.events.map { ($0.input.event.id, notationStart + $0.x) })
    return segments.flatMap { segment -> [AndroidRenderCommand] in
      let located = segment.eventIDs.compactMap { xs[$0] }
      guard let first = located.first, let last = located.last else { return [] }
      let y = firstStaffTop - 22
      var result = [text(role: "tupletNumber", value: String(segment.tuplet.actualCount), x: (first + last) / 2, y: y - 3, size: 12)]
      if segment.tuplet.bracket != .never {
        result += [
          line(role: "tupletBracket", x1: first - 5, y1: y, x2: (first + last) / 2 - 10, y2: y),
          line(role: "tupletBracket", x1: (first + last) / 2 + 10, y1: y, x2: last + 5, y2: y),
        ]
      }
      return result
    }
  }

  private func spannerCommands(
    _ segments: [SpannerSystemSegment],
    score: NotationScore,
    layout: HorizontalLayout,
    staves: [NotationStaff],
    staffTops: [String: Double],
    notationStart: Double,
    endX: Double,
    stemDirections: [String: Bool]
  ) -> [AndroidRenderCommand] {
    let positioned = Dictionary(uniqueKeysWithValues: layout.events.map { ($0.input.event.id, notationStart + $0.x) })
    let events = Dictionary(uniqueKeysWithValues: score.voices.flatMap(\.events).map { ($0.id, $0) })
    let voiceByEvent = Dictionary(uniqueKeysWithValues: score.voices.flatMap { voice in voice.events.map { ($0.id, voice.id) } })
    func below(_ spanner: NotationSpanner) -> Bool {
      if spanner.placement == .below { return true }
      if spanner.placement == .above { return false }
      if spanner.kind == .crescendo || spanner.kind == .diminuendo || spanner.kind == .pedal { return true }
      return voiceByEvent[spanner.startEventID].flatMap { stemDirections[$0] } ?? false
    }
    func point(_ endpoint: SpannerSystemEndpoint, _ spanner: NotationSpanner, start: Bool) -> AndroidRenderPoint? {
      let id: NotationEventID
      let x: Double
      switch endpoint {
      case .event(let value): id = value; guard let valueX = positioned[value] else { return nil }; x = valueX + (start ? 8 : -8)
      case .leadingSystemEdge: id = spanner.endEventID; x = notationStart - 10
      case .trailingSystemEdge: id = spanner.startEventID; x = endX - 6
      }
      guard let event = events[id], let top = staffTops[event.staffID] else { return nil }
      if spanner.kind == .crescendo || spanner.kind == .diminuendo { return .init(x: x, y: top + options.lineSpacing * 4 + 28) }
      if spanner.kind == .pedal { return .init(x: x, y: top + options.lineSpacing * 4 + 44) }
      guard case .notes(let pitches) = event.content, let pitch = pitches.first,
        let staff = staves.first(where: { $0.id == event.staffID })
      else { return nil }
      let y = top + options.lineSpacing * 4 - Double(staffPosition(for: pitch, clef: staff.clef)) * options.lineSpacing / 2
      return .init(x: x, y: y + (below(spanner) ? 10 : -10))
    }
    return segments.flatMap { segment -> [AndroidRenderCommand] in
      guard let start = point(segment.start, segment.spanner, start: true),
        let end = point(segment.end, segment.spanner, start: false), end.x > start.x
      else { return [] }
      if segment.spanner.kind == .crescendo || segment.spanner.kind == .diminuendo {
        let h = 6.0
        if segment.spanner.kind == .crescendo {
          return [line(role: "hairpin", x1: start.x, y1: start.y, x2: end.x, y2: end.y - h), line(role: "hairpin", x1: start.x, y1: start.y, x2: end.x, y2: end.y + h)]
        }
        return [line(role: "hairpin", x1: start.x, y1: start.y - h, x2: end.x, y2: end.y), line(role: "hairpin", x1: start.x, y1: start.y + h, x2: end.x, y2: end.y)]
      }
      if segment.spanner.kind == .pedal {
        return [
          text(role: "pedalLabel", value: "Ped.", x: start.x + 9, y: start.y - 1, size: 14),
          line(role: "pedalLine", x1: start.x + 24, y1: start.y, x2: end.x, y2: end.y),
          line(role: "pedalHook", x1: end.x, y1: end.y, x2: end.x, y2: end.y - 8),
        ]
      }
      let direction = below(segment.spanner) ? 1.0 : -1.0
      let controlY = (start.y + end.y) / 2 + direction * min(18, (end.x - start.x) * 0.12)
      return [AndroidRenderCommand(
        kind: .path,
        role: segment.spanner.kind.rawValue,
        lineWidth: segment.spanner.kind == .tie ? 1.8 : 1.2,
        path: [
          .init(verb: .move, points: [start]),
          .init(verb: .quadratic, points: [.init(x: (start.x + end.x) / 2, y: controlY), end]),
        ]
      )]
    }
  }

  private func voltaCommands(
    _ segments: [VoltaSystemSegment],
    layout: HorizontalLayout,
    notationStart: Double,
    endX: Double,
    top: Double
  ) -> [AndroidRenderCommand] {
    let y = top - 38
    return segments.flatMap { segment in
      let startX = segment.startsHere
        ? xForOnset(segment.volta.startOnset, layout: layout, notationStart: notationStart) : notationStart - 10
      let finishX = segment.endsHere
        ? xForOnset(segment.volta.endOnset, layout: layout, notationStart: notationStart) : endX
      var result = [line(role: "volta", x1: startX, y1: y, x2: finishX, y2: y)]
      if segment.startsHere {
        result.append(line(role: "voltaHook", x1: startX, y1: y, x2: startX, y2: y + 10))
        result.append(text(role: "voltaNumber", value: segment.volta.numbers.map(String.init).joined(separator: ",") + ".", x: startX + 12, y: y + 8, size: 12))
      }
      if segment.endsHere && segment.volta.hasEndHook {
        result.append(line(role: "voltaHook", x1: finishX, y1: y, x2: finishX, y2: y + 10))
      }
      return result
    }
  }

  private func xForOnset(_ onset: Rational, layout: HorizontalLayout, notationStart: Double) -> Double {
    if let exact = layout.contexts.first(where: { $0.onset == onset }) { return notationStart + exact.x }
    if let next = layout.contexts.first(where: { $0.onset > onset }) { return notationStart + next.x }
    return notationStart + layout.width
  }

  private func makeSystemVerticalGeometries(
    layouts: [HorizontalLayout],
    staves: [NotationStaff],
    stemDirections: [String: Bool],
    spannerSegments: [SpannerSystemSegment],
    tupletSegments: [TupletSystemSegment],
    voltaSegments: [VoltaSystemSegment]
  ) -> [SystemVerticalGeometry] {
    guard !layouts.isEmpty else { return [] }
    guard options.automaticSystemBreaks else {
      let height = options.height / Double(layouts.count)
      let staffStep = options.lineSpacing * 4 + options.interStaffGap
      let staffBlockHeight = Double(max(staves.count - 1, 0)) * staffStep
        + options.lineSpacing * 4
      return Array(
        repeating: SystemVerticalGeometry(
          height: height,
          firstStaffTopOffset: height / 2 - staffBlockHeight / 2
        ),
        count: layouts.count
      )
    }

    let staffStep = options.lineSpacing * 4 + options.interStaffGap
    let staffBlockHeight = Double(max(staves.count - 1, 0)) * staffStep
      + options.lineSpacing * 4
    let eventVoiceIDs = Dictionary(
      uniqueKeysWithValues: layouts.flatMap { layout in
        layout.events.map { ($0.input.event.id, $0.input.voiceID) }
      }
    )

    return layouts.enumerated().map { systemIndex, layout in
      var contentTop = 0.0
      var contentBottom = staffBlockHeight

      for positioned in layout.events {
        let event = positioned.input.event
        guard let staffIndex = staves.firstIndex(where: { $0.id == event.staffID }),
          case .notes(let pitches) = event.content,
          !pitches.isEmpty
        else { continue }
        let staffTop = Double(staffIndex) * staffStep
        let positions = pitches.map { staffPosition(for: $0, clef: staves[staffIndex].clef) }
        let noteYs = positions.map {
          staffTop + options.lineSpacing * 4 - Double($0) * options.lineSpacing / 2
        }
        guard let highestNote = noteYs.min(), let lowestNote = noteYs.max() else { continue }
        contentTop = min(contentTop, highestNote - 11)
        contentBottom = max(contentBottom, lowestNote + 11)

        if event.engravingDuration < .one {
          let averagePosition = Double(positions.reduce(0, +)) / Double(positions.count)
          let stemUp = stemDirections[eventVoiceIDs[event.id] ?? ""] ?? (averagePosition < 4)
          if stemUp {
            contentTop = min(contentTop, highestNote - options.lineSpacing * 3.8)
          } else {
            contentBottom = max(contentBottom, lowestNote + options.lineSpacing * 3.8)
          }
        }
        for attachment in event.attachments {
          if attachment.placement == .below {
            contentBottom = max(contentBottom, lowestNote + 48)
          } else {
            contentTop = min(contentTop, highestNote - 48)
          }
        }
      }

      for segment in spannerSegments where segment.systemIndex == systemIndex {
        let spanner = segment.spanner
        if spanner.kind == .pedal || spanner.kind == .crescendo
          || spanner.kind == .diminuendo || spanner.kind.rawValue == "hairpin.swell"
          || spanner.placement == .below
        {
          contentBottom = max(contentBottom, staffBlockHeight + 58)
        } else {
          contentTop = min(contentTop, -34)
        }
      }
      for segment in tupletSegments where segment.systemIndex == systemIndex {
        if segment.tuplet.placement == .below {
          contentBottom = max(contentBottom, staffBlockHeight + 38)
        } else {
          contentTop = min(contentTop, -38)
        }
      }
      if voltaSegments.contains(where: { $0.systemIndex == systemIndex }) {
        contentTop = min(contentTop, -52)
      }

      let outerPadding = 22.0
      let requiredHeight = contentBottom - contentTop + outerPadding * 2
      let height = max(options.minimumSystemHeight, requiredHeight)
      return SystemVerticalGeometry(
        height: height,
        firstStaffTopOffset: (height - requiredHeight) / 2 + outerPadding - contentTop
      )
    }
  }

  private func voiceStemDirections(_ voices: [NotationVoice]) -> [String: Bool] {
    let grouped = Dictionary(grouping: voices) { $0.events.first?.staffID ?? "" }
    var result: [String: Bool] = [:]
    for values in grouped.values where values.count > 1 {
      for (index, voice) in values.enumerated() { result[voice.id] = index == 0 }
    }
    return result
  }

  private func staffPosition(for pitch: NotatedPitch, clef: StaffClef) -> Int {
    let bottom = clef == .bass
      ? NotatedPitch(midi: MIDIPitch(rawValue: 43), step: .g, octave: 2).diatonicIndex
      : NotatedPitch(midi: MIDIPitch(rawValue: 64), step: .e, octave: 4).diatonicIndex
    return pitch.diatonicIndex - bottom
  }

  private func flagGlyph(_ duration: Rational, stemUp: Bool) -> AndroidSMuFLGlyph? {
    if duration == Rational(1, 8) { return stemUp ? .flag8thUp : .flag8thDown }
    if duration == Rational(1, 16) { return stemUp ? .flag16thUp : .flag16thDown }
    return nil
  }

  private func line(role: String, eventID: String? = nil, x1: Double, y1: Double, x2: Double, y2: Double, lineWidth: Double = 1.2, color: String = "#FF000000") -> AndroidRenderCommand {
    AndroidRenderCommand(kind: .line, role: role, eventID: eventID, color: color, lineWidth: lineWidth, points: [.init(x: x1, y: y1), .init(x: x2, y: y2)])
  }

  private func rectangle(role: String, eventID: String? = nil, x: Double, y: Double, width: Double, height: Double, color: String = "#FF000000", fill: Bool) -> AndroidRenderCommand {
    AndroidRenderCommand(kind: .rectangle, role: role, eventID: eventID, color: color, fill: fill, x: x, y: y, width: width, height: height)
  }

  private func ellipse(role: String, x: Double, y: Double, width: Double, height: Double) -> AndroidRenderCommand {
    AndroidRenderCommand(kind: .ellipse, role: role, fill: true, x: x, y: y, width: width, height: height)
  }

  private func glyph(role: String, eventID: String? = nil, value: AndroidSMuFLGlyph, x: Double, y: Double, size: Double) -> AndroidRenderCommand {
    AndroidRenderCommand(kind: .glyph, role: role, eventID: eventID, fill: true, x: x, y: y, text: value.character, fontSize: size)
  }

  private func text(role: String, eventID: String? = nil, value: String, x: Double, y: Double, size: Double) -> AndroidRenderCommand {
    AndroidRenderCommand(kind: .text, role: role, eventID: eventID, fill: true, x: x, y: y, text: value, fontSize: size)
  }

  private struct BeamStem {
    let isUp: Bool
    let endY: Double
  }

  private struct BeamNode {
    let id: NotationEventID
    let x: Double
    let topY: Double
    let bottomY: Double
    let averagePosition: Double
  }

  private struct BeamLayout {
    let stems: [NotationEventID: BeamStem]
    let commands: [AndroidRenderCommand]
  }

  private struct SystemVerticalGeometry {
    let height: Double
    let firstStaffTopOffset: Double
  }
}
