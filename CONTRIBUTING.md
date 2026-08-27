# Contributing

Thanks for helping improve AthenaNotation.

## Before opening a change

1. Open an issue for substantial API or engraving changes.
2. Keep changes within the documented public modules and preserve the one-way
   dependency structure described in `Documentation/Architecture.md`.
3. Add focused tests for semantic, import, layout, or rendering behavior.
4. Preserve exact rational timing; avoid converting score time to floating
   point inside the model and layout layers.

## Local checks

```sh
swift test
swift build --product AthenaNotationExample
pod lib lint AthenaNotation.podspec --allow-warnings
```

Use conventional, concise commit messages. Public API changes should also
update README.md and CHANGELOG.md.
