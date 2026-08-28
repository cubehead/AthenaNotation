#!/bin/sh
set -eu

repository_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
baseline="$repository_dir/API/PublicAPI.txt"
temporary=$(mktemp)
trap 'rm -f "$temporary"' EXIT

cd "$repository_dir"
swift package dump-symbol-graph \
  --skip-synthesized-members \
  --minimum-access-level public >/dev/null

graph_dir=$(find .build -type d -name symbolgraph -print | head -n 1)
if [ -z "$graph_dir" ]; then
  echo "No Swift symbol graph directory was produced." >&2
  exit 1
fi

modules="AthenaNotationCore AthenaNotationLayout AthenaNotationRenderApple AthenaNotationRenderAndroid AthenaScoreAnalysis AthenaMusicXML AthenaMIDI"
for module in $modules; do
  graph="$graph_dir/$module.symbols.json"
  if [ ! -f "$graph" ]; then
    echo "Missing symbol graph for $module." >&2
    exit 1
  fi
  jq -r --arg module "$module" '
    .symbols[]
    | [
        $module,
        "symbol",
        .kind.identifier,
        (.pathComponents | join(".")),
        # Swift 6.0 omits @Sendable from some typealias symbol-graph
        # declarations that Swift 6.3 emits. Normalize that compiler-only
        # presentation difference before comparing source API.
        ((.declarationFragments // []) | map(.spelling) | join("") | gsub("@Sendable "; ""))
      ]
    | @tsv
  ' "$graph"
  jq -r --arg module "$module" '
    . as $graph
    | ($graph.symbols
        | map({key: .identifier.precise, value: (.pathComponents | join("."))})
        | from_entries) as $names
    |
    .relationships[]
    | select(.kind == "conformsTo" or .kind == "inheritsFrom" or .kind == "requirementOf")
    | ($names[.source] // empty) as $source
    | ($names[.target] // .targetFallback // empty) as $target
    | select($source != "" and $target != "")
    # Swift 6.3 began emitting this implicit metatype conformance for every
    # Sendable type. It is compiler metadata, not source API.
    | select($target != "Swift.SendableMetatype")
    | [$module, "relationship", .kind, $source, $target]
    | @tsv
  ' "$graph"
done | LC_ALL=C sort > "$temporary"

if [ "${1:-}" = "--record" ]; then
  mkdir -p "$(dirname -- "$baseline")"
  cp "$temporary" "$baseline"
  chmod 644 "$baseline"
  echo "Recorded public API baseline at $baseline"
  exit 0
fi

if [ ! -f "$baseline" ]; then
  echo "Public API baseline is missing. Run Tools/check-api-baseline.sh --record." >&2
  exit 1
fi

if ! diff -u "$baseline" "$temporary"; then
  echo "Public API changed. Review it, then record the intentional 1.x-compatible baseline." >&2
  exit 1
fi

echo "Public API matches API/PublicAPI.txt"
