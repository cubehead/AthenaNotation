#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif
import Foundation

/// One stable, semantically described stop in score-reading order.
public struct ScoreNavigationEntry: Identifiable, Hashable, Sendable, Codable {
  public var id: NotationEventID { event.id }
  public let voiceID: String
  public let event: NotationEvent
  public let onset: Rational
  public let end: Rational
  /// One-based measure number derived from the score's current time-signature model.
  public let measureNumber: Int
  /// One-based beat position. Fractional values preserve tuplets exactly.
  public let beat: Rational

  public init(
    voiceID: String,
    event: NotationEvent,
    onset: Rational,
    end: Rational,
    measureNumber: Int,
    beat: Rational
  ) {
    precondition(onset >= .zero && end > onset)
    precondition(measureNumber > 0 && beat >= .one)
    self.voiceID = voiceID
    self.event = event
    self.onset = onset
    self.end = end
    self.measureNumber = measureNumber
    self.beat = beat
  }
}

/// Deterministic event navigation shared by Apple accessibility, Android bridges,
/// keyboard commands, selection, and score-following clients.
public struct ScoreNavigator: Hashable, Sendable {
  public let entries: [ScoreNavigationEntry]
  public let measureDuration: Rational

  public init(score: NotationScore) {
    let signature = score.staves.first?.timeSignature ?? .commonTime
    let resolvedMeasureDuration = Rational(
      Int64(signature.numerator),
      Int64(signature.denominator)
    )
    measureDuration = resolvedMeasureDuration
    let beatDuration = Rational(1, Int64(signature.denominator))
    let staffOrder = Dictionary(
      uniqueKeysWithValues: score.staves.enumerated().map { ($0.element.id, $0.offset) }
    )
    let voiceOrder = Dictionary(
      uniqueKeysWithValues: score.voices.enumerated().map { ($0.element.id, $0.offset) }
    )

    entries = ScoreTimeline(score: score).events.map { timed in
      let measureOffset = timed.onset / resolvedMeasureDuration
      let measureIndex = Int(measureOffset.numerator / measureOffset.denominator)
      let offsetInMeasure =
        timed.onset - resolvedMeasureDuration * Rational(Int64(measureIndex))
      return ScoreNavigationEntry(
        voiceID: timed.voiceID,
        event: timed.event,
        onset: timed.onset,
        end: timed.end,
        measureNumber: measureIndex + 1,
        beat: offsetInMeasure / beatDuration + .one
      )
    }.sorted { lhs, rhs in
      if lhs.onset != rhs.onset { return lhs.onset < rhs.onset }
      let lhsStaff = staffOrder[lhs.event.staffID] ?? Int.max
      let rhsStaff = staffOrder[rhs.event.staffID] ?? Int.max
      if lhsStaff != rhsStaff { return lhsStaff < rhsStaff }
      let lhsVoice = voiceOrder[lhs.voiceID] ?? Int.max
      let rhsVoice = voiceOrder[rhs.voiceID] ?? Int.max
      if lhsVoice != rhsVoice { return lhsVoice < rhsVoice }
      return lhs.id.rawValue < rhs.id.rawValue
    }
  }

  public func entry(id: NotationEventID) -> ScoreNavigationEntry? {
    entries.first { $0.id == id }
  }

  public func next(after id: NotationEventID, wrapping: Bool = false) -> ScoreNavigationEntry? {
    guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
    if entries.indices.contains(index + 1) { return entries[index + 1] }
    return wrapping ? entries.first : nil
  }

  public func previous(
    before id: NotationEventID,
    wrapping: Bool = false
  ) -> ScoreNavigationEntry? {
    guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
    if index > entries.startIndex { return entries[index - 1] }
    return wrapping ? entries.last : nil
  }

  public func entries(at onset: Rational) -> [ScoreNavigationEntry] {
    entries.filter { $0.onset == onset }
  }

  public func entries(inMeasure measureNumber: Int) -> [ScoreNavigationEntry] {
    guard measureNumber > 0 else { return [] }
    return entries.filter { $0.measureNumber == measureNumber }
  }

  public func nearest(
    to onset: Rational,
    staffID: String? = nil
  ) -> ScoreNavigationEntry? {
    entries
      .filter { staffID == nil || $0.event.staffID == staffID }
      .min {
        let lhsDistance = abs(($0.onset - onset).doubleValue)
        let rhsDistance = abs(($1.onset - onset).doubleValue)
        if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
        return $0.onset < $1.onset
      }
  }
}

/// Produces localized VoiceOver/TalkBack labels without coupling score semantics
/// to SwiftUI, UIKit, AppKit, or Android APIs.
public struct ScoreAccessibilityFormatter: Hashable, Sendable {
  public let localeIdentifier: String

  public init(localeIdentifier: String = Locale.current.identifier) {
    self.localeIdentifier = localeIdentifier
  }

  public func label(for entry: ScoreNavigationEntry) -> String {
    let chinese = localeIdentifier.lowercased().hasPrefix("zh")
    let position = chinese
      ? "第\(entry.measureNumber)小节，第\(beatText(entry.beat))拍"
      : "Measure \(entry.measureNumber), beat \(beatText(entry.beat))"
    let content = contentLabel(for: entry.event, chinese: chinese)
    let duration = durationLabel(for: entry.event, chinese: chinese)
    let details = attachmentLabels(for: entry.event, chinese: chinese)
    return ([position, content, duration] + details).joined(separator: chinese ? "，" : ", ")
  }

  private func contentLabel(for event: NotationEvent, chinese: Bool) -> String {
    switch event.content {
    case .rest:
      return chinese ? "休止符" : "rest"
    case .notes(let pitches):
      let names = pitches.map { pitchLabel($0, chinese: chinese) }.joined(separator: " ")
      if pitches.count == 1 { return chinese ? "音符 \(names)" : "note \(names)" }
      return chinese ? "和弦 \(names)" : "chord \(names)"
    }
  }

  private func pitchLabel(_ pitch: NotatedPitch, chinese: Bool) -> String {
    let step = ["C", "D", "E", "F", "G", "A", "B"][pitch.step.rawValue]
    let accidental: String
    switch pitch.accidental {
    case .sharp: accidental = chinese ? "升" : " sharp"
    case .flat: accidental = chinese ? "降" : " flat"
    case .natural: accidental = chinese ? "还原" : " natural"
    case .doubleSharp: accidental = chinese ? "重升" : " double sharp"
    case .doubleFlat: accidental = chinese ? "重降" : " double flat"
    case .some(let value): accidental = " \(value.rawValue)"
    case nil: accidental = ""
    }
    return chinese
      ? "\(accidental)\(step)\(pitch.octave)"
      : "\(step)\(pitch.octave)\(accidental)"
  }

  private func durationLabel(for event: NotationEvent, chinese: Bool) -> String {
    let value: String
    switch event.engravingDuration {
    case .one: value = chinese ? "全音符" : "whole note"
    case Rational(1, 2): value = chinese ? "二分音符" : "half note"
    case Rational(1, 4): value = chinese ? "四分音符" : "quarter note"
    case Rational(1, 8): value = chinese ? "八分音符" : "eighth note"
    case Rational(1, 16): value = chinese ? "十六分音符" : "sixteenth note"
    case Rational(1, 32): value = chinese ? "三十二分音符" : "thirty-second note"
    case Rational(1, 64): value = chinese ? "六十四分音符" : "sixty-fourth note"
    default: value = chinese ? "时值 \(event.engravingDuration)" : "duration \(event.engravingDuration)"
    }
    guard event.dotCount > 0 else { return value }
    return chinese ? "\(event.dotCount)个附点\(value)" : "\(event.dotCount)-dot \(value)"
  }

  private func attachmentLabels(for event: NotationEvent, chinese: Bool) -> [String] {
    event.attachments.compactMap { attachment in
      switch attachment.content {
      case .fingering(let finger):
        return chinese ? "指法 \(finger.rawValue)" : "finger \(finger.rawValue)"
      case .dynamic(let label, _):
        return chinese ? "力度 \(label)" : "dynamic \(label)"
      case .text(let value):
        return value
      case .technique(let name):
        return chinese ? "奏法 \(name)" : "technique \(name)"
      case .smuflGlyph(let name):
        return chinese ? "记号 \(name)" : "symbol \(name)"
      }
    }
  }

  private func beatText(_ beat: Rational) -> String {
    beat.denominator == 1 ? String(beat.numerator) : beat.description
  }
}
