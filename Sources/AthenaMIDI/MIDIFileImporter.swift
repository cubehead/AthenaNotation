#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif
import Foundation

public struct MIDIDiagnostic: Hashable, Sendable {
  public let message: String

  public init(_ message: String) {
    self.message = message
  }
}

public struct MIDIImportResult: Sendable {
  public let score: NotationScore
  public let title: String?
  public let tempoBPM: Double
  public let diagnostics: [MIDIDiagnostic]

  public init(
    score: NotationScore,
    title: String?,
    tempoBPM: Double,
    diagnostics: [MIDIDiagnostic]
  ) {
    self.score = score
    self.title = title
    self.tempoBPM = tempoBPM
    self.diagnostics = diagnostics
  }
}

public enum MIDIImportError: Error, Equatable, LocalizedError {
  case truncatedFile
  case invalidHeader
  case unsupportedFormat(UInt16)
  case unsupportedSMPTETimeDivision
  case malformedTrack(Int)
  case missingNoteEvents

  public var errorDescription: String? {
    switch self {
    case .truncatedFile:
      "MIDI 文件不完整"
    case .invalidHeader:
      "不是有效的 Standard MIDI File"
    case .unsupportedFormat(let format):
      "暂不支持 MIDI Type \(format)；当前支持 Type 0 和 Type 1"
    case .unsupportedSMPTETimeDivision:
      "暂不支持使用 SMPTE 时间码的 MIDI 文件；当前需要 PPQN 时间格式"
    case .malformedTrack(let index):
      "MIDI 第 \(index + 1) 条轨道格式不正确"
    case .missingNoteEvents:
      "MIDI 文件中没有可用于钢琴谱的音符"
    }
  }
}

/// Native Standard MIDI File importer. It deliberately parses only the file
/// semantics Athena needs and has no dependency on a third-party MIDI runtime.
public struct MIDIFileImporter: Sendable {
  public init() {}

  public func parse(data: Data) throws -> MIDIImportResult {
    var reader = ByteReader(bytes: Array(data))
    guard try reader.readASCII(count: 4) == "MThd" else {
      throw MIDIImportError.invalidHeader
    }
    let headerLength = try reader.readUInt32()
    guard headerLength >= 6 else { throw MIDIImportError.invalidHeader }
    let format = try reader.readUInt16()
    guard format <= 1 else { throw MIDIImportError.unsupportedFormat(format) }
    let trackCount = Int(try reader.readUInt16())
    let division = try reader.readUInt16()
    guard division & 0x8000 == 0 else {
      throw MIDIImportError.unsupportedSMPTETimeDivision
    }
    let pulsesPerQuarter = Int(division)
    guard pulsesPerQuarter > 0 else { throw MIDIImportError.invalidHeader }
    if headerLength > 6 {
      try reader.skip(count: Int(headerLength - 6))
    }

    var notes: [RawNote] = []
    var tempos: [RawTempo] = []
    var timeSignatures: [RawTimeSignature] = []
    var keySignatures: [RawKeySignature] = []
    var trackNames: [Int: String] = [:]
    var diagnostics: [MIDIDiagnostic] = []

    for trackIndex in 0..<trackCount {
      guard try reader.readASCII(count: 4) == "MTrk" else {
        throw MIDIImportError.malformedTrack(trackIndex)
      }
      let length = Int(try reader.readUInt32())
      let bytes = try reader.readBytes(count: length)
      do {
        let result = try TrackParser(trackIndex: trackIndex, bytes: bytes).parse()
        notes.append(contentsOf: result.notes)
        tempos.append(contentsOf: result.tempos)
        timeSignatures.append(contentsOf: result.timeSignatures)
        keySignatures.append(contentsOf: result.keySignatures)
        if let name = result.name { trackNames[trackIndex] = name }
        diagnostics.append(contentsOf: result.diagnostics)
      } catch {
        throw MIDIImportError.malformedTrack(trackIndex)
      }
    }

    let pitchedNotes = notes.filter { $0.channel != 9 }
    guard !pitchedNotes.isEmpty else { throw MIDIImportError.missingNoteEvents }
    if pitchedNotes.count != notes.count {
      diagnostics.append(MIDIDiagnostic("已跳过 MIDI 鼓通道（Channel 10）"))
    }

    let gridTicks = max(1, pulsesPerQuarter / 8)
    var didQuantize = false
    let prepared = pitchedNotes.map { note -> PreparedNote in
      let start = Self.quantize(note.startTick, grid: gridTicks)
      var end = Self.quantize(note.endTick, grid: gridTicks)
      if end <= start { end = start + UInt64(gridTicks) }
      didQuantize = didQuantize || start != note.startTick || end != note.endTick
      return PreparedNote(
        trackIndex: note.trackIndex,
        channel: note.channel,
        midi: note.midi,
        velocity: note.velocity,
        startTick: start,
        endTick: end,
        hand: Self.inferredHand(
          midi: note.midi,
          trackName: trackNames[note.trackIndex]
        )
      )
    }
    if didQuantize {
      diagnostics.append(MIDIDiagnostic("演奏时值已量化到 1/32 音符网格，以生成可读谱面"))
    }

    let firstTimeSignature = timeSignatures.sorted { $0.tick < $1.tick }.first
    let timeSignature = TimeSignature(
      numerator: firstTimeSignature?.numerator ?? 4,
      denominator: firstTimeSignature?.denominator ?? 4
    )
    if Set(timeSignatures.map { ($0.numerator, $0.denominator) }.map(Pair.init)).count > 1 {
      diagnostics.append(MIDIDiagnostic("文件包含中途拍号变化；当前谱面暂按第一个拍号显示"))
    }

    let firstKeySignature = keySignatures.sorted { $0.tick < $1.tick }.first
    let fifths = firstKeySignature?.fifths ?? 0
    if Set(keySignatures.map(\.fifths)).count > 1 {
      diagnostics.append(MIDIDiagnostic("文件包含中途调号变化；当前谱面暂按第一个调号显示"))
    }
    if firstKeySignature?.isMinor == true {
      diagnostics.append(MIDIDiagnostic("已保留 MIDI 小调调号；当前模型暂不单独显示大小调名称"))
    }

    let staffIDs: [Hand: String] = [.right: "midi-treble", .left: "midi-bass"]
    let grouped = Dictionary(grouping: prepared) { TrackHand($0.trackIndex, $0.hand) }
    var voices: [NotationVoice] = []
    for key in grouped.keys.sorted() {
      let groups = Self.noteGroups(from: grouped[key, default: []])
      let lanes = Self.allocateLanes(groups)
      for (laneIndex, lane) in lanes.enumerated() {
        var cursor = Rational.zero
        var events: [NotationEvent] = []
        for (eventIndex, group) in lane.enumerated() {
          let onset = Self.scoreTime(ticks: group.startTick, ppqn: pulsesPerQuarter)
          let duration = Self.scoreTime(
            ticks: group.endTick - group.startTick,
            ppqn: pulsesPerQuarter
          )
          let staffID = staffIDs[key.hand]!
          if onset > cursor {
            events.append(
              NotationEvent(
                id: NotationEventID(
                  rawValue: "midi-t\(key.trackIndex)-\(key.hand)-v\(laneIndex)-gap\(eventIndex)"
                ),
                content: .rest,
                duration: onset - cursor,
                staffID: staffID,
                hand: key.hand
              )
            )
          }
          let notation = Self.notationValue(for: duration)
          events.append(
            NotationEvent(
              id: NotationEventID(
                rawValue: "midi-t\(key.trackIndex)-\(key.hand)-v\(laneIndex)-e\(eventIndex)"
              ),
              content: .notes(
                group.notes.sorted { $0.midi < $1.midi }.map {
                  Self.notatedPitch(midi: $0.midi, preferFlats: fifths < 0)
                }
              ),
              duration: duration,
              writtenDuration: notation?.base,
              dotCount: notation?.dots ?? 0,
              staffID: staffID,
              hand: key.hand,
              velocity: group.notes.map(\.velocity).max()
            )
          )
          cursor = onset + duration
        }
        voices.append(
          NotationVoice(
            id: "midi-track-\(key.trackIndex)-\(key.hand)-voice-\(laneIndex)",
            events: events
          )
        )
      }
    }

    let tempoByTick = Dictionary(tempos.map { ($0.tick, $0) }, uniquingKeysWith: { _, new in new })
    var tempoChanges = tempoByTick.values.sorted { $0.tick < $1.tick }.map {
      NotationTempoChange(
        onset: Self.scoreTime(ticks: $0.tick, ppqn: pulsesPerQuarter),
        beatsPerMinute: 60_000_000 / Double($0.microsecondsPerQuarter)
      )
    }
    if tempoChanges.first?.onset != .zero {
      tempoChanges.insert(NotationTempoChange(onset: .zero, beatsPerMinute: 120), at: 0)
    }

    let duration = prepared.map(\.endTick).max() ?? 0
    let barlines = Self.barlines(
      throughTick: duration,
      ppqn: pulsesPerQuarter,
      timeSignature: timeSignature
    )
    let title = trackNames[0] ?? trackNames.keys.sorted().compactMap { trackNames[$0] }.first
    return MIDIImportResult(
      score: NotationScore(
        staves: [
          NotationStaff(
            id: staffIDs[.right]!,
            clef: .treble,
            timeSignature: timeSignature,
            keySignature: KeySignature(fifths: fifths)
          ),
          NotationStaff(
            id: staffIDs[.left]!,
            clef: .bass,
            timeSignature: timeSignature,
            keySignature: KeySignature(fifths: fifths)
          ),
        ],
        voices: voices,
        barlines: barlines,
        tempoChanges: tempoChanges
      ),
      title: title,
      tempoBPM: tempoChanges.first?.beatsPerMinute ?? 120,
      diagnostics: diagnostics
    )
  }
}

private extension MIDIFileImporter {
  static func quantize(_ tick: UInt64, grid: Int) -> UInt64 {
    let value = UInt64(grid)
    return ((tick + value / 2) / value) * value
  }

  static func scoreTime(ticks: UInt64, ppqn: Int) -> Rational {
    Rational(Int64(ticks), Int64(ppqn * 4))
  }

  static func inferredHand(midi: UInt8, trackName: String?) -> Hand {
    let name = trackName?.lowercased() ?? ""
    if name.contains("left") || name.contains("左手") || name.contains("bass") || name == "lh" {
      return .left
    }
    if name.contains("right") || name.contains("右手") || name.contains("treble")
      || name.contains("melody") || name == "rh"
    {
      return .right
    }
    return midi < 60 ? .left : .right
  }

  static func noteGroups(from notes: [PreparedNote]) -> [NoteGroup] {
    let grouped = Dictionary(grouping: notes) { NoteInterval($0.startTick, $0.endTick) }
    return grouped.map { key, notes in
      NoteGroup(startTick: key.start, endTick: key.end, notes: notes)
    }.sorted {
      if $0.startTick != $1.startTick { return $0.startTick < $1.startTick }
      if $0.endTick != $1.endTick { return $0.endTick < $1.endTick }
      return ($0.notes.first?.midi ?? 0) < ($1.notes.first?.midi ?? 0)
    }
  }

  static func allocateLanes(_ groups: [NoteGroup]) -> [[NoteGroup]] {
    var lanes: [[NoteGroup]] = []
    var laneEnds: [UInt64] = []
    for group in groups {
      if let index = laneEnds.firstIndex(where: { $0 <= group.startTick }) {
        lanes[index].append(group)
        laneEnds[index] = group.endTick
      } else {
        lanes.append([group])
        laneEnds.append(group.endTick)
      }
    }
    return lanes
  }

  static func notationValue(for duration: Rational) -> (base: Rational, dots: UInt8)? {
    let bases = [
      Rational.one, Rational(1, 2), Rational(1, 4), Rational(1, 8), Rational(1, 16),
      Rational(1, 32), Rational(1, 64),
    ]
    for base in bases {
      var value = base
      var addition = base
      for dots: UInt8 in 0...3 {
        if value == duration { return (base, dots) }
        addition = addition / Rational(2)
        value = value + addition
      }
    }
    return nil
  }

  static func notatedPitch(midi: UInt8, preferFlats: Bool) -> NotatedPitch {
    let sharpSpellings: [(DiatonicStep, Int, AccidentalKind?)] = [
      (.c, 0, nil), (.c, 0, .sharp), (.d, 0, nil), (.d, 0, .sharp),
      (.e, 0, nil), (.f, 0, nil), (.f, 0, .sharp), (.g, 0, nil),
      (.g, 0, .sharp), (.a, 0, nil), (.a, 0, .sharp), (.b, 0, nil),
    ]
    let flatSpellings: [(DiatonicStep, Int, AccidentalKind?)] = [
      (.c, 0, nil), (.d, 0, .flat), (.d, 0, nil), (.e, 0, .flat),
      (.e, 0, nil), (.f, 0, nil), (.g, 0, .flat), (.g, 0, nil),
      (.a, 0, .flat), (.a, 0, nil), (.b, 0, .flat), (.b, 0, nil),
    ]
    let spelling = (preferFlats ? flatSpellings : sharpSpellings)[Int(midi) % 12]
    return NotatedPitch(
      midi: MIDIPitch(rawValue: midi),
      step: spelling.0,
      octave: Int(midi) / 12 - 1 + spelling.1,
      accidental: spelling.2
    )
  }

  static func barlines(
    throughTick endTick: UInt64,
    ppqn: Int,
    timeSignature: TimeSignature
  ) -> [NotationBarline] {
    let measureTicks = max(
      1,
      UInt64(ppqn) * 4 * UInt64(timeSignature.numerator) / UInt64(timeSignature.denominator)
    )
    var result: [NotationBarline] = []
    var tick = measureTicks
    while tick < endTick {
      result.append(
        NotationBarline(onset: scoreTime(ticks: tick, ppqn: ppqn), style: .regular)
      )
      tick += measureTicks
    }
    result.append(
      NotationBarline(onset: scoreTime(ticks: endTick, ppqn: ppqn), style: .final)
    )
    return result
  }
}

private struct Pair: Hashable {
  let first: UInt8
  let second: UInt8

  init(_ value: (UInt8, UInt8)) {
    first = value.0
    second = value.1
  }
}

private struct TrackHand: Hashable, Comparable {
  let trackIndex: Int
  let hand: Hand

  init(_ trackIndex: Int, _ hand: Hand) {
    self.trackIndex = trackIndex
    self.hand = hand
  }

  static func < (lhs: Self, rhs: Self) -> Bool {
    if lhs.hand != rhs.hand { return lhs.hand == .right }
    return lhs.trackIndex < rhs.trackIndex
  }
}

private struct NoteInterval: Hashable {
  let start: UInt64
  let end: UInt64

  init(_ start: UInt64, _ end: UInt64) {
    self.start = start
    self.end = end
  }
}

private struct PreparedNote {
  let trackIndex: Int
  let channel: UInt8
  let midi: UInt8
  let velocity: UInt8
  let startTick: UInt64
  let endTick: UInt64
  let hand: Hand
}

private struct NoteGroup {
  let startTick: UInt64
  let endTick: UInt64
  let notes: [PreparedNote]
}

private struct RawNote {
  let trackIndex: Int
  let channel: UInt8
  let midi: UInt8
  let velocity: UInt8
  let startTick: UInt64
  let endTick: UInt64
}

private struct RawTempo {
  let tick: UInt64
  let microsecondsPerQuarter: UInt32
}

private struct RawTimeSignature {
  let tick: UInt64
  let numerator: UInt8
  let denominator: UInt8
}

private struct RawKeySignature {
  let tick: UInt64
  let fifths: Int8
  let isMinor: Bool
}

private struct ActiveNote {
  let tick: UInt64
  let velocity: UInt8
}

private struct ActiveNoteKey: Hashable {
  let channel: UInt8
  let midi: UInt8
}

private struct TrackParseResult {
  var notes: [RawNote] = []
  var tempos: [RawTempo] = []
  var timeSignatures: [RawTimeSignature] = []
  var keySignatures: [RawKeySignature] = []
  var name: String?
  var diagnostics: [MIDIDiagnostic] = []
}

private struct TrackParser {
  let trackIndex: Int
  let bytes: [UInt8]

  func parse() throws -> TrackParseResult {
    var reader = ByteReader(bytes: bytes)
    var result = TrackParseResult()
    var tick: UInt64 = 0
    var runningStatus: UInt8?
    var active: [ActiveNoteKey: [ActiveNote]] = [:]

    while !reader.isAtEnd {
      tick += UInt64(try reader.readVariableLength())
      let first = try reader.readUInt8()
      let status: UInt8
      var firstData: UInt8?
      if first & 0x80 != 0 {
        status = first
        if status < 0xF0 { runningStatus = status }
      } else {
        guard let runningStatus else { throw MIDIImportError.malformedTrack(trackIndex) }
        status = runningStatus
        firstData = first
      }

      if status == 0xFF {
        let type = try reader.readUInt8()
        let length = Int(try reader.readVariableLength())
        let payload = try reader.readBytes(count: length)
        switch type {
        case 0x03:
          if result.name == nil {
            result.name = String(bytes: payload, encoding: .utf8)?.trimmingCharacters(
              in: .whitespacesAndNewlines
            )
          }
        case 0x51 where payload.count == 3:
          let microseconds = UInt32(payload[0]) << 16 | UInt32(payload[1]) << 8 | UInt32(payload[2])
          if microseconds > 0 {
            result.tempos.append(RawTempo(tick: tick, microsecondsPerQuarter: microseconds))
          }
        case 0x58 where payload.count >= 2:
          let exponent = min(payload[1], 7)
          result.timeSignatures.append(
            RawTimeSignature(
              tick: tick,
              numerator: max(1, payload[0]),
              denominator: UInt8(1 << exponent)
            )
          )
        case 0x59 where payload.count >= 2:
          let fifths = max(-7, min(7, Int(Int8(bitPattern: payload[0]))))
          result.keySignatures.append(
            RawKeySignature(tick: tick, fifths: Int8(fifths), isMinor: payload[1] == 1)
          )
        case 0x2F:
          reader.moveToEnd()
        default:
          break
        }
        continue
      }

      if status == 0xF0 || status == 0xF7 {
        let length = Int(try reader.readVariableLength())
        try reader.skip(count: length)
        runningStatus = nil
        continue
      }

      let kind = status & 0xF0
      let channel = status & 0x0F
      let dataCount = (kind == 0xC0 || kind == 0xD0) ? 1 : 2
      let data1 = try firstData ?? reader.readUInt8()
      let data2 = dataCount == 2 ? try reader.readUInt8() : 0
      guard data1 < 0x80 && data2 < 0x80 else {
        throw MIDIImportError.malformedTrack(trackIndex)
      }

      switch kind {
      case 0x90 where data2 > 0:
        active[ActiveNoteKey(channel: channel, midi: data1), default: []].append(
          ActiveNote(tick: tick, velocity: data2)
        )
      case 0x80, 0x90:
        let key = ActiveNoteKey(channel: channel, midi: data1)
        if var starts = active[key], !starts.isEmpty {
          let start = starts.removeFirst()
          active[key] = starts.isEmpty ? nil : starts
          if tick > start.tick {
            result.notes.append(
              RawNote(
                trackIndex: trackIndex,
                channel: channel,
                midi: data1,
                velocity: start.velocity,
                startTick: start.tick,
                endTick: tick
              )
            )
          }
        }
      default:
        break
      }
    }

    let danglingCount = active.values.reduce(0) { $0 + $1.count }
    if danglingCount > 0 {
      result.diagnostics.append(MIDIDiagnostic("第 \(trackIndex + 1) 轨有 \(danglingCount) 个未闭合音符，已跳过"))
    }
    return result
  }
}

private struct ByteReader {
  let bytes: [UInt8]
  private(set) var index = 0

  var isAtEnd: Bool { index >= bytes.count }

  mutating func readUInt8() throws -> UInt8 {
    guard index < bytes.count else { throw MIDIImportError.truncatedFile }
    defer { index += 1 }
    return bytes[index]
  }

  mutating func readUInt16() throws -> UInt16 {
    let high = UInt16(try readUInt8())
    let low = UInt16(try readUInt8())
    return high << 8 | low
  }

  mutating func readUInt32() throws -> UInt32 {
    var value: UInt32 = 0
    for _ in 0..<4 { value = value << 8 | UInt32(try readUInt8()) }
    return value
  }

  mutating func readVariableLength() throws -> UInt32 {
    var value: UInt32 = 0
    for _ in 0..<4 {
      let byte = try readUInt8()
      value = value << 7 | UInt32(byte & 0x7F)
      if byte & 0x80 == 0 { return value }
    }
    throw MIDIImportError.truncatedFile
  }

  mutating func readBytes(count: Int) throws -> [UInt8] {
    guard count >= 0, index + count <= bytes.count else { throw MIDIImportError.truncatedFile }
    defer { index += count }
    return Array(bytes[index..<(index + count)])
  }

  mutating func readASCII(count: Int) throws -> String {
    String(decoding: try readBytes(count: count), as: UTF8.self)
  }

  mutating func skip(count: Int) throws {
    _ = try readBytes(count: count)
  }

  mutating func moveToEnd() {
    index = bytes.count
  }
}
