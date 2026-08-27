#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif
import Foundation

#if canImport(FoundationXML)
  import FoundationXML
#endif

public enum MusicXMLDiagnosticSeverity: String, Hashable, Sendable, Codable {
  case information
  case warning
}

public struct MusicXMLDiagnostic: Hashable, Sendable, Codable {
  public let code: String
  public let severity: MusicXMLDiagnosticSeverity
  public let message: String
  public let measureNumber: String?

  public init(
    _ message: String,
    code: String = "musicxml.import",
    severity: MusicXMLDiagnosticSeverity = .warning,
    measureNumber: String? = nil
  ) {
    self.code = code
    self.severity = severity
    self.message = message
    self.measureNumber = measureNumber
  }
}

public struct MusicXMLImportResult: Sendable {
  public let score: NotationScore
  public let title: String?
  public let tempoBPM: Double?
  public let diagnostics: [MusicXMLDiagnostic]

  public init(
    score: NotationScore,
    title: String?,
    tempoBPM: Double? = nil,
    diagnostics: [MusicXMLDiagnostic]
  ) {
    self.score = score
    self.title = title
    self.tempoBPM = tempoBPM
    self.diagnostics = diagnostics
  }
}

public enum MusicXMLImportError: Error, Equatable, LocalizedError {
  case malformedXML(String)
  case unsupportedRoot(String)
  case missingPart

  public var errorDescription: String? {
    switch self {
    case .malformedXML(let detail):
      "MusicXML 文件格式不正确：\(detail)"
    case .unsupportedRoot(let root):
      "暂不支持 \(root)；当前需要 score-partwise MusicXML"
    case .missingPart:
      "MusicXML 中没有可导入的乐谱 part"
    }
  }
}

public struct MusicXMLImporter: Sendable {
  public init() {}

  public func parse(data: Data) throws -> MusicXMLImportResult {
    let parser = XMLParser(data: data)
    parser.shouldResolveExternalEntities = false
    let builder = XMLTreeBuilder()
    parser.delegate = builder
    guard parser.parse(), let root = builder.root else {
      throw MusicXMLImportError.malformedXML(
        builder.parserError?.localizedDescription ?? "Unknown XML parser error"
      )
    }
    guard root.name == "score-partwise" else {
      throw MusicXMLImportError.unsupportedRoot(root.name)
    }
    guard let part = root.child("part") else { throw MusicXMLImportError.missingPart }
    return ImportState(root: root, part: part).build()
  }
}

private struct VoiceKey: Hashable {
  let staff: Int
  let voice: String
}

private struct EventKey: Hashable {
  let voice: VoiceKey
  let onset: Rational
}

private struct ImportedEvent {
  var event: NotationEvent
  let onset: Rational
  var tieMarkers: [TieMarker] = []
  var slurMarkers: [RangeMarker] = []
  var tupletMarkers: [TupletMarker] = []
}

private struct PitchIdentity: Hashable {
  let midi: UInt8
  let diatonicIndex: Int
}

private struct TieMarker: Hashable {
  let pitch: PitchIdentity
  let type: String
}

private struct RangeMarker: Hashable {
  let number: String
  let type: String
  let kind: NotationSpannerKind
  let placement: AttachmentPlacement
}

private struct PendingAttachment {
  let onset: Rational
  let staff: Int?
  let attachment: NotationAttachment
}

private struct DirectionRangeMarker {
  let family: String
  let number: String
  let type: String
  let kind: NotationSpannerKind?
  let onset: Rational
  let staff: Int?
  let placement: AttachmentPlacement
}

private struct TupletMarker: Hashable {
  let number: String
  let type: String
  let actualCount: UInt8
  let normalCount: UInt8
}

private struct ActiveTuplet {
  let id: String
  let actualCount: UInt8
  let normalCount: UInt8
  var eventIDs: [NotationEventID]
}

private struct StaffConfiguration {
  var clef: StaffClef
  var keySignature: KeySignature
  var timeSignature: TimeSignature
}

private struct ImportState {
  let root: XMLTreeNode
  let part: XMLTreeNode

  func build() -> MusicXMLImportResult {
    var divisions = 1
    var staffCount = 1
    var timeSignature = TimeSignature.commonTime
    var keySignature = KeySignature.cMajor
    var staffConfigs: [Int: StaffConfiguration] = [:]
    var measureStart = Rational.zero
    var importedByKey: [EventKey: ImportedEvent] = [:]
    var lastChordOnset: [VoiceKey: Rational] = [:]
    var barlinesByOnset: [Rational: NotationBarline] = [:]
    var activeVoltas: [String: (onset: Rational, numbers: [UInt8])] = [:]
    var voltas: [NotationVolta] = []
    var tempoChangesByOnset: [Rational: NotationTempoChange] = [:]
    var pendingAttachments: [PendingAttachment] = []
    var directionRangeMarkers: [DirectionRangeMarker] = []
    var diagnostics: [MusicXMLDiagnostic] = []

    let partID = part.attributes["id"] ?? "P1"
    for (measureIndex, measure) in part.children(named: "measure").enumerated() {
      if let attributes = measure.child("attributes") {
        if let value = Int(attributes.child("divisions")?.trimmedText ?? ""), value > 0 {
          divisions = value
        }
        if let value = Int(attributes.child("staves")?.trimmedText ?? ""), value > 0 {
          staffCount = value
        }
        if let time = attributes.child("time"),
          let beats = UInt8(time.child("beats")?.trimmedText ?? ""),
          let beatType = UInt8(time.child("beat-type")?.trimmedText ?? ""),
          beats > 0, beatType > 0
        {
          timeSignature = TimeSignature(numerator: beats, denominator: beatType)
        }
        if let fifths = Int8(attributes.child("key")?.child("fifths")?.trimmedText ?? ""),
          (-7...7).contains(fifths)
        {
          keySignature = KeySignature(fifths: fifths)
        }
        for clef in attributes.children(named: "clef") {
          let staff = Int(clef.attributes["number"] ?? "1") ?? 1
          let sign = clef.child("sign")?.trimmedText.uppercased()
          staffConfigs[staff] = StaffConfiguration(
            clef: sign == "F" ? .bass : .treble,
            keySignature: keySignature,
            timeSignature: timeSignature
          )
        }
      }
      for staff in 1...staffCount where staffConfigs[staff] == nil {
        staffConfigs[staff] = StaffConfiguration(
          clef: staff == 2 ? .bass : .treble,
          keySignature: keySignature,
          timeSignature: timeSignature
        )
      }

      let measureDuration = Rational(
        Int64(timeSignature.numerator),
        Int64(timeSignature.denominator)
      )
      var cursorTicks = 0
      for child in measure.children {
        switch child.name {
        case "backup":
          cursorTicks -= Int(child.child("duration")?.trimmedText ?? "") ?? 0
          cursorTicks = max(0, cursorTicks)
        case "forward":
          cursorTicks += Int(child.child("duration")?.trimmedText ?? "") ?? 0
        case "direction":
          let offsetTicks = Int(child.child("offset")?.trimmedText ?? "0") ?? 0
          let localTicks = max(0, cursorTicks + offsetTicks)
          let onset = measureStart + Rational(Int64(localTicks), Int64(divisions * 4))
          if let bpm = Self.tempoBPM(from: child), bpm > 0 {
            tempoChangesByOnset[onset] = NotationTempoChange(
              onset: onset,
              beatsPerMinute: bpm
            )
          }
          let directionIndex = pendingAttachments.count + directionRangeMarkers.count
          pendingAttachments.append(
            contentsOf: Self.directionAttachments(
              from: child,
              onset: onset,
              partID: partID,
              measureIndex: measureIndex,
              directionIndex: directionIndex
            )
          )
          directionRangeMarkers.append(
            contentsOf: Self.directionRanges(from: child, onset: onset)
          )
        case "note":
          let durationTicks = Int(child.child("duration")?.trimmedText ?? "") ?? 0
          guard durationTicks > 0 else {
            diagnostics.append(
              MusicXMLDiagnostic(
                "Skipped grace or zero-duration note",
                code: "musicxml.note.grace-unsupported",
                measureNumber: measure.attributes["number"]
              )
            )
            continue
          }
          let staff = Int(child.child("staff")?.trimmedText ?? "1") ?? 1
          let voice = child.child("voice")?.trimmedText.nilIfEmpty ?? "1"
          let voiceKey = VoiceKey(staff: staff, voice: voice)
          let isChord = child.child("chord") != nil
          let localOnsetTicks =
            isChord
            ? (lastChordOnset[voiceKey]?.ticks(divisions: divisions) ?? cursorTicks) : cursorTicks
          let onset = measureStart + Rational(Int64(localOnsetTicks), Int64(divisions * 4))
          if !isChord {
            lastChordOnset[voiceKey] = Rational(Int64(localOnsetTicks), Int64(divisions * 4))
            cursorTicks += durationTicks
          }
          let duration = Rational(Int64(durationTicks), Int64(divisions * 4))
          let writtenDuration = Self.writtenDuration(for: child.child("type")?.trimmedText)
          let dotCount = UInt8(min(child.children(named: "dot").count, 3))
          let staffID = "\(partID)-staff-\(staff)"
          let eventID = NotationEventID(
            rawValue: "\(partID)-m\(measureIndex + 1)-s\(staff)-v\(voice)-t\(localOnsetTicks)"
          )
          let eventKey = EventKey(voice: voiceKey, onset: onset)

          if child.child("rest") != nil {
            importedByKey[eventKey] = ImportedEvent(
              event: NotationEvent(
                id: eventID,
                content: .rest,
                duration: duration,
                writtenDuration: writtenDuration,
                dotCount: dotCount,
                staffID: staffID,
                hand: Self.hand(forStaff: staff)
              ),
              onset: onset
            )
          } else if let pitch = Self.pitch(from: child) {
            let markers = Self.markers(from: child, pitch: pitch)
            if isChord, var existing = importedByKey[eventKey],
              case .notes(let pitches) = existing.event.content
            {
              let attachments =
                existing.event.attachments
                + Self.noteAttachments(
                  from: child,
                  eventID: existing.event.id,
                  noteheadIndex: pitches.count
                )
              existing.event = NotationEvent(
                id: existing.event.id,
                content: .notes(pitches + [pitch]),
                duration: existing.event.duration,
                writtenDuration: existing.event.writtenDuration,
                dotCount: existing.event.dotCount,
                staffID: existing.event.staffID,
                hand: existing.event.hand,
                attachments: attachments
              )
              existing.tieMarkers.append(contentsOf: markers.ties)
              existing.slurMarkers.append(contentsOf: markers.slurs)
              existing.tupletMarkers.append(contentsOf: markers.tuplets)
              importedByKey[eventKey] = existing
            } else {
              importedByKey[eventKey] = ImportedEvent(
                event: NotationEvent(
                  id: eventID,
                  content: .notes([pitch]),
                  duration: duration,
                  writtenDuration: writtenDuration,
                  dotCount: dotCount,
                  staffID: staffID,
                  hand: Self.hand(forStaff: staff),
                  attachments: Self.noteAttachments(
                    from: child,
                    eventID: eventID,
                    noteheadIndex: 0
                  )
                ),
                onset: onset,
                tieMarkers: markers.ties,
                slurMarkers: markers.slurs,
                tupletMarkers: markers.tuplets
              )
            }
          } else {
            diagnostics.append(
              MusicXMLDiagnostic(
                "Skipped note without pitch or rest",
                code: "musicxml.note.missing-content",
                measureNumber: measure.attributes["number"]
              )
            )
          }
        case "barline":
          let location = child.attributes["location"] ?? "right"
          let onset = location == "left" ? measureStart : measureStart + measureDuration
          if let ending = child.child("ending") {
            let numberText = ending.attributes["number"] ?? "1"
            let numbers = Self.endingNumbers(numberText)
            switch ending.attributes["type"] {
            case "start":
              activeVoltas[numberText] = (onset, numbers)
            case "stop", "discontinue":
              if let active = activeVoltas.removeValue(forKey: numberText), onset > active.onset {
                voltas.append(
                  NotationVolta(
                    id: "\(partID)-ending-\(numberText)-\(voltas.count)",
                    startOnset: active.onset,
                    endOnset: onset,
                    numbers: active.numbers,
                    hasEndHook: ending.attributes["type"] == "stop"
                  )
                )
              }
            default:
              break
            }
          }
          if child.child("repeat") != nil || child.child("bar-style") != nil {
            let style = Self.barlineStyle(from: child)
            let repeatCount = UInt8(child.child("repeat")?.attributes["times"] ?? "2") ?? 2
            let incoming = NotationBarline(
              onset: onset,
              style: style,
              repeatCount: max(2, repeatCount)
            )
            if let existing = barlinesByOnset[onset] {
              barlinesByOnset[onset] = Self.merged(existing, incoming)
            } else {
              barlinesByOnset[onset] = incoming
            }
          }
        default:
          break
        }
      }
      measureStart = measureStart + measureDuration
    }

    for pending in pendingAttachments {
      guard let key = Self.anchorKey(
        for: pending.onset,
        staff: pending.staff,
        preferFollowing: true,
        in: importedByKey
      ), var imported = importedByKey[key]
      else {
        diagnostics.append(
          MusicXMLDiagnostic(
            "Could not anchor direction attachment at \(pending.onset)",
            code: "musicxml.direction.unanchored"
          )
        )
        continue
      }
      imported.event = Self.appending(pending.attachment, to: imported.event)
      importedByKey[key] = imported
    }

    let grouped = Dictionary(grouping: importedByKey) { $0.key.voice }
    let sortedVoiceKeys = grouped.keys.sorted {
      $0.staff == $1.staff ? $0.voice < $1.voice : $0.staff < $1.staff
    }
    var spanners = Self.directionSpanners(
      markers: directionRangeMarkers,
      importedByKey: importedByKey,
      diagnostics: &diagnostics
    )
    var tuplets: [NotationTuplet] = []
    for key in sortedVoiceKeys {
      let imported = grouped[key, default: []].map(\.value).sorted { $0.onset < $1.onset }
      var activeTies: [PitchIdentity: NotationEventID] = [:]
      var activeRanges: [String: (eventID: NotationEventID, marker: RangeMarker)] = [:]
      var activeTuplets: [String: ActiveTuplet] = [:]
      for item in imported {
        for marker in Set(item.tieMarkers) where marker.type == "stop" {
          if let startID = activeTies.removeValue(forKey: marker.pitch) {
            spanners.append(
              NotationSpanner(
                id: "tie-\(startID.rawValue)-\(item.event.id.rawValue)",
                kind: .tie,
                startEventID: startID,
                endEventID: item.event.id
              )
            )
          }
        }
        for marker in Set(item.slurMarkers) where marker.type == "stop" {
          let rangeKey = "\(marker.kind.rawValue):\(marker.number)"
          if let active = activeRanges.removeValue(forKey: rangeKey) {
            spanners.append(
              NotationSpanner(
                id: "\(marker.kind.rawValue)-\(key.voice)-\(marker.number)-\(spanners.count)",
                kind: active.marker.kind,
                startEventID: active.eventID,
                endEventID: item.event.id,
                placement: active.marker.placement
              )
            )
          }
        }
        for marker in Set(item.tieMarkers) where marker.type == "start" {
          activeTies[marker.pitch] = item.event.id
        }
        for marker in Set(item.slurMarkers) where marker.type == "start" {
          activeRanges["\(marker.kind.rawValue):\(marker.number)"] = (item.event.id, marker)
        }
        for marker in Set(item.tupletMarkers) where marker.type == "start" {
          activeTuplets[marker.number] = ActiveTuplet(
            id: "tuplet-\(key.staff)-\(key.voice)-\(marker.number)-\(tuplets.count)",
            actualCount: marker.actualCount,
            normalCount: marker.normalCount,
            eventIDs: []
          )
        }
        for number in Array(activeTuplets.keys) {
          activeTuplets[number]?.eventIDs.append(item.event.id)
        }
        for marker in Set(item.tupletMarkers) where marker.type == "stop" {
          if let active = activeTuplets.removeValue(forKey: marker.number),
            active.eventIDs.count >= 2
          {
            tuplets.append(
              NotationTuplet(
                id: active.id,
                eventIDs: active.eventIDs,
                actualCount: active.actualCount,
                normalCount: active.normalCount
              )
            )
          }
        }
      }
      if !activeTies.isEmpty || !activeRanges.isEmpty || !activeTuplets.isEmpty {
        diagnostics.append(
          MusicXMLDiagnostic(
            "Unclosed notation range in voice \(key.voice)",
            code: "musicxml.notation.unclosed-range"
          )
        )
      }
    }

    let voices = sortedVoiceKeys.map { key in
      let imported = grouped[key, default: []].map(\.value).sorted { $0.onset < $1.onset }
      var cursor = Rational.zero
      var events: [NotationEvent] = []
      for item in imported {
        if item.onset > cursor {
          events.append(
            NotationEvent(
              id: NotationEventID(
                rawValue: "\(partID)-s\(key.staff)-v\(key.voice)-gap-\(events.count)"),
              content: .rest,
              duration: item.onset - cursor,
              staffID: "\(partID)-staff-\(key.staff)"
            )
          )
        } else if item.onset < cursor {
          diagnostics.append(MusicXMLDiagnostic("Overlapping events in voice \(key.voice)"))
        }
        events.append(item.event)
        cursor = max(cursor, item.onset + item.event.duration)
      }
      return NotationVoice(id: "\(partID)-staff-\(key.staff)-voice-\(key.voice)", events: events)
    }

    let staves = (1...staffCount).map { staff in
      let config =
        staffConfigs[staff]
        ?? StaffConfiguration(
          clef: staff == 2 ? .bass : .treble,
          keySignature: keySignature,
          timeSignature: timeSignature
        )
      return NotationStaff(
        id: "\(partID)-staff-\(staff)",
        clef: config.clef,
        timeSignature: config.timeSignature,
        keySignature: config.keySignature
      )
    }
    let title = root.child("work")?.child("work-title")?.trimmedText.nilIfEmpty
    let tempoChanges = tempoChangesByOnset.values.sorted { $0.onset < $1.onset }
    let tempoBPM = tempoChanges.first { $0.onset == .zero }?.beatsPerMinute
    return MusicXMLImportResult(
      score: NotationScore(
        staves: staves,
        voices: voices,
        spanners: spanners,
        tuplets: tuplets,
        barlines: barlinesByOnset.values.sorted { $0.onset < $1.onset },
        voltas: voltas.sorted { $0.startOnset < $1.startOnset },
        tempoChanges: tempoChanges
      ),
      title: title,
      tempoBPM: tempoBPM,
      diagnostics: diagnostics
    )
  }

  private static func writtenDuration(for type: String?) -> Rational? {
    switch type {
    case "whole": .one
    case "half": Rational(1, 2)
    case "quarter": Rational(1, 4)
    case "eighth": Rational(1, 8)
    case "16th": Rational(1, 16)
    case "32nd": Rational(1, 32)
    case "64th": Rational(1, 64)
    default: nil
    }
  }

  private static func tempoBPM(from direction: XMLTreeNode) -> Double? {
    if let value = direction.child("sound")?.attributes["tempo"].flatMap(Double.init), value > 0 {
      return value
    }
    guard let metronome = direction.child("direction-type")?.child("metronome"),
      let perMinute = Double(metronome.child("per-minute")?.trimmedText ?? ""),
      perMinute > 0
    else {
      return nil
    }

    let quarterUnits: Double
    switch metronome.child("beat-unit")?.trimmedText {
    case "whole": quarterUnits = 4
    case "half": quarterUnits = 2
    case "quarter": quarterUnits = 1
    case "eighth": quarterUnits = 0.5
    case "16th": quarterUnits = 0.25
    case "32nd": quarterUnits = 0.125
    default: quarterUnits = 1
    }
    let dots = metronome.children(named: "beat-unit-dot").count
    let dotMultiplier = (0..<dots).reduce(1.0) { result, index in
      result + 1 / pow(2, Double(index + 1))
    }
    return perMinute * quarterUnits * dotMultiplier
  }

  private static func markers(
    from note: XMLTreeNode,
    pitch: NotatedPitch
  ) -> (ties: [TieMarker], slurs: [RangeMarker], tuplets: [TupletMarker]) {
    let identity = PitchIdentity(
      midi: pitch.midi.rawValue,
      diatonicIndex: pitch.diatonicIndex
    )
    let ties = note.children(named: "tie").compactMap { node -> TieMarker? in
      guard let type = node.attributes["type"] else { return nil }
      return TieMarker(pitch: identity, type: type)
    }
    let notations = note.child("notations")
    let slurs =
      notations?.children(named: "slur").compactMap { node -> RangeMarker? in
        guard let type = node.attributes["type"] else { return nil }
        return RangeMarker(
          number: node.attributes["number"] ?? "1",
          type: type,
          kind: .slur,
          placement: placement(from: node)
        )
      } ?? []
    let glissandi = ["glissando", "slide"].flatMap { elementName in
      notations?.children(named: elementName).compactMap { node -> RangeMarker? in
        guard let type = node.attributes["type"] else { return nil }
        return RangeMarker(
          number: node.attributes["number"] ?? "1",
          type: type,
          kind: .glissando,
          placement: placement(from: node)
        )
      } ?? []
    }
    let modification = note.child("time-modification")
    let actualCount = UInt8(modification?.child("actual-notes")?.trimmedText ?? "") ?? 3
    let normalCount = UInt8(modification?.child("normal-notes")?.trimmedText ?? "") ?? 2
    let tuplets =
      notations?.children(named: "tuplet").compactMap { node -> TupletMarker? in
        guard let type = node.attributes["type"] else { return nil }
        return TupletMarker(
          number: node.attributes["number"] ?? "1",
          type: type,
          actualCount: actualCount,
          normalCount: normalCount
        )
      } ?? []
    return (ties, slurs + glissandi, tuplets)
  }

  private static func noteAttachments(
    from note: XMLTreeNode,
    eventID: NotationEventID,
    noteheadIndex: Int
  ) -> [NotationAttachment] {
    var result: [NotationAttachment] = []
    let notations = note.child("notations")
    let technical = notations?.child("technical")

    if let value = UInt8(technical?.child("fingering")?.trimmedText ?? ""),
      let finger = PianoFinger(rawValue: value)
    {
      result.append(
        NotationAttachment(
          id: "\(eventID.rawValue)-finger-\(noteheadIndex)",
          anchor: .notehead(index: noteheadIndex),
          placement: .automatic,
          content: .fingering(finger)
        )
      )
    }

    if let articulations = notations?.child("articulations") {
      for (index, articulation) in articulations.children.enumerated() {
        let placement = placement(from: articulation)
        let glyphName = articulationGlyphName(
          for: articulation.name,
          placement: placement
        )
        result.append(
          NotationAttachment(
            id: "\(eventID.rawValue)-articulation-\(index)",
            placement: placement,
            content: glyphName.map { .smuflGlyph(name: $0) }
              ?? .technique(name: articulation.name)
          )
        )
      }
    }

    if let ornaments = notations?.child("ornaments") {
      for (index, ornament) in ornaments.children.enumerated()
      where ornament.name != "wavy-line" {
        let glyphName = ornamentGlyphNames[ornament.name]
        result.append(
          NotationAttachment(
            id: "\(eventID.rawValue)-ornament-\(index)",
            placement: placement(from: ornament),
            content: glyphName.map { .smuflGlyph(name: $0) }
              ?? .technique(name: ornament.name)
          )
        )
      }
    }

    for (index, fermata) in (notations?.children(named: "fermata") ?? []).enumerated() {
      let placement: AttachmentPlacement =
        fermata.attributes["type"] == "inverted" ? .below : .above
      result.append(
        NotationAttachment(
          id: "\(eventID.rawValue)-fermata-\(index)",
          placement: placement,
          content: .smuflGlyph(
            name: placement == .below ? "fermataBelow" : "fermataAbove"
          )
        )
      )
    }

    if notations?.child("arpeggiate") != nil {
      result.append(
        NotationAttachment(
          id: "\(eventID.rawValue)-arpeggiate",
          placement: .left,
          content: .technique(name: "arpeggio")
        )
      )
    }

    let namedTechniques = [
      "up-bow", "down-bow", "harmonic", "open-string", "stopped",
      "snap-pizzicato", "heel", "toe", "pluck", "tap",
    ]
    for name in namedTechniques where technical?.child(name) != nil {
      result.append(
        NotationAttachment(
          id: "\(eventID.rawValue)-technical-\(name)",
          placement: placement(from: technical?.child(name)),
          content: .technique(name: name)
        )
      )
    }

    for (index, lyric) in note.children(named: "lyric").enumerated() {
      let syllabic = lyric.child("syllabic")?.trimmedText
      let text = lyric.children(named: "text").map(\.trimmedText).joined()
      guard !text.isEmpty else { continue }
      let renderedText = syllabic == "begin" || syllabic == "middle" ? text + "-" : text
      result.append(
        NotationAttachment(
          id: "\(eventID.rawValue)-lyric-\(index)",
          placement: .below,
          content: .text(renderedText)
        )
      )
    }

    return result
  }

  private static func directionAttachments(
    from direction: XMLTreeNode,
    onset: Rational,
    partID: String,
    measureIndex: Int,
    directionIndex: Int
  ) -> [PendingAttachment] {
    let staff = Int(direction.child("staff")?.trimmedText ?? "")
    let directionPlacement = placement(from: direction)
    let soundDynamics = direction.child("sound")?.attributes["dynamics"].flatMap(Double.init)
    let explicitVelocity = soundDynamics.map {
      UInt8(min(127, max(1, Int(($0 * 1.27).rounded()))))
    }
    var result: [PendingAttachment] = []

    func append(_ content: AttachmentContent, placement: AttachmentPlacement? = nil) {
      result.append(
        PendingAttachment(
          onset: onset,
          staff: staff,
          attachment: NotationAttachment(
            id: "\(partID)-m\(measureIndex + 1)-direction-\(directionIndex)-\(result.count)",
            placement: placement ?? directionPlacement,
            content: content
          )
        )
      )
    }

    for directionType in direction.children(named: "direction-type") {
      for dynamics in directionType.children(named: "dynamics") {
        for dynamic in dynamics.children {
          append(.dynamic(label: dynamic.name, velocity: explicitVelocity))
        }
      }
      for words in directionType.children(named: "words") {
        let value = words.trimmedText
        if !value.isEmpty { append(.text(value), placement: placement(from: words)) }
      }
      for rehearsal in directionType.children(named: "rehearsal") {
        let value = rehearsal.trimmedText
        if !value.isEmpty {
          append(.technique(name: value), placement: placement(from: rehearsal))
        }
      }
      if directionType.child("segno") != nil { append(.technique(name: "segno")) }
      if directionType.child("coda") != nil { append(.technique(name: "coda")) }
    }
    return result
  }

  private static func directionRanges(
    from direction: XMLTreeNode,
    onset: Rational
  ) -> [DirectionRangeMarker] {
    let staff = Int(direction.child("staff")?.trimmedText ?? "")
    let inheritedPlacement = placement(from: direction)
    var result: [DirectionRangeMarker] = []

    for directionType in direction.children(named: "direction-type") {
      for wedge in directionType.children(named: "wedge") {
        guard let type = wedge.attributes["type"] else { continue }
        let kind: NotationSpannerKind?
        switch type {
        case "crescendo": kind = .crescendo
        case "diminuendo": kind = .diminuendo
        default: kind = nil
        }
        result.append(
          DirectionRangeMarker(
            family: "wedge",
            number: wedge.attributes["number"] ?? "1",
            type: type,
            kind: kind,
            onset: onset,
            staff: staff,
            placement: placement(from: wedge, fallback: inheritedPlacement)
          )
        )
      }
      for pedal in directionType.children(named: "pedal") {
        guard let type = pedal.attributes["type"] else { continue }
        result.append(
          DirectionRangeMarker(
            family: "pedal",
            number: pedal.attributes["number"] ?? "1",
            type: type,
            kind: type == "stop" || type == "discontinue" ? nil : .pedal,
            onset: onset,
            staff: staff,
            placement: placement(from: pedal, fallback: .below)
          )
        )
      }
      for shift in directionType.children(named: "octave-shift") {
        guard let type = shift.attributes["type"] else { continue }
        result.append(
          DirectionRangeMarker(
            family: "octave-shift",
            number: shift.attributes["number"] ?? "1",
            type: type,
            kind: type == "stop" ? nil : .ottava,
            onset: onset,
            staff: staff,
            placement: placement(from: shift, fallback: .above)
          )
        )
      }
    }
    return result
  }

  private static func directionSpanners(
    markers: [DirectionRangeMarker],
    importedByKey: [EventKey: ImportedEvent],
    diagnostics: inout [MusicXMLDiagnostic]
  ) -> [NotationSpanner] {
    struct ActiveRange {
      let kind: NotationSpannerKind
      let startEventID: NotationEventID
      let placement: AttachmentPlacement
    }

    var active: [String: ActiveRange] = [:]
    var result: [NotationSpanner] = []
    for marker in markers {
      let key = "\(marker.family):\(marker.number)"
      let isStop = marker.type == "stop" || marker.type == "discontinue"
      let isChange = marker.type == "change"

      if isStop || isChange {
        guard let range = active.removeValue(forKey: key),
          let endKey = anchorKey(
            for: marker.onset,
            staff: marker.staff,
            preferFollowing: false,
            in: importedByKey
          ), let endEvent = importedByKey[endKey]?.event
        else {
          diagnostics.append(
            MusicXMLDiagnostic(
              "Could not close \(marker.family) range \(marker.number)",
              code: "musicxml.direction.unclosed-range"
            )
          )
          continue
        }
        if range.startEventID != endEvent.id {
          result.append(
            NotationSpanner(
              id: "\(marker.family)-\(marker.number)-\(result.count)",
              kind: range.kind,
              startEventID: range.startEventID,
              endEventID: endEvent.id,
              placement: range.placement
            )
          )
        }
        if !isChange { continue }
      }

      guard let kind = marker.kind,
        let startKey = anchorKey(
          for: marker.onset,
          staff: marker.staff,
          preferFollowing: true,
          in: importedByKey
        ), let startEvent = importedByKey[startKey]?.event
      else {
        diagnostics.append(
          MusicXMLDiagnostic(
            "Could not start \(marker.family) range \(marker.number)",
            code: "musicxml.direction.unanchored-range"
          )
        )
        continue
      }
      active[key] = ActiveRange(
        kind: kind,
        startEventID: startEvent.id,
        placement: marker.placement
      )
    }

    for (key, _) in active {
      diagnostics.append(
        MusicXMLDiagnostic(
          "Unclosed direction range \(key)",
          code: "musicxml.direction.unclosed-range"
        )
      )
    }
    return result
  }

  private static func anchorKey(
    for onset: Rational,
    staff: Int?,
    preferFollowing: Bool,
    in importedByKey: [EventKey: ImportedEvent]
  ) -> EventKey? {
    let candidates = importedByKey.keys.filter { staff == nil || $0.voice.staff == staff }
    let ordered = candidates.sorted {
      if $0.onset != $1.onset { return $0.onset < $1.onset }
      if $0.voice.staff != $1.voice.staff { return $0.voice.staff < $1.voice.staff }
      return $0.voice.voice < $1.voice.voice
    }
    if preferFollowing {
      return ordered.first { $0.onset >= onset } ?? ordered.last
    }
    return ordered.last { $0.onset <= onset } ?? ordered.first
  }

  private static func appending(
    _ attachment: NotationAttachment,
    to event: NotationEvent
  ) -> NotationEvent {
    NotationEvent(
      id: event.id,
      content: event.content,
      duration: event.duration,
      writtenDuration: event.writtenDuration,
      dotCount: event.dotCount,
      staffID: event.staffID,
      hand: event.hand,
      velocity: event.velocity,
      attachments: event.attachments + [attachment]
    )
  }

  private static func placement(
    from node: XMLTreeNode?,
    fallback: AttachmentPlacement = .automatic
  ) -> AttachmentPlacement {
    switch node?.attributes["placement"] ?? node?.attributes["type"] {
    case "above", "upright": .above
    case "below", "inverted": .below
    case "left": .left
    case "right": .right
    default: fallback
    }
  }

  private static func articulationGlyphName(
    for name: String,
    placement: AttachmentPlacement
  ) -> String? {
    let suffix = placement == .below ? "Below" : "Above"
    switch name {
    case "accent": return "articAccent\(suffix)"
    case "staccato": return "articStaccato\(suffix)"
    case "tenuto": return "articTenuto\(suffix)"
    case "staccatissimo": return "articStaccatissimo\(suffix)"
    case "strong-accent": return "articMarcato\(suffix)"
    case "breath-mark": return "breathMarkComma"
    case "caesura": return "caesura"
    default: return nil
    }
  }

  private static let ornamentGlyphNames: [String: String] = [
    "trill-mark": "ornamentTrill",
    "turn": "ornamentTurn",
    "inverted-turn": "ornamentTurnInverted",
    "mordent": "ornamentMordent",
    "inverted-mordent": "ornamentMordentInverted",
  ]

  private static func pitch(from note: XMLTreeNode) -> NotatedPitch? {
    guard let pitch = note.child("pitch"),
      let step = step(pitch.child("step")?.trimmedText),
      let octave = Int(pitch.child("octave")?.trimmedText ?? "")
    else { return nil }
    let alter = Int(pitch.child("alter")?.trimmedText ?? "0") ?? 0
    let base = [0, 2, 4, 5, 7, 9, 11][step.rawValue]
    let midiValue = min(127, max(0, (octave + 1) * 12 + base + alter))
    let accidentalText = note.child("accidental")?.trimmedText
    let accidental: AccidentalKind?
    switch accidentalText {
    case "flat-flat": accidental = .doubleFlat
    case "flat": accidental = .flat
    case "natural": accidental = .natural
    case "sharp": accidental = .sharp
    case "double-sharp": accidental = .doubleSharp
    default:
      accidental =
        [
          -2: AccidentalKind.doubleFlat,
          -1: .flat,
          1: .sharp,
          2: .doubleSharp,
        ][alter]
    }
    return NotatedPitch(
      midi: MIDIPitch(rawValue: UInt8(midiValue)),
      step: step,
      octave: octave,
      accidental: accidental
    )
  }

  private static func step(_ value: String?) -> DiatonicStep? {
    switch value?.uppercased() {
    case "C": .c
    case "D": .d
    case "E": .e
    case "F": .f
    case "G": .g
    case "A": .a
    case "B": .b
    default: nil
    }
  }

  private static func hand(forStaff staff: Int) -> Hand? {
    switch staff {
    case 1: .right
    case 2: .left
    default: nil
    }
  }

  private static func barlineStyle(from node: XMLTreeNode) -> NotationBarlineStyle {
    if let repeatNode = node.child("repeat") {
      return repeatNode.attributes["direction"] == "forward" ? .repeatStart : .repeatEnd
    }
    switch node.child("bar-style")?.trimmedText {
    case "light-light": return .double
    case "light-heavy": return .final
    default: return .regular
    }
  }

  private static func endingNumbers(_ text: String) -> [UInt8] {
    let values = text.split { !$0.isNumber }.compactMap { UInt8($0) }
    return values.isEmpty ? [1] : values
  }

  private static func merged(_ lhs: NotationBarline, _ rhs: NotationBarline) -> NotationBarline {
    let styles = Set([lhs.style, rhs.style])
    let style: NotationBarlineStyle
    if styles.contains(.repeatStart) && styles.contains(.repeatEnd) {
      style = .repeatBoth
    } else if rhs.style == .regular {
      style = lhs.style
    } else {
      style = rhs.style
    }
    return NotationBarline(
      onset: lhs.onset,
      style: style,
      repeatCount: max(lhs.repeatCount, rhs.repeatCount)
    )
  }
}

extension String {
  fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}

extension Rational {
  fileprivate func ticks(divisions: Int) -> Int {
    Int(numerator * Int64(divisions * 4) / denominator)
  }
}
