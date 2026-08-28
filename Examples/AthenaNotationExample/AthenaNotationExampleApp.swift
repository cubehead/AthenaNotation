import AthenaMIDI
import AthenaMusicXML
import AthenaNotationCore
import AthenaNotationRenderApple
import AthenaScoreAnalysis
import Combine
import SwiftUI
import UniformTypeIdentifiers

@main
struct AthenaNotationExampleApp: App {
  var body: some Scene {
    WindowGroup {
      ExampleScoreView()
    }
  }
}

private struct ExampleScoreView: View {
  @State private var score = NativeDemoScore.bundledResult?.score ?? NativeDemoScore.score
  @State private var title = NativeDemoScore.bundledResult?.title ?? "AthenaNotation Example"
  @State private var isImporting = false
  @State private var errorMessage: String?
  @State private var isScoreTouchEnabled = true
  @State private var selectedEventID: NotationEventID?
  @State private var selectedPosition: Rational?
  @State private var playbackEventDescription = "触摸音符可生成播放事件"
  @State private var playbackPosition = 0.0
  @State private var isPlaying = false
  @State private var loopStart: Double?
  @State private var loopEnd: Double?
  @State private var countInRemaining: Double?
  @State private var countInTarget = 0.0
  @State private var previousTick: Date?
  @State private var lastCountInBeat: Int?

  private static let playbackTimer = Timer.publish(
    every: 1.0 / 30.0,
    on: .main,
    in: .common
  ).autoconnect()

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        HStack {
          Label(title, systemImage: "music.note.list")
            .font(.headline)
          Spacer()
          Button("内置示例") {
            score = NativeDemoScore.bundledResult?.score ?? NativeDemoScore.score
            title = NativeDemoScore.bundledResult?.title ?? "AthenaNotation Example"
          }
          Button("导入 MusicXML / MIDI") {
            isImporting = true
          }
          .buttonStyle(.borderedProminent)
        }
        .padding()

        Divider()

        HStack(spacing: 12) {
          Toggle("允许触摸跳转", isOn: $isScoreTouchEnabled)
            .toggleStyle(.switch)
            .fixedSize()
          Text(playbackEventDescription)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)

        HStack(spacing: 10) {
          Button(countInRemaining != nil ? "取消预备" : (isPlaying ? "暂停" : "播放")) {
            togglePlayback()
          }
          .buttonStyle(.borderedProminent)

          Slider(
            value: Binding(
              get: { playbackPosition },
              set: { seek(to: $0) }
            ),
            in: 0...max(scoreDuration, 0.000_001)
          )

          Button(loopStart.map { "A \(positionLabel($0))" } ?? "设 A") {
            loopStart = playbackPosition
            if let loopEnd, loopEnd <= playbackPosition { self.loopEnd = nil }
          }
          Button(loopEnd.map { "B \(positionLabel($0))" } ?? "设 B") {
            guard let loopStart, playbackPosition > loopStart else { return }
            loopEnd = playbackPosition
          }
          .disabled(loopStart == nil || playbackPosition <= (loopStart ?? 0))

          if let beat = currentCountInBeat {
            Text("倒计时事件：\(beat)")
              .font(.caption.bold())
              .foregroundStyle(.orange)
          }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)

        ScrollableNativeScorePreview(
          score: score,
          playbackEventIDs: selectedEventID.map { [$0] } ?? [],
          preferredSystemCount: 2,
          interactionOptions: isScoreTouchEnabled ? .default : [],
          onInteraction: handleScoreInteraction
        )
        .padding(24)
        .background(Color.white)
      }
      .navigationTitle("AthenaNotation")
    }
    .fileImporter(
      isPresented: $isImporting,
      allowedContentTypes: Self.supportedTypes,
      allowsMultipleSelection: false,
      onCompletion: importScore
    )
    .alert(
      "无法导入乐谱",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      ),
      actions: {
        Button("好", role: .cancel) {}
      },
      message: {
        Text(errorMessage ?? "")
      }
    )
    .onReceive(Self.playbackTimer, perform: advancePlayback)
  }

  private static let supportedTypes: [UTType] = [
    UTType(filenameExtension: "musicxml"),
    UTType(filenameExtension: "xml"),
    UTType(filenameExtension: "mid"),
    UTType(filenameExtension: "midi"),
  ].compactMap { $0 }

  private func importScore(_ result: Result<[URL], Error>) {
    do {
      guard let url = try result.get().first else { return }
      let didAccess = url.startAccessingSecurityScopedResource()
      defer {
        if didAccess { url.stopAccessingSecurityScopedResource() }
      }
      let data = try Data(contentsOf: url)
      switch url.pathExtension.lowercased() {
      case "mid", "midi":
        let imported = try MIDIFileImporter().parse(data: data)
        score = imported.score
        title = imported.title ?? url.deletingPathExtension().lastPathComponent
      default:
        let imported = try MusicXMLImporter().parse(data: data)
        score = imported.score
        title = imported.title ?? url.deletingPathExtension().lastPathComponent
      }
      resetSelection()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func handleScoreInteraction(_ interaction: NativeScoreInteractionEvent) {
    guard let entry = ScoreNavigator(score: score).entry(id: interaction.eventID) else { return }
    seek(to: entry.onset.doubleValue)
  }

  private func resetSelection() {
    selectedEventID = nil
    selectedPosition = nil
    playbackEventDescription = "触摸音符可生成播放事件"
    playbackPosition = 0
    isPlaying = false
    loopStart = nil
    loopEnd = nil
    countInRemaining = nil
    previousTick = nil
    lastCountInBeat = nil
  }

  private var scoreDuration: Double { ScoreTimeline(score: score).duration.doubleValue }
  private var tempoMap: ScoreTempoMap { ScoreTempoMap(score: score) }
  private var eventPlanner: ScorePlaybackEventPlanner { ScorePlaybackEventPlanner(score: score) }
  private var timeSignature: TimeSignature { score.staves.first?.timeSignature ?? .commonTime }
  private var activeLoopRange: ScoreABLoopRange? {
    guard let loopStart, let loopEnd else { return nil }
    return ScoreABLoopRange(start: loopStart, end: loopEnd, scoreDuration: scoreDuration)
  }
  private var currentCountInBeat: Int? {
    guard let countInRemaining else { return nil }
    return ScoreCountInClock.displayedBeat(
      remainingSeconds: countInRemaining,
      timeSignature: timeSignature,
      beatsPerMinute: tempoMap.beatsPerMinute(at: countInTarget),
      rate: 1
    )
  }

  private func togglePlayback() {
    if countInRemaining != nil {
      countInRemaining = nil
      previousTick = nil
      lastCountInBeat = nil
      return
    }
    if isPlaying {
      isPlaying = false
      previousTick = nil
      emit(reason: .paused, from: playbackPosition)
      return
    }
    startCountIn(at: playbackPosition)
  }

  private func startCountIn(at position: Double) {
    isPlaying = false
    playbackPosition = min(max(0, position), scoreDuration)
    countInTarget = playbackPosition
    countInRemaining = ScoreCountInClock.durationSeconds(
      timeSignature: timeSignature,
      beatsPerMinute: tempoMap.beatsPerMinute(at: playbackPosition),
      rate: 1
    )
    previousTick = nil
    lastCountInBeat = nil
    emit(reason: .countInStarted, from: nil)
    publishCountInBeatIfNeeded()
  }

  private func seek(to position: Double) {
    let previous = playbackPosition
    playbackPosition = min(max(0, position), scoreDuration)
    countInRemaining = nil
    previousTick = nil
    lastCountInBeat = nil
    emit(reason: .seeked, from: previous)
  }

  private func advancePlayback(_ date: Date) {
    guard countInRemaining != nil || isPlaying else {
      previousTick = nil
      return
    }
    guard let previousTick else {
      self.previousTick = date
      return
    }
    let elapsed = max(0, date.timeIntervalSince(previousTick))
    self.previousTick = date

    if let countInRemaining {
      let result = ScoreCountInClock.advance(
        remainingSeconds: countInRemaining,
        elapsedSeconds: elapsed
      )
      self.countInRemaining = result.didFinish ? nil : result.remainingSeconds
      if result.didFinish {
        lastCountInBeat = nil
        isPlaying = true
        self.previousTick = nil
        emit(reason: .started, from: nil)
      } else {
        publishCountInBeatIfNeeded()
      }
      return
    }

    let previous = playbackPosition
    let advance = tempoMap.advance(
      position: playbackPosition,
      duration: scoreDuration,
      elapsedSeconds: elapsed,
      rate: 1,
      loops: activeLoopRange != nil,
      loopRange: activeLoopRange?.range
    )
    let step = ScorePlaybackStepPlanner.resolve(
      advance,
      loopRange: activeLoopRange,
      countInOnLoop: true
    )
    playbackPosition = step.position
    emit(reason: step.reason, from: previous)
    switch step.nextAction {
    case .continuePlayback:
      break
    case .beginCountIn(let position):
      startCountIn(at: position)
    case .finish:
      isPlaying = false
      self.previousTick = nil
    }
  }

  private func publishCountInBeatIfNeeded() {
    guard let beat = currentCountInBeat, beat != lastCountInBeat else { return }
    lastCountInBeat = beat
    emit(reason: .countInBeat(beat), from: nil)
  }

  private func emit(reason: ScorePlaybackEventReason, from previous: Double?) {
    let position = Rational(Int64((playbackPosition * 1_000_000).rounded()), 1_000_000)
    let previousPosition = previous.map {
      Rational(Int64(($0 * 1_000_000).rounded()), 1_000_000)
    }
    let event = eventPlanner.event(reason: reason, from: previousPosition, to: position)
    selectedEventID = event.snapshot.cursorEventIDs.sorted { $0.rawValue < $1.rawValue }.first
    selectedPosition = position
    playbackEventDescription =
      "\(reasonLabel(reason)) · on \(event.noteTransition.noteOns.count) · off \(event.noteTransition.noteOffs.count)"
  }

  private func reasonLabel(_ reason: ScorePlaybackEventReason) -> String {
    switch reason {
    case .started: "started"
    case .advanced: "advanced"
    case .seeked: "seeked"
    case .looped: "looped"
    case .countInStarted: "countInStarted"
    case .countInBeat(let beat): "countInBeat(\(beat))"
    case .paused: "paused"
    case .finished: "finished"
    }
  }

  private func positionLabel(_ position: Double) -> String {
    String(format: "%.2f", position)
  }
}
