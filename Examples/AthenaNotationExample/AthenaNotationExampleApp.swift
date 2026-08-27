import AthenaMIDI
import AthenaMusicXML
import AthenaNotationCore
import AthenaNotationRenderApple
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

        ScrollableNativeScorePreview(
          score: score,
          preferredSystemCount: 2
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
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
