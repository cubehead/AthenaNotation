# Public API stability

AthenaNotation 1.x follows Semantic Versioning. Public declarations in these
library products are covered by the compatibility policy:

- `AthenaNotationCore`
- `AthenaNotationLayout`
- `AthenaNotationRenderApple`
- `AthenaNotationRenderAndroid`
- `AthenaScoreAnalysis`
- `AthenaMusicXML`
- `AthenaMIDI`

## Compatibility promise

Patch releases fix defects without intentionally changing source-compatible
public API. Minor releases may add API, notation coverage, render commands, and
optional Codable fields. Removing or renaming public declarations, changing
their types, or changing existing semantic meaning requires a new major
version.

Codable and Android JSON consumers must ignore unknown keys. New enum cases and
new raw-value notation kinds can appear in minor releases; clients should keep
fallback behavior for symbols they do not render yet.

## Automated baseline

[`API/PublicAPI.txt`](../API/PublicAPI.txt) is generated from Swift Symbol Graph
output. Compiler-private identifiers are normalized to public symbol paths, and
toolchain-only synthesized metadata is excluded, so the baseline remains stable
across supported Swift 6.x toolchains. CI runs:

```sh
Tools/check-api-baseline.sh
```

When an intentional compatible API addition is reviewed, update the baseline:

```sh
Tools/check-api-baseline.sh --record
```

The textual baseline is a review gate, not a replacement for behavior tests or
Semantic Versioning judgment.

## Pre-1.0 transition

Version 1.0 establishes this promise. API from the earlier 0.1 preview may be
refined in the 1.0 release; compatibility is guaranteed beginning with the
committed 1.0 baseline.
