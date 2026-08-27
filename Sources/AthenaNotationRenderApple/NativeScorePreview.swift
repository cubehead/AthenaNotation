#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif
#if SWIFT_PACKAGE
  import AthenaNotationLayout
#endif
#if SWIFT_PACKAGE
  import AthenaScoreAnalysis
#endif
import SwiftUI

/// Native Apple renderer for the current VexFlow-to-Swift port subset.
@available(iOS 17.0, macOS 15.0, *)
public struct NativeScorePreview: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.locale) private var locale

  private let score: NotationScore
  private let playbackEventIDs: Set<NotationEventID>
  private let preferredSystemCount: Int
  private let theme: NativeScoreTheme?

  public init(
    score: NotationScore,
    playbackEventID: NotationEventID? = nil,
    preferredSystemCount: Int = 1,
    theme: NativeScoreTheme? = nil
  ) {
    precondition(preferredSystemCount > 0)
    self.score = score
    playbackEventIDs = playbackEventID.map { [$0] } ?? []
    self.preferredSystemCount = preferredSystemCount
    self.theme = theme
  }

  public init(
    score: NotationScore,
    playbackEventIDs: Set<NotationEventID>,
    preferredSystemCount: Int = 1,
    theme: NativeScoreTheme? = nil
  ) {
    precondition(preferredSystemCount > 0)
    self.score = score
    self.playbackEventIDs = playbackEventIDs
    self.preferredSystemCount = preferredSystemCount
    self.theme = theme
  }

  public init(
    voices: [NotationVoice],
    playbackEventID: NotationEventID? = nil,
    preferredSystemCount: Int = 1,
    theme: NativeScoreTheme? = nil
  ) {
    self.init(
      score: NotationScore(
        staves: [NotationStaff(id: "treble", clef: .treble)],
        voices: voices
      ),
      playbackEventID: playbackEventID,
      preferredSystemCount: preferredSystemCount,
      theme: theme
    )
  }

  public var body: some View {
    GeometryReader { proxy in
      let _ = BravuraFont.isRegistered
      let horizontalPadding = 36.0
      let staves =
        score.staves.isEmpty
        ? [NotationStaff(id: "treble", clef: .treble)] : score.staves
      let maximumKeyAccidentals = staves.map(\.keySignature.accidentalCount).max() ?? 0
      let notationStart = 150.0 + Double(maximumKeyAccidentals) * 9
      let availableWidth = max(proxy.size.width - notationStart - horizontalPadding, 1)
      let formatter = HorizontalFormatter()
      let timingInputs = formatter.makeInputs(voices: score.voices)
      let visibleAccidentals = AccidentalPlanner().visibleAccidentals(
        inputs: timingInputs,
        staves: staves
      )
      let metrics = layoutMetrics(for: score.voices, visibleAccidentals: visibleAccidentals)
      let inputs = formatter.makeInputs(voices: score.voices, metrics: metrics)
      let layouts = SystemFormatter(horizontalFormatter: formatter).format(
        inputs: inputs,
        systemCount: preferredSystemCount,
        justifyTo: availableWidth,
        measureDuration: measureDuration
      )
      let beamGroups = layouts.map { BeamPlanner().groups(inputs: $0.events.map(\.input)) }
      let spannerSegments = SpannerPlanner().segments(spanners: score.spanners, layouts: layouts)
      let tupletSegments = TupletPlanner().segments(tuplets: score.tuplets, layouts: layouts)
      let voltaSegments = VoltaPlanner().segments(
        voltas: score.voltas,
        layouts: layouts,
        scoreEnd: scoreDuration
      )
      let stemDirections = voiceStemDirections

      Canvas { context, size in
        let lineSpacing = 12.0
        let interStaffGap = 48.0
        let grandStaffHeight = lineSpacing * 8 + interStaffGap
        for (systemIndex, layout) in layouts.enumerated() {
          let centerY =
            size.height * (Double(systemIndex) + 0.5) / Double(max(layouts.count, 1))
          let firstStaffTop = centerY - grandStaffHeight / 2
          let staffTops = Dictionary(
            uniqueKeysWithValues: staves.enumerated().map { index, staff in
              (staff.id, firstStaffTop + Double(index) * (lineSpacing * 4 + interStaffGap))
            })
          let beamLayouts = staves.map { staff in
            makeBeamRenderLayout(
              groups: beamGroups[systemIndex].filter { $0.staffID == staff.id },
              layout: layout,
              staff: staff,
              notationStart: notationStart,
              staffTop: staffTops[staff.id] ?? firstStaffTop,
              lineSpacing: lineSpacing,
              stemDirections: stemDirections
            )
          }
          let stems = beamLayouts.reduce(into: [:]) { result, beamLayout in
            result.merge(beamLayout.stems) { _, new in new }
          }

          for staff in staves {
            let staffTop = staffTops[staff.id] ?? firstStaffTop
            drawStaff(
              in: &context,
              top: staffTop,
              spacing: lineSpacing,
              startX: horizontalPadding,
              endX: size.width - horizontalPadding
            )
            drawHeader(
              staff: staff,
              showTimeSignature: systemIndex == 0,
              in: &context,
              staffTop: staffTop,
              lineSpacing: lineSpacing,
              startX: horizontalPadding
            )
          }
          drawSystemBarlines(
            layout: layout,
            nextSystemOnset: layouts.indices.contains(systemIndex + 1)
              ? layouts[systemIndex + 1].contexts.first?.onset : nil,
            in: &context,
            staffTops: staves.compactMap { staffTops[$0.id] },
            lineSpacing: lineSpacing,
            startX: horizontalPadding,
            endX: size.width - horizontalPadding,
            notationStart: notationStart
          )

          for positioned in layout.events {
            let event = positioned.input.event
            guard let staff = staves.first(where: { $0.id == event.staffID }) else { continue }
            let staffTop = staffTops[staff.id] ?? firstStaffTop
            let x = notationStart + positioned.x

            if playbackEventIDs.contains(event.id) {
              let lastStaffTop = staffTops[staves.last?.id ?? ""] ?? staffTop
              let cursor = CGRect(
                x: x - 3,
                y: firstStaffTop - 22,
                width: 6,
                height: lastStaffTop + lineSpacing * 4 - firstStaffTop + 44
              )
              context.fill(Path(cursor), with: .color(resolvedTheme.playbackHighlight))
            }

            switch event.content {
            case .rest:
              drawRest(
                event,
                voiceStemUp: stemDirections[positioned.input.voiceID],
                atX: x,
                in: &context,
                staffTop: staffTop,
                lineSpacing: lineSpacing
              )
            case .notes(let pitches):
              drawNotes(
                pitches,
                event: event,
                staff: staff,
                atX: x,
                beamStem: stems[event.id],
                voiceStemUp: stemDirections[positioned.input.voiceID],
                visibleAccidentals: visibleAccidentals[event.id, default: []],
                in: &context,
                staffTop: staffTop,
                lineSpacing: lineSpacing
              )
            }
          }
          for beamLayout in beamLayouts {
            drawBeams(beamLayout.beams, in: &context)
          }
          drawTuplets(
            tupletSegments.filter { $0.systemIndex == systemIndex },
            layout: layout,
            beamGroups: beamGroups[systemIndex],
            beams: beamLayouts.flatMap(\.beams),
            staves: staves,
            staffTops: staffTops,
            notationStart: notationStart,
            lineSpacing: lineSpacing,
            in: &context
          )
          drawSpanners(
            spannerSegments.filter { $0.systemIndex == systemIndex },
            layout: layout,
            staves: staves,
            staffTops: staffTops,
            notationStart: notationStart,
            endX: size.width - horizontalPadding,
            lineSpacing: lineSpacing,
            beams: beamLayouts.flatMap(\.beams),
            in: &context
          )
          drawVoltas(
            voltaSegments.filter { $0.systemIndex == systemIndex },
            layout: layout,
            nextSystemOnset: layouts.indices.contains(systemIndex + 1)
              ? layouts[systemIndex + 1].contexts.first?.onset : nil,
            firstStaffTop: firstStaffTop,
            topStaff: staves[0],
            stemOverrides: stems,
            notationStart: notationStart,
            endX: size.width - horizontalPadding,
            lineSpacing: lineSpacing,
            in: &context
          )
        }
      }
      .background(resolvedTheme.background)
      .accessibilityElement(children: .contain)
      .accessibilityLabel(Text("Musical score"))
      .accessibilityChildren {
        let navigator = ScoreNavigator(score: score)
        let formatter = ScoreAccessibilityFormatter(localeIdentifier: locale.identifier)
        ForEach(navigator.entries) { entry in
          Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement()
            .accessibilityLabel(Text(formatter.label(for: entry)))
            .accessibilityIdentifier(entry.id.rawValue)
        }
      }
    }
  }

  private var resolvedTheme: NativeScoreTheme {
    theme ?? (colorScheme == .dark ? .dark : .light)
  }

  private var measureDuration: Rational {
    let signature = score.staves.first?.timeSignature ?? .commonTime
    return Rational(Int64(signature.numerator), Int64(signature.denominator))
  }

  private var scoreDuration: Rational {
    score.voices.map { voice in
      voice.events.reduce(.zero) { $0 + $1.duration }
    }.max() ?? .zero
  }

  /// Multiple voices on one staff use conventional opposing stem directions.
  /// A single voice keeps automatic pitch-based stems.
  private var voiceStemDirections: [String: Bool] {
    let voicesByStaff = Dictionary(grouping: score.voices) { voice in
      voice.events.first?.staffID ?? ""
    }
    var result: [String: Bool] = [:]
    for voices in voicesByStaff.values where voices.count > 1 {
      for (index, voice) in voices.enumerated() {
        result[voice.id] = index == 0
      }
    }
    return result
  }

  private func layoutMetrics(
    for voices: [NotationVoice],
    visibleAccidentals: [NotationEventID: [VisibleAccidental]]
  ) -> [NotationEventID: EventLayoutMetrics] {
    Dictionary(
      uniqueKeysWithValues: voices.flatMap { voice in
        voice.events.map { event in
          let hasAccidental = !(visibleAccidentals[event.id]?.isEmpty ?? true)
          return (
            event.id,
            EventLayoutMetrics(
              noteWidth: 16,
              leftExtent: hasAccidental ? 20 : 2,
              rightExtent: max(
                event.engravingDuration <= Rational(1, 8) ? 18 : 2,
                event.dotCount > 0 ? 12 + Double(event.dotCount) * 8 : 2
              )
            )
          )
        }
      })
  }

  private func drawStaff(
    in context: inout GraphicsContext,
    top: Double,
    spacing: Double,
    startX: Double,
    endX: Double
  ) {
    for line in 0..<5 {
      let y = top + Double(line) * spacing
      var path = Path()
      path.move(to: CGPoint(x: startX, y: y))
      path.addLine(to: CGPoint(x: endX, y: y))
      context.stroke(path, with: .color(resolvedTheme.foreground), lineWidth: 1)
    }
  }

  private func drawSystemBarlines(
    layout: HorizontalLayout,
    nextSystemOnset: Rational?,
    in context: inout GraphicsContext,
    staffTops: [Double],
    lineSpacing: Double,
    startX: Double,
    endX: Double,
    notationStart: Double
  ) {
    guard let firstStaffTop = staffTops.first, let lastStaffTop = staffTops.last else { return }
    let top = firstStaffTop
    let bottom = lastStaffTop + lineSpacing * 4

    func stroke(at x: Double, width: Double) {
      var line = Path()
      line.move(to: CGPoint(x: x, y: top))
      line.addLine(to: CGPoint(x: x, y: bottom))
      context.stroke(line, with: .color(resolvedTheme.foreground), lineWidth: width)
    }

    func dots(at x: Double) {
      for staffTop in staffTops {
        for offset in [1.5, 2.5] {
          let dot = CGRect(
            x: x - 2.25,
            y: staffTop + lineSpacing * offset - 2.25,
            width: 4.5,
            height: 4.5
          )
          context.fill(Path(ellipseIn: dot), with: .color(resolvedTheme.foreground))
        }
      }
    }

    func drawBarline(_ style: NotationBarlineStyle, at x: Double) {
      switch style {
      case .regular:
        stroke(at: x, width: 1.2)
      case .double:
        stroke(at: x - 3, width: 1.2)
        stroke(at: x + 3, width: 1.2)
      case .final:
        stroke(at: x - 5, width: 1.2)
        stroke(at: x, width: 4)
      case .repeatStart:
        stroke(at: x, width: 4)
        stroke(at: x + 6, width: 1.2)
        dots(at: x + 13)
      case .repeatEnd:
        dots(at: x - 13)
        stroke(at: x - 6, width: 1.2)
        stroke(at: x, width: 4)
      case .repeatBoth:
        dots(at: x - 13)
        stroke(at: x - 6, width: 1.2)
        stroke(at: x, width: 4)
        stroke(at: x + 6, width: 1.2)
        dots(at: x + 13)
      }
    }

    func style(at onset: Rational) -> NotationBarlineStyle? {
      score.barlines.first(where: { $0.onset == onset })?.style
    }

    stroke(at: startX, width: 1.6)
    if let firstOnset = layout.contexts.first?.onset {
      switch style(at: firstOnset) {
      case .repeatStart, .repeatBoth:
        drawBarline(.repeatStart, at: notationStart - 28)
      default:
        break
      }
    }

    let trailingStyle: NotationBarlineStyle
    if let nextSystemOnset {
      switch style(at: nextSystemOnset) {
      case .repeatEnd, .repeatBoth:
        trailingStyle = .repeatEnd
      default:
        trailingStyle = .regular
      }
    } else {
      let scoreEnd =
        score.voices.map { voice in
          voice.events.reduce(.zero) { $0 + $1.duration }
        }.max() ?? .zero
      trailingStyle = style(at: scoreEnd) ?? .regular
    }
    drawBarline(trailingStyle, at: endX)

    for (index, tickContext) in layout.contexts.enumerated() where index > 0 {
      let measure = tickContext.onset / measureDuration
      guard measure.denominator == 1 else { continue }
      let previousX = layout.contexts[index - 1].x
      let boundaryX = notationStart + (previousX + tickContext.x) / 2
      drawBarline(style(at: tickContext.onset) ?? .regular, at: boundaryX)
    }
  }

  private func drawHeader(
    staff: NotationStaff,
    showTimeSignature: Bool,
    in context: inout GraphicsContext,
    staffTop: Double,
    lineSpacing: Double,
    startX: Double
  ) {
    let clef: SMuFLGlyph = staff.clef == .bass ? .fClef : .gClef
    drawGlyph(
      clef,
      size: staff.clef == .bass ? 42 : 58,
      at: CGPoint(x: startX + 28, y: staffTop + lineSpacing * 2),
      in: &context
    )

    let keyCount = staff.keySignature.accidentalCount
    if keyCount > 0 {
      let glyph: SMuFLGlyph = staff.keySignature.fifths > 0 ? .accidentalSharp : .accidentalFlat
      let positions: [Int]
      if staff.keySignature.fifths > 0 {
        positions = staff.clef == .bass ? [6, 3, 7, 4, 1, 5, 2] : [8, 5, 9, 6, 3, 7, 4]
      } else {
        positions = staff.clef == .bass ? [2, 5, 1, 4, 0, 3, -1] : [4, 7, 3, 6, 2, 5, 1]
      }
      for index in 0..<keyCount {
        let y = staffTop + lineSpacing * 4 - Double(positions[index]) * lineSpacing / 2
        drawGlyph(
          glyph,
          size: 27,
          at: CGPoint(x: startX + 58 + Double(index) * 9, y: y),
          in: &context
        )
      }
    }

    if showTimeSignature,
      let numerator = SMuFLGlyph.timeSignatureDigit(staff.timeSignature.numerator),
      let denominator = SMuFLGlyph.timeSignatureDigit(staff.timeSignature.denominator)
    {
      let x = startX + 76 + Double(keyCount) * 9
      drawGlyph(
        numerator,
        size: 27,
        at: CGPoint(x: x, y: staffTop + lineSpacing),
        in: &context
      )
      drawGlyph(
        denominator,
        size: 27,
        at: CGPoint(x: x, y: staffTop + lineSpacing * 3),
        in: &context
      )
    }
  }

  private func drawNotes(
    _ pitches: [NotatedPitch],
    event: NotationEvent,
    staff: NotationStaff,
    atX x: Double,
    beamStem: BeamStemOverride?,
    voiceStemUp: Bool?,
    visibleAccidentals: [VisibleAccidental],
    in context: inout GraphicsContext,
    staffTop: Double,
    lineSpacing: Double
  ) {
    guard !pitches.isEmpty else { return }
    let notehead: SMuFLGlyph
    if event.engravingDuration >= .one {
      notehead = .noteheadWhole
    } else if event.engravingDuration >= Rational(1, 2) {
      notehead = .noteheadHalf
    } else {
      notehead = .noteheadBlack
    }
    let noteheadSize = 40.0
    let noteheadBounds =
      BravuraFont.metrics(for: notehead, size: noteheadSize)?.bounds
      ?? CGRect(x: 0, y: -5, width: 12, height: 10)
    let positions = pitches.map { staffPosition(for: $0, clef: staff.clef) }
    let ys = positions.map {
      staffTop + lineSpacing * 4 - Double($0) * lineSpacing / 2
    }
    let automaticStemUp = Double(positions.reduce(0, +)) / Double(positions.count) < 4
    let stemUp = beamStem?.isUp ?? voiceStemUp ?? automaticStemUp
    let accidentalIndices = Set(visibleAccidentals.map(\.pitchIndex))
    let placements = ChordPlanner().placements(
      staffPositions: positions,
      stemUp: stemUp,
      accidentalPitchIndices: accidentalIndices
    )
    let stemWidth = 1.4
    let noteheadAdvance = ChordPlanner().horizontalAdvance(
      noteheadWidth: noteheadBounds.width,
      stemWidth: stemWidth
    )
    let noteXs = placements.map { x + Double($0.noteheadColumn) * noteheadAdvance }

    let stem: StemGeometry?
    if event.engravingDuration < .one, let lowestY = ys.max(), let highestY = ys.min() {
      let stemX =
        x
        + (stemUp
          ? noteheadBounds.width / 2 - stemWidth / 2
          : -noteheadBounds.width / 2 + stemWidth / 2)
      let startY = stemUp ? lowestY : highestY
      let defaultEndY =
        (stemUp ? highestY : lowestY) + (stemUp ? -lineSpacing * 3.5 : lineSpacing * 3.5)
      stem = drawStemSegment(
        x: stemX,
        startY: startY,
        endY: beamStem?.endY ?? defaultEndY,
        isUp: stemUp,
        width: stemWidth,
        in: &context
      )
    } else {
      stem = nil
    }

    let leftmostHeadX = noteXs.min() ?? x
    for placement in placements {
      let index = placement.pitchIndex
      let noteX = noteXs[index]
      let y = ys[index]
      drawLedgerLines(
        for: placement.staffPosition,
        atX: noteX,
        in: &context,
        staffTop: staffTop,
        lineSpacing: lineSpacing
      )
      if let column = placement.accidentalColumn,
        let visible = visibleAccidentals.first(where: { $0.pitchIndex == index }),
        let accidental = SMuFLGlyph.accidental(visible.accidental)
      {
        drawGlyph(
          accidental,
          size: 28,
          at: CGPoint(
            x: leftmostHeadX - noteheadBounds.width / 2 - 8 - Double(column) * 11,
            y: y
          ),
          in: &context
        )
      }
      drawGlyph(notehead, size: noteheadSize, at: CGPoint(x: noteX, y: y), in: &context)
      drawDots(
        count: event.dotCount,
        atX: noteX,
        noteY: y,
        staffPosition: placement.staffPosition,
        notehead: notehead,
        noteheadSize: noteheadSize,
        lineSpacing: lineSpacing,
        in: &context
      )
      drawAttachments(
        event.attachments,
        noteheadIndex: index,
        noteX: noteX,
        noteY: y,
        stemEndY: stem?.endY,
        in: &context
      )
    }
    if beamStem == nil,
      let stem,
      let flag = flagGlyph(for: event.engravingDuration, stemUp: stem.isUp)
    {
      drawFlag(flag, stem: stem, in: &context)
    }
  }

  private func drawRest(
    _ event: NotationEvent,
    voiceStemUp: Bool?,
    atX x: Double,
    in context: inout GraphicsContext,
    staffTop: Double,
    lineSpacing: Double
  ) {
    let glyph: SMuFLGlyph
    if event.engravingDuration >= .one {
      glyph = .restWhole
    } else if event.engravingDuration >= Rational(1, 2) {
      glyph = .restHalf
    } else if event.engravingDuration >= Rational(1, 4) {
      glyph = .restQuarter
    } else {
      glyph = .restEighth
    }
    let restY =
      staffTop + lineSpacing * 2 + (voiceStemUp.map { $0 ? -lineSpacing : lineSpacing } ?? 0)
    drawGlyph(
      glyph,
      size: 32,
      at: CGPoint(x: x, y: restY),
      in: &context
    )
    for dotIndex in 0..<Int(event.dotCount) {
      drawGlyph(
        .augmentationDot,
        size: 40,
        at: CGPoint(x: x + 15 + Double(dotIndex) * 8, y: restY),
        in: &context
      )
    }
  }

  private func drawDots(
    count: UInt8,
    atX x: Double,
    noteY: Double,
    staffPosition: Int,
    notehead: SMuFLGlyph,
    noteheadSize: Double,
    lineSpacing: Double,
    in context: inout GraphicsContext
  ) {
    guard count > 0 else { return }
    let noteheadWidth = BravuraFont.metrics(for: notehead, size: noteheadSize)?.bounds.width ?? 12
    let dotY = staffPosition.isMultiple(of: 2) ? noteY - lineSpacing / 2 : noteY
    for dotIndex in 0..<Int(count) {
      drawGlyph(
        .augmentationDot,
        size: 40,
        at: CGPoint(
          x: x + noteheadWidth / 2 + 6 + Double(dotIndex) * 8,
          y: dotY
        ),
        in: &context
      )
    }
  }

  private func drawStemSegment(
    x: Double,
    startY: Double,
    endY: Double,
    isUp: Bool,
    width: Double,
    in context: inout GraphicsContext
  ) -> StemGeometry {
    var stem = Path()
    stem.move(to: CGPoint(x: x, y: startY))
    stem.addLine(to: CGPoint(x: x, y: endY))
    context.stroke(stem, with: .color(resolvedTheme.foreground), lineWidth: width)
    return StemGeometry(x: x, endY: endY, isUp: isUp, width: width)
  }

  private func flagGlyph(for duration: Rational, stemUp: Bool) -> SMuFLGlyph? {
    if duration == Rational(1, 8) {
      return stemUp ? .flag8thUp : .flag8thDown
    }
    if duration == Rational(1, 16) {
      return stemUp ? .flag16thUp : .flag16thDown
    }
    return nil
  }

  private func drawFlag(
    _ glyph: SMuFLGlyph,
    stem: StemGeometry,
    in context: inout GraphicsContext
  ) {
    let flagSize = 40.0
    guard let bounds = BravuraFont.metrics(for: glyph, size: flagSize)?.bounds else { return }

    // VexFlow aligns an up-flag's top and a down-flag's bottom with the stem
    // tip. Its x origin is shifted left by half the stem width.
    let left = stem.x - stem.width / 2
    let centerY = stem.isUp ? stem.endY + bounds.height / 2 : stem.endY - bounds.height / 2
    drawGlyph(
      glyph,
      size: flagSize,
      at: CGPoint(x: left + bounds.width / 2, y: centerY),
      in: &context
    )
  }

  private func makeBeamRenderLayout(
    groups: [BeamGroup],
    layout: HorizontalLayout,
    staff: NotationStaff,
    notationStart: Double,
    staffTop: Double,
    lineSpacing: Double,
    stemDirections: [String: Bool]
  ) -> BeamRenderLayout {
    let positioned = Dictionary(uniqueKeysWithValues: layout.events.map { ($0.input.event.id, $0) })
    let noteheadBounds =
      BravuraFont.metrics(for: .noteheadBlack, size: 40)?.bounds
      ?? CGRect(x: 0, y: -5, width: 12, height: 10)
    let stemWidth = 1.4
    let beamThickness = 5.0
    let beamGap = beamThickness * 0.5
    let minimumStemLength = lineSpacing * 3.5
    var stems: [NotationEventID: BeamStemOverride] = [:]
    var renderedGroups: [RenderedBeam] = []

    for group in groups {
      let nodes: [BeamNode] = group.eventIDs.compactMap { eventID in
        guard let positionedEvent = positioned[eventID],
          case .notes(let pitches) = positionedEvent.input.event.content,
          !pitches.isEmpty
        else { return nil }
        let staffPositions = pitches.map { staffPosition(for: $0, clef: staff.clef) }
        let noteYs = staffPositions.map {
          staffTop + lineSpacing * 4 - Double($0) * lineSpacing / 2
        }
        return BeamNode(
          eventID: eventID,
          noteX: notationStart + positionedEvent.x,
          topNoteY: noteYs.min() ?? staffTop,
          bottomNoteY: noteYs.max() ?? staffTop,
          averageStaffPosition: Double(staffPositions.reduce(0, +)) / Double(staffPositions.count)
        )
      }
      guard nodes.count == group.eventIDs.count else {
        continue
      }

      let isUp =
        stemDirections[group.voiceID]
        ?? (nodes.map(\.averageStaffPosition).reduce(0, +) / Double(nodes.count) < 4)
      let referenceYs = nodes.map { isUp ? $0.topNoteY : $0.bottomNoteY }
      let halfWidth = noteheadBounds.width / 2
      let stemXs = nodes.map {
        $0.noteX + (isUp ? halfWidth - stemWidth / 2 : -halfWidth + stemWidth / 2)
      }
      guard let firstStemX = stemXs.first, let lastStemX = stemXs.last else { continue }

      let totalX = max(lastStemX - firstStemX, 1)
      guard let firstReferenceY = referenceYs.first, let lastReferenceY = referenceYs.last else {
        continue
      }
      let desiredRise = min(
        max((lastReferenceY - firstReferenceY) * 0.25, -lineSpacing),
        lineSpacing
      )
      let slope = desiredRise / totalX
      let outerStartY: Double
      if isUp {
        outerStartY =
          zip(referenceYs, stemXs).map { noteY, stemX in
            noteY - minimumStemLength - slope * (stemX - firstStemX)
          }.min() ?? firstReferenceY - minimumStemLength
      } else {
        outerStartY =
          zip(referenceYs, stemXs).map { noteY, stemX in
            noteY + minimumStemLength - slope * (stemX - firstStemX)
          }.max() ?? firstReferenceY + minimumStemLength
      }
      let outerEndY = outerStartY + slope * (lastStemX - firstStemX)

      for (node, stemX) in zip(nodes, stemXs) {
        let outerY = outerStartY + slope * (stemX - firstStemX)
        stems[node.eventID] = BeamStemOverride(
          isUp: isUp,
          endY: outerY + (isUp ? stemWidth / 2 : -stemWidth / 2)
        )
      }
      let segments = makeBeamSegments(
        stemXs: stemXs,
        eventBeamCounts: group.eventBeamCounts,
        stemWidth: stemWidth
      )
      renderedGroups.append(
        RenderedBeam(
          startX: firstStemX,
          endX: lastStemX,
          startY: outerStartY,
          endY: outerEndY,
          isUp: isUp,
          segments: segments,
          thickness: beamThickness,
          gap: beamGap
        ))
    }

    return BeamRenderLayout(stems: stems, beams: renderedGroups)
  }

  private func drawBeams(_ beams: [RenderedBeam], in context: inout GraphicsContext) {
    for beam in beams {
      let totalX = max(beam.endX - beam.startX, 1)
      for segment in beam.segments {
        let distance = Double(segment.level) * (beam.thickness + beam.gap)
        let offset = beam.isUp ? distance : -distance
        let signedThickness = beam.isUp ? beam.thickness : -beam.thickness
        let startY =
          beam.startY
          + (segment.startX - beam.startX) / totalX * (beam.endY - beam.startY)
          + offset
        let endY =
          beam.startY
          + (segment.endX - beam.startX) / totalX * (beam.endY - beam.startY)
          + offset
        var path = Path()
        path.move(to: CGPoint(x: segment.startX, y: startY))
        path.addLine(to: CGPoint(x: segment.endX, y: endY))
        path.addLine(to: CGPoint(x: segment.endX, y: endY + signedThickness))
        path.addLine(to: CGPoint(x: segment.startX, y: startY + signedThickness))
        path.closeSubpath()
        context.fill(path, with: .color(resolvedTheme.foreground))
      }
    }
  }

  private func drawSpanners(
    _ segments: [SpannerSystemSegment],
    layout: HorizontalLayout,
    staves: [NotationStaff],
    staffTops: [String: Double],
    notationStart: Double,
    endX: Double,
    lineSpacing: Double,
    beams: [RenderedBeam],
    in context: inout GraphicsContext
  ) {
    let positioned = Dictionary(
      uniqueKeysWithValues: layout.events.map {
        ($0.input.event.id, notationStart + $0.x)
      })
    let events = Dictionary(
      uniqueKeysWithValues: score.voices.flatMap(\.events).map { ($0.id, $0) })
    let voiceByEvent = Dictionary(
      uniqueKeysWithValues: score.voices.flatMap { voice in
        voice.events.map { ($0.id, voice.id) }
      })

    func isBelow(_ spanner: NotationSpanner) -> Bool {
      if spanner.placement == .below { return true }
      if spanner.placement == .above { return false }
      if spanner.kind == .crescendo || spanner.kind == .diminuendo
        || spanner.kind == .pedal || spanner.kind.rawValue == "hairpin.swell"
      { return true }
      guard spanner.kind == .tie || spanner.kind == .slur,
        let voiceID = voiceByEvent[spanner.startEventID],
        let stemUp = voiceStemDirections[voiceID]
      else { return false }
      return stemUp
    }

    func noteY(for event: NotationEvent) -> Double? {
      guard let staff = staves.first(where: { $0.id == event.staffID }),
        let staffTop = staffTops[staff.id],
        case .notes(let pitches) = event.content,
        let pitch = pitches.first
      else { return nil }
      return staffTop + lineSpacing * 4
        - Double(staffPosition(for: pitch, clef: staff.clef)) * lineSpacing / 2
    }

    func point(
      for endpoint: SpannerSystemEndpoint,
      spanner: NotationSpanner,
      isStart: Bool
    ) -> CGPoint? {
      let eventID: NotationEventID
      let x: Double
      switch endpoint {
      case .event(let id):
        eventID = id
        guard let positionedX = positioned[id] else { return nil }
        x = positionedX + (isStart ? 8 : -8)
      case .leadingSystemEdge:
        eventID = spanner.endEventID
        x = notationStart - 10
      case .trailingSystemEdge:
        eventID = spanner.startEventID
        x = endX - 6
      }
      guard let event = events[eventID],
        let staffTop = staffTops[event.staffID]
      else { return nil }
      let below = isBelow(spanner)
      if spanner.kind == .crescendo || spanner.kind == .diminuendo
        || spanner.kind.rawValue == "hairpin.swell"
      {
        return CGPoint(x: x, y: staffTop + lineSpacing * 4 + 28)
      }
      if spanner.kind == .pedal {
        return CGPoint(x: x, y: staffTop + lineSpacing * 4 + 44)
      }
      guard let y = noteY(for: event) else { return nil }
      return CGPoint(x: x, y: y + (below ? 10 : -10))
    }

    for segment in segments {
      guard
        let start = point(for: segment.start, spanner: segment.spanner, isStart: true),
        let end = point(for: segment.end, spanner: segment.spanner, isStart: false),
        end.x > start.x
      else { continue }

      if segment.spanner.kind == .crescendo || segment.spanner.kind == .diminuendo
        || segment.spanner.kind.rawValue == "hairpin.swell"
      {
        let halfHeight = 6.0
        var hairpin = Path()
        if segment.spanner.kind == .crescendo {
          hairpin.move(to: start)
          hairpin.addLine(to: CGPoint(x: end.x, y: end.y - halfHeight))
          hairpin.move(to: start)
          hairpin.addLine(to: CGPoint(x: end.x, y: end.y + halfHeight))
        } else if segment.spanner.kind == .diminuendo {
          hairpin.move(to: CGPoint(x: start.x, y: start.y - halfHeight))
          hairpin.addLine(to: end)
          hairpin.move(to: CGPoint(x: start.x, y: start.y + halfHeight))
          hairpin.addLine(to: end)
        } else {
          let middleX = (start.x + end.x) / 2
          hairpin.move(to: start)
          hairpin.addLine(to: CGPoint(x: middleX, y: start.y - halfHeight))
          hairpin.addLine(to: end)
          hairpin.move(to: start)
          hairpin.addLine(to: CGPoint(x: middleX, y: start.y + halfHeight))
          hairpin.addLine(to: end)
        }
        context.stroke(hairpin, with: .color(resolvedTheme.foreground), lineWidth: 1.2)
        continue
      }

      if segment.spanner.kind == .pedal {
        var pedalLine = Path()
        let labelOffset = segment.start == .event(segment.spanner.startEventID) ? 24.0 : 0
        pedalLine.move(to: CGPoint(x: start.x + labelOffset, y: start.y))
        pedalLine.addLine(to: end)
        pedalLine.addLine(to: CGPoint(x: end.x, y: end.y - 8))
        context.stroke(pedalLine, with: .color(resolvedTheme.foreground), lineWidth: 1.1)
        if labelOffset > 0 {
          let label = Text("Ped.")
            .font(.system(size: 14, weight: .semibold, design: .serif))
            .italic()
            .foregroundColor(resolvedTheme.foreground)
          context.draw(label, at: CGPoint(x: start.x + 9, y: start.y - 1), anchor: .center)
        }
        continue
      }

      let below = isBelow(segment.spanner)
      let span = end.x - start.x
      let maximumArch = segment.spanner.kind == .tie ? 12.0 : 20.0
      let archHeight = min(maximumArch, max(5.0, span * 0.08))
      var controlY = below ? max(start.y, end.y) + archHeight : min(start.y, end.y) - archHeight
      if segment.spanner.kind == .slur,
        let voiceID = voiceByEvent[segment.spanner.startEventID]
      {
        let coveredNoteYs = layout.events.compactMap { positionedEvent -> Double? in
          guard positionedEvent.input.voiceID == voiceID else { return nil }
          let x = notationStart + positionedEvent.x
          guard start.x...end.x ~= x else { return nil }
          return noteY(for: positionedEvent.input.event)
        }
        if below, let lowest = coveredNoteYs.max() {
          controlY = max(controlY, lowest + 18)
        } else if let highest = coveredNoteYs.min() {
          controlY = min(controlY, highest - 18)
        }

        let overlappingBeams = beams.filter { beam in
          beam.endX >= start.x && beam.startX <= end.x
        }
        if below, let lowestBeam = overlappingBeams.map({ max($0.startY, $0.endY) }).max() {
          controlY = max(controlY, lowestBeam + 18)
        } else if let highestBeam = overlappingBeams.map({ min($0.startY, $0.endY) }).min() {
          controlY = min(controlY, highestBeam - 18)
        }
      }
      var curve = Path()
      curve.move(to: start)
      curve.addCurve(
        to: end,
        control1: CGPoint(x: start.x + span * 0.28, y: controlY),
        control2: CGPoint(x: end.x - span * 0.28, y: controlY)
      )
      context.stroke(
        curve,
        with: .color(resolvedTheme.foreground),
        lineWidth: segment.spanner.kind == .tie ? 1.5 : 1.3
      )
    }
  }

  private func drawVoltas(
    _ segments: [VoltaSystemSegment],
    layout: HorizontalLayout,
    nextSystemOnset: Rational?,
    firstStaffTop: Double,
    topStaff: NotationStaff,
    stemOverrides: [NotationEventID: BeamStemOverride],
    notationStart: Double,
    endX: Double,
    lineSpacing: Double,
    in context: inout GraphicsContext
  ) {
    guard let firstOnset = layout.contexts.first?.onset else { return }
    let systemEnd = nextSystemOnset ?? scoreDuration

    func boundaryX(for onset: Rational) -> Double {
      if onset <= firstOnset { return notationStart - 28 }
      if onset >= systemEnd { return endX }
      guard let index = layout.contexts.firstIndex(where: { $0.onset >= onset }) else {
        return endX
      }
      guard index > 0 else { return notationStart - 28 }
      return notationStart + (layout.contexts[index - 1].x + layout.contexts[index].x) / 2
    }

    var occupiedLevelEnds: [Double] = []
    for segment in segments {
      let startX =
        segment.startsHere ? boundaryX(for: segment.volta.startOnset) : notationStart - 28
      let finishX = segment.endsHere ? boundaryX(for: segment.volta.endOnset) : endX
      guard finishX > startX else { continue }

      let level: Int
      if let reusableLevel = occupiedLevelEnds.firstIndex(where: { $0 <= startX + 0.5 }) {
        level = reusableLevel
        occupiedLevelEnds[level] = finishX
      } else {
        level = occupiedLevelEnds.count
        occupiedLevelEnds.append(finishX)
      }

      let defaultY = firstStaffTop - lineSpacing * 2.5 - Double(level) * 24
      let contentTop = topContentY(
        in: layout,
        staff: topStaff,
        stemOverrides: stemOverrides,
        notationStart: notationStart,
        startX: startX,
        finishX: finishX,
        staffTop: firstStaffTop,
        lineSpacing: lineSpacing
      )
      let y = min(defaultY, (contentTop ?? defaultY) - lineSpacing * 1.25)
      var bracket = Path()
      bracket.move(to: CGPoint(x: startX, y: y + (segment.startsHere ? 14 : 0)))
      bracket.addLine(to: CGPoint(x: startX, y: y))
      bracket.addLine(to: CGPoint(x: finishX, y: y))
      if segment.endsHere, segment.volta.hasEndHook {
        bracket.addLine(to: CGPoint(x: finishX, y: y + 14))
      }
      context.stroke(bracket, with: .color(resolvedTheme.foreground), lineWidth: 1.5)

      if segment.startsHere {
        let label = segment.volta.numbers.map(String.init).joined(separator: ",") + "."
        let text = Text(label)
          .font(.system(size: 14, weight: .semibold, design: .serif))
          .foregroundColor(resolvedTheme.foreground)
        context.draw(text, at: CGPoint(x: startX + 10, y: y + 10), anchor: .leading)
      }
    }
  }

  private func topContentY(
    in layout: HorizontalLayout,
    staff: NotationStaff,
    stemOverrides: [NotationEventID: BeamStemOverride],
    notationStart: Double,
    startX: Double,
    finishX: Double,
    staffTop: Double,
    lineSpacing: Double
  ) -> Double? {
    layout.events.compactMap { positioned -> Double? in
      let event = positioned.input.event
      let x = notationStart + positioned.x
      guard event.staffID == staff.id, startX...finishX ~= x,
        case .notes(let pitches) = event.content, !pitches.isEmpty
      else { return nil }

      let positions = pitches.map { staffPosition(for: $0, clef: staff.clef) }
      let noteYs = positions.map {
        staffTop + lineSpacing * 4 - Double($0) * lineSpacing / 2
      }
      guard let highestNoteY = noteYs.min() else { return nil }

      var top = highestNoteY - lineSpacing * 0.55
      if event.engravingDuration < .one {
        let automaticStemUp =
          Double(positions.reduce(0, +)) / Double(positions.count) < 4
        let stemUp =
          stemOverrides[event.id]?.isUp
          ?? voiceStemDirections[positioned.input.voiceID]
          ?? automaticStemUp
        if stemUp {
          let stemEndY =
            stemOverrides[event.id]?.endY
            ?? highestNoteY - lineSpacing * 3.5
          top = min(top, stemEndY)
        }
      }
      return top
    }.min()
  }

  private func drawTuplets(
    _ segments: [TupletSystemSegment],
    layout: HorizontalLayout,
    beamGroups: [BeamGroup],
    beams: [RenderedBeam],
    staves: [NotationStaff],
    staffTops: [String: Double],
    notationStart: Double,
    lineSpacing: Double,
    in context: inout GraphicsContext
  ) {
    let positioned = Dictionary(
      uniqueKeysWithValues: layout.events.map {
        ($0.input.event.id, $0)
      })

    for segment in segments {
      guard let firstID = segment.eventIDs.first,
        let lastID = segment.eventIDs.last,
        let first = positioned[firstID],
        let last = positioned[lastID],
        let staff = staves.first(where: { $0.id == first.input.event.staffID }),
        let staffTop = staffTops[staff.id]
      else { continue }

      let x1 = notationStart + first.x - 9
      let x2 = notationStart + last.x + 9
      let stemUp = voiceStemDirections[first.input.voiceID]
      let below: Bool
      if segment.tuplet.placement == .below {
        below = true
      } else if segment.tuplet.placement == .above {
        below = false
      } else {
        below = !(stemUp ?? true)
      }

      let segmentIDs = Set(segment.eventIDs)
      let isBeamedTogether = beamGroups.contains { group in
        segmentIDs.isSubset(of: Set(group.eventIDs))
      }
      let showBracket: Bool
      switch segment.tuplet.bracket {
      case .always: showBracket = true
      case .never: showBracket = false
      case .automatic: showBracket = !isBeamedTogether
      }

      let overlappingBeams = beams.filter { $0.endX >= x1 && $0.startX <= x2 }
      let y: Double
      if below {
        let beamBottom = overlappingBeams.map { max($0.startY, $0.endY) + $0.thickness }.max()
        y = max(staffTop + lineSpacing * 5.5, (beamBottom ?? staffTop) + 14)
      } else {
        let beamTop = overlappingBeams.map { min($0.startY, $0.endY) }.min()
        y = min(staffTop - lineSpacing * 1.4, (beamTop ?? staffTop) - 14)
      }

      let centerX = (x1 + x2) / 2
      if showBracket {
        let gap = 20.0
        let hook = below ? -7.0 : 7.0
        var bracket = Path()
        bracket.move(to: CGPoint(x: x1, y: y + hook))
        bracket.addLine(to: CGPoint(x: x1, y: y))
        bracket.addLine(to: CGPoint(x: centerX - gap / 2, y: y))
        bracket.move(to: CGPoint(x: centerX + gap / 2, y: y))
        bracket.addLine(to: CGPoint(x: x2, y: y))
        bracket.addLine(to: CGPoint(x: x2, y: y + hook))
        context.stroke(bracket, with: .color(resolvedTheme.foreground), lineWidth: 1.2)
      }

      if let glyph = SMuFLGlyph.timeSignatureDigit(segment.tuplet.actualCount) {
        drawGlyph(glyph, size: 20, at: CGPoint(x: centerX, y: y), in: &context)
      } else {
        let text = Text(String(segment.tuplet.actualCount))
          .font(.system(size: 12, weight: .semibold, design: .serif))
          .foregroundColor(resolvedTheme.foreground)
        context.draw(text, at: CGPoint(x: centerX, y: y), anchor: .center)
      }
    }
  }

  private func makeBeamSegments(
    stemXs: [Double],
    eventBeamCounts: [Int],
    stemWidth: Double
  ) -> [BeamSegment] {
    guard let firstX = stemXs.first, let lastX = stemXs.last else { return [] }
    var segments = [
      BeamSegment(
        level: 0,
        startX: firstX - stemWidth / 2,
        endX: lastX + stemWidth / 2
      )
    ]
    let maximumLevel = eventBeamCounts.max() ?? 1
    guard maximumLevel > 1 else { return segments }

    for level in 1..<maximumLevel {
      var index = 0
      while index < eventBeamCounts.count {
        guard eventBeamCounts[index] > level else {
          index += 1
          continue
        }
        let runStart = index
        while index + 1 < eventBeamCounts.count, eventBeamCounts[index + 1] > level {
          index += 1
        }
        let runEnd = index
        if runStart != runEnd {
          segments.append(
            BeamSegment(
              level: level,
              startX: stemXs[runStart] - stemWidth / 2,
              endX: stemXs[runEnd] + stemWidth / 2
            ))
        } else {
          let hookLength = 10.0
          let pointsRight = runStart == 0
          segments.append(
            BeamSegment(
              level: level,
              startX: pointsRight
                ? stemXs[runStart] - stemWidth / 2 : stemXs[runStart] - hookLength,
              endX: pointsRight ? stemXs[runStart] + hookLength : stemXs[runStart] + stemWidth / 2
            ))
        }
        index += 1
      }
    }
    return segments
  }

  private func drawLedgerLines(
    for staffPosition: Int,
    atX x: Double,
    in context: inout GraphicsContext,
    staffTop: Double,
    lineSpacing: Double
  ) {
    let positions: [Int]
    if staffPosition < 0 {
      positions = Array(stride(from: -2, through: staffPosition, by: -2))
    } else if staffPosition > 8 {
      positions = Array(stride(from: 10, through: staffPosition, by: 2))
    } else {
      return
    }

    for position in positions {
      let y = staffTop + lineSpacing * 4 - Double(position) * lineSpacing / 2
      var ledger = Path()
      ledger.move(to: CGPoint(x: x - 10, y: y))
      ledger.addLine(to: CGPoint(x: x + 10, y: y))
      context.stroke(ledger, with: .color(resolvedTheme.foreground), lineWidth: 1)
    }
  }

  private func drawAttachments(
    _ attachments: [NotationAttachment],
    noteheadIndex: Int,
    noteX: Double,
    noteY: Double,
    stemEndY: Double?,
    in context: inout GraphicsContext
  ) {
    for attachment in attachments {
      if attachment.anchor == .event, noteheadIndex != 0 {
        continue
      }
      if case .notehead(let targetIndex) = attachment.anchor,
        targetIndex != noteheadIndex
      {
        continue
      }

      let y: Double
      if attachment.placement == .below {
        y = max(noteY + 27, (stemEndY ?? noteY) + 13)
      } else {
        y = min(noteY - 27, (stemEndY ?? noteY) - 13)
      }
      switch attachment.content {
      case .fingering(let finger):
        let text = Text(String(finger.rawValue))
          .font(.system(size: 13, weight: .semibold, design: .serif))
          .foregroundColor(resolvedTheme.foreground)
        context.draw(text, at: CGPoint(x: noteX, y: y), anchor: .center)
      case .smuflGlyph(let name):
        if let glyph = SMuFLGlyph.named(name) {
          drawGlyph(glyph, size: 24, at: CGPoint(x: noteX, y: y), in: &context)
        }
      case .text(let value), .technique(let value):
        let text = Text(value).font(.system(size: 12)).foregroundColor(resolvedTheme.foreground)
        context.draw(text, at: CGPoint(x: noteX, y: y), anchor: .center)
      case .dynamic(let label, _):
        let text = Text(label)
          .font(.system(size: 16, weight: .semibold, design: .serif))
          .italic()
          .foregroundColor(resolvedTheme.foreground)
        context.draw(text, at: CGPoint(x: noteX, y: y), anchor: .center)
      }
    }
  }

  private func drawGlyph(
    _ glyph: SMuFLGlyph,
    size: Double,
    at point: CGPoint,
    in context: inout GraphicsContext
  ) {
    guard
      let glyphPath = BravuraFont.path(for: glyph, size: size),
      let metrics = BravuraFont.metrics(for: glyph, size: size)
    else {
      let placeholder = Path(
        CGRect(x: point.x - size / 4, y: point.y - size / 4, width: size / 2, height: size / 2)
      )
      context.stroke(placeholder, with: .color(.red), lineWidth: 1)
      return
    }

    // CoreText paths are baseline-based and y-up. Center the measured outline
    // on the engraving point while flipping it into SwiftUI Canvas coordinates.
    let transform = CGAffineTransform(
      a: 1,
      b: 0,
      c: 0,
      d: -1,
      tx: point.x - metrics.bounds.midX,
      ty: point.y + metrics.bounds.midY
    )
    let path = Path(glyphPath).applying(transform)
    context.fill(path, with: .color(resolvedTheme.foreground))
  }

  private func staffPosition(for pitch: NotatedPitch, clef: StaffClef) -> Int {
    let bottomLineIndex =
      clef == .bass
      ? NotatedPitch(midi: MIDIPitch(rawValue: 43), step: .g, octave: 2).diatonicIndex
      : NotatedPitch(midi: MIDIPitch(rawValue: 64), step: .e, octave: 4).diatonicIndex
    return pitch.diatonicIndex - bottomLineIndex
  }

  private struct StemGeometry {
    let x: Double
    let endY: Double
    let isUp: Bool
    let width: Double
  }

  private struct BeamStemOverride {
    let isUp: Bool
    let endY: Double
  }

  private struct BeamNode {
    let eventID: NotationEventID
    let noteX: Double
    let topNoteY: Double
    let bottomNoteY: Double
    let averageStaffPosition: Double
  }

  private struct RenderedBeam {
    let startX: Double
    let endX: Double
    let startY: Double
    let endY: Double
    let isUp: Bool
    let segments: [BeamSegment]
    let thickness: Double
    let gap: Double
  }

  private struct BeamSegment {
    let level: Int
    let startX: Double
    let endX: Double
  }

  private struct BeamRenderLayout {
    let stems: [NotationEventID: BeamStemOverride]
    let beams: [RenderedBeam]
  }
}
