# Windows support plan

Windows support is being delivered as a portability track rather than as a
port of the Apple SwiftUI view. Swift owns score semantics, import, layout,
analysis and a deterministic display list. A Windows-native adapter will own
the canvas, scrolling, input and accessibility integration.

## Delivery strategy

- Keep one engraving implementation across Apple, Android and Windows.
- Make the portable Swift package build independently of Apple frameworks.
- Use a Windows-named render facade now, backed by the established Codable
  display-list schema.
- Add WinUI 3 or Direct2D only after the Swift package passes on a Windows host.
- Treat Windows UI packaging and installer work as a later milestone.

## Milestones

| Milestone | Goal | Deliverables | Exit criteria | Status |
| --- | --- | --- | --- | --- |
| W0 | Establish the package boundary | Conditional SwiftPM manifest, `AthenaNotationRenderWindows`, CLI example, portable tests | Manifest and all existing tests pass on macOS; Windows CI is configured | Complete |
| W1 | Prove native Windows compilation | Build core, layout, importers, analysis, renderer and example on Windows 10/11 x64 | `swift build` and `swift test` pass on a clean Windows host | Pending Windows validation |
| W2 | Render a score in a native window | WinUI 3/Direct2D command executor, Bravura font loading, scroll viewport | MusicXML demo renders with correct sizing, dark mode and playback highlight | Planned |
| W3 | Add interaction and accessibility | Hit testing, touch/mouse callbacks, auto-follow and UI Automation nodes | Example supports seek-by-click and screen-reader navigation | Planned |
| W4 | Package and harden | DLL/C ABI decision, sample app packaging, Windows CI matrix | Reproducible x64 release artifact and documented integration | Planned |

## W1 validation checklist

- Install the current stable Swift toolchain and Visual Studio 2022 C++ build
  tools with a Windows 10/11 SDK.
- Run `swift --version` and record the exact toolchain.
- Run `swift build --target AthenaNotationCore`.
- Run `swift build --target AthenaNotationRenderWindows`.
- Run `swift run AthenaNotationWindowsExample` and validate its JSON output.
- Run `swift test` and attach the result to the first Windows-support issue.
- Repeat on x64 first; add ARM64 only after x64 is green.

## Risks and decisions

| Risk or decision | Current handling |
| --- | --- |
| Foundation behavior differs on Windows | Portable importer and analysis tests run in Windows CI |
| Bravura resource lookup differs from bundle behavior | W2 validates explicit font discovery before UI work expands |
| Display-list names originated in the Android integration | Windows aliases provide a stable entry point; a neutral scene module can be introduced in a later API cycle |
| Windows UI technology | Prefer WinUI 3 with Direct2D; confirm after the native compilation proof |
| Binary integration shape | Defer DLL/C ABI versus direct SwiftPM consumption until W1 measurements are available |

## Not in W0

- A Windows graphical application
- WinUI, Direct2D or Windows UI Automation bindings
- An installer or signed binary release
