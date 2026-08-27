public struct ChordNotePlacement: Hashable, Sendable {
  public let pitchIndex: Int
  public let staffPosition: Int
  /// Horizontal notehead columns relative to the chord anchor.
  public let noteheadColumn: Int
  /// Zero is nearest the noteheads; larger values move farther left.
  public let accidentalColumn: Int?

  public init(
    pitchIndex: Int,
    staffPosition: Int,
    noteheadColumn: Int,
    accidentalColumn: Int?
  ) {
    self.pitchIndex = pitchIndex
    self.staffPosition = staffPosition
    self.noteheadColumn = noteheadColumn
    self.accidentalColumn = accidentalColumn
  }
}

/// Plans chord notehead displacement and accidental columns independently of
/// font metrics. Rendering scales the returned columns using measured glyphs.
public struct ChordPlanner: Sendable {
  public init() {}

  /// VexFlow-style displacement keeps the shifted head touching the opposite
  /// side of the stem instead of merely nudging two heads on the same side.
  public func horizontalAdvance(noteheadWidth: Double, stemWidth: Double) -> Double {
    precondition(noteheadWidth > 0)
    precondition(stemWidth >= 0)
    return max(0, noteheadWidth - stemWidth / 2)
  }

  public func placements(
    staffPositions: [Int],
    stemUp: Bool,
    accidentalPitchIndices: Set<Int> = []
  ) -> [ChordNotePlacement] {
    let sorted = staffPositions.enumerated().sorted {
      if $0.element != $1.element { return $0.element < $1.element }
      return $0.offset < $1.offset
    }
    var noteheadColumns: [Int: Int] = [:]
    var runStart = 0
    while runStart < sorted.count {
      var runEnd = runStart
      while runEnd + 1 < sorted.count,
        sorted[runEnd + 1].element - sorted[runEnd].element == 1
      {
        runEnd += 1
      }
      if runEnd > runStart {
        for index in runStart...runEnd {
          let offset = index - runStart
          noteheadColumns[sorted[index].offset] =
            stemUp
            ? (offset.isMultiple(of: 2) ? 0 : 1)
            : (offset.isMultiple(of: 2) ? -1 : 0)
        }
      }
      runStart = runEnd + 1
    }

    var positionsByAccidentalColumn: [[Int]] = []
    var accidentalColumns: [Int: Int] = [:]
    for item in sorted.reversed() where accidentalPitchIndices.contains(item.offset) {
      var column = 0
      while column < positionsByAccidentalColumn.count,
        positionsByAccidentalColumn[column].contains(where: { abs($0 - item.element) < 4 })
      {
        column += 1
      }
      if column == positionsByAccidentalColumn.count {
        positionsByAccidentalColumn.append([])
      }
      positionsByAccidentalColumn[column].append(item.element)
      accidentalColumns[item.offset] = column
    }

    return staffPositions.indices.map { pitchIndex in
      ChordNotePlacement(
        pitchIndex: pitchIndex,
        staffPosition: staffPositions[pitchIndex],
        noteheadColumn: noteheadColumns[pitchIndex, default: 0],
        accidentalColumn: accidentalColumns[pitchIndex]
      )
    }
  }
}
