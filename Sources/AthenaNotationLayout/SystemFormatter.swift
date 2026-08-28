#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif
import Foundation

/// Splits exact-onset contexts into balanced systems, then runs the horizontal
/// formatter independently for each line. Events sharing an onset are never
/// separated across systems.
public struct SystemFormatter: Sendable {
  public let horizontalFormatter: HorizontalFormatter

  public init(horizontalFormatter: HorizontalFormatter = .init()) {
    self.horizontalFormatter = horizontalFormatter
  }

  public func format(
    inputs: [LayoutInput],
    systemCount requestedSystemCount: Int,
    justifyTo width: Double,
    measureDuration: Rational? = nil
  ) -> [HorizontalLayout] {
    precondition(requestedSystemCount > 0)
    guard !inputs.isEmpty else { return [] }

    let contexts = Dictionary(grouping: inputs, by: \.onset)
      .sorted { $0.key < $1.key }
      .map(\.value)
    let systemCount = min(requestedSystemCount, contexts.count)
    let splitIndices = splitIndices(
      contexts: contexts,
      systemCount: systemCount,
      measureDuration: measureDuration
    )
    let bounds = [0] + splitIndices + [contexts.count]
    let systems = zip(bounds, bounds.dropFirst()).map { start, end in
      Array(contexts[start..<end]).flatMap { $0 }
    }

    return systems.map { horizontalFormatter.format(inputs: $0, justifyTo: width) }
  }

  /// Breaks a complete score into as many systems as its engraved width requires.
  ///
  /// This overload does not impose a measures-per-system limit. It greedily fits
  /// collision-aware tick contexts into the available width, preferring a measure
  /// boundary when one is available and falling back to a beat-level break only
  /// when a single measure is too dense to fit.
  public func format(
    inputs: [LayoutInput],
    fittingWidth width: Double,
    measureDuration: Rational? = nil
  ) -> [HorizontalLayout] {
    precondition(width > 0)
    guard !inputs.isEmpty else { return [] }

    let contexts = Dictionary(grouping: inputs, by: \.onset)
      .sorted { $0.key < $1.key }
      .map(\.value)
    let measureBoundaries = measureBoundaryIndices(
      contexts: contexts,
      measureDuration: measureDuration
    )
    var systems: [[LayoutInput]] = []
    var start = 0

    while start < contexts.count {
      var end = start
      var occupiedWidth = 0.0
      var lastMeasureBoundary: Int?

      while end < contexts.count {
        let context = contexts[end]
        let left = context.map(\.metrics.leftExtent).max() ?? 0
        let right = context.map { $0.metrics.noteWidth + $0.metrics.rightExtent }.max() ?? 0
        let nextWidth = occupiedWidth
          + (end == start ? 0 : horizontalFormatter.options.minimumContextGap)
          + left + right

        if end > start, nextWidth > width { break }
        occupiedWidth = nextWidth
        end += 1
        if measureBoundaries.contains(end) {
          lastMeasureBoundary = end
        }
      }

      if end < contexts.count,
        let boundary = lastMeasureBoundary,
        boundary > start
      {
        end = boundary
      }

      let systemInputs = Array(contexts[start..<end]).flatMap { $0 }
      systems.append(systemInputs)
      start = end
    }

    return systems.map { horizontalFormatter.format(inputs: $0, justifyTo: width) }
  }

  private func splitIndices(
    contexts: [[LayoutInput]],
    systemCount: Int,
    measureDuration: Rational?
  ) -> [Int] {
    guard systemCount > 1 else { return [] }

    let measureBoundaries: Set<Int>
    if let measureDuration {
      precondition(measureDuration > .zero)
      measureBoundaries = Set(
        contexts.indices.dropFirst().filter { index in
          guard let onset = contexts[index].first?.onset else { return false }
          let measure = onset / measureDuration
          return measure.denominator == 1
        })
    } else {
      measureBoundaries = []
    }

    var result: [Int] = []
    var lowerBound = 1
    for systemIndex in 1..<systemCount {
      let systemsRemaining = systemCount - systemIndex
      let upperBound = contexts.count - systemsRemaining
      let ideal = Int(
        (Double(contexts.count) * Double(systemIndex) / Double(systemCount)).rounded())
      let candidates = measureBoundaries.filter { lowerBound...upperBound ~= $0 }
      let split =
        candidates.min {
          let lhsDistance = abs($0 - ideal)
          let rhsDistance = abs($1 - ideal)
          return lhsDistance == rhsDistance ? $0 < $1 : lhsDistance < rhsDistance
        } ?? min(max(ideal, lowerBound), upperBound)
      result.append(split)
      lowerBound = split + 1
    }
    return result
  }

  private func measureBoundaryIndices(
    contexts: [[LayoutInput]],
    measureDuration: Rational?
  ) -> Set<Int> {
    guard let measureDuration else { return [] }
    precondition(measureDuration > .zero)
    return Set(
      contexts.indices.dropFirst().filter { index in
        guard let onset = contexts[index].first?.onset else { return false }
        return (onset / measureDuration).denominator == 1
      })
  }
}
