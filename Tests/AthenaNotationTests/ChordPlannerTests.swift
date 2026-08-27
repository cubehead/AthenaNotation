import AthenaNotationLayout
import XCTest

final class ChordPlannerTests: XCTestCase {
  func testSecondIntervalCentersLandOnOppositeSidesOfStem() {
    let noteheadWidth = 12.0
    let stemWidth = 1.4
    let anchorX = 100.0
    let advance = ChordPlanner().horizontalAdvance(
      noteheadWidth: noteheadWidth,
      stemWidth: stemWidth
    )

    let downStemX = anchorX - noteheadWidth / 2 + stemWidth / 2
    XCTAssertLessThan(anchorX - advance, downStemX)
    XCTAssertGreaterThan(anchorX, downStemX)

    let upStemX = anchorX + noteheadWidth / 2 - stemWidth / 2
    XCTAssertLessThan(anchorX, upStemX)
    XCTAssertGreaterThan(anchorX + advance, upStemX)
  }

  func testSecondIntervalDisplacesNoteheadOppositeUpStem() {
    let placements = ChordPlanner().placements(staffPositions: [0, 1], stemUp: true)

    XCTAssertEqual(placements.map(\.noteheadColumn), [0, 1])
  }

  func testSecondIntervalDisplacesNoteheadOppositeDownStem() {
    let placements = ChordPlanner().placements(staffPositions: [0, 1], stemUp: false)

    XCTAssertEqual(placements.map(\.noteheadColumn), [-1, 0])
  }

  func testCloseAccidentalsStaggerAcrossColumns() {
    let placements = ChordPlanner().placements(
      staffPositions: [0, 2, 4],
      stemUp: true,
      accidentalPitchIndices: [0, 1, 2]
    )

    XCTAssertEqual(placements.compactMap(\.accidentalColumn), [0, 1, 0])
  }

  func testDistantAccidentalsReuseNearestColumn() {
    let placements = ChordPlanner().placements(
      staffPositions: [0, 4, 8],
      stemUp: true,
      accidentalPitchIndices: [0, 1, 2]
    )

    XCTAssertEqual(placements.compactMap(\.accidentalColumn), [0, 0, 0])
  }
}
