import AthenaNotationCore
import AthenaNotationLayout
import XCTest

final class SpannerPlannerTests: XCTestCase {
  func testKeepsSlurInOneSystem() {
    let layouts = layoutsForTwoSystems()
    let slur = NotationSpanner(
      id: "slur",
      kind: .slur,
      startEventID: eventID("a"),
      endEventID: eventID("b")
    )

    let segments = SpannerPlanner().segments(spanners: [slur], layouts: layouts)

    XCTAssertEqual(segments.count, 1)
    XCTAssertEqual(segments.first?.systemIndex, 0)
    XCTAssertEqual(segments.first?.start, .event(eventID("a")))
    XCTAssertEqual(segments.first?.end, .event(eventID("b")))
  }

  func testSplitsTieAcrossSystemBreak() {
    let layouts = layoutsForTwoSystems()
    let tie = NotationSpanner(
      id: "tie",
      kind: .tie,
      startEventID: eventID("b"),
      endEventID: eventID("c")
    )

    let segments = SpannerPlanner().segments(spanners: [tie], layouts: layouts)

    XCTAssertEqual(segments.count, 2)
    XCTAssertEqual(segments[0].start, .event(eventID("b")))
    XCTAssertEqual(segments[0].end, .trailingSystemEdge)
    XCTAssertEqual(segments[1].start, .leadingSystemEdge)
    XCTAssertEqual(segments[1].end, .event(eventID("c")))
  }

  func testPedalAcrossSystemShowsOneLabelAndOneFinalHook() {
    let pedal = NotationSpanner(
      id: "pedal",
      kind: .pedal,
      startEventID: eventID("a"),
      endEventID: eventID("c")
    )

    let segments = SpannerPlanner().segments(spanners: [pedal], layouts: layoutsForTwoSystems())

    XCTAssertEqual(segments.count, 2)
    XCTAssertTrue(segments[0].showsPedalLabel)
    XCTAssertFalse(segments[0].showsPedalReleaseHook)
    XCTAssertFalse(segments[1].showsPedalLabel)
    XCTAssertTrue(segments[1].showsPedalReleaseHook)
  }

  func testAdjacentPedalRangesOnlyLabelFirstPress() {
    let first = NotationSpanner(
      id: "pedal-1",
      kind: .pedal,
      startEventID: eventID("a"),
      endEventID: eventID("b")
    )
    let second = NotationSpanner(
      id: "pedal-2",
      kind: .pedal,
      startEventID: eventID("c"),
      endEventID: eventID("d")
    )

    let segments = SpannerPlanner().segments(
      spanners: [first, second],
      layouts: layoutsForAdjacentPedals()
    )

    XCTAssertEqual(segments.count, 2)
    XCTAssertTrue(segments[0].showsPedalLabel)
    XCTAssertTrue(segments[0].showsPedalReleaseHook)
    XCTAssertFalse(segments[1].showsPedalLabel)
    XCTAssertTrue(segments[1].showsPedalReleaseHook)
  }

  private func layoutsForTwoSystems() -> [HorizontalLayout] {
    let inputs = [
      LayoutInput(event: event("a"), voiceID: "voice", onset: .zero),
      LayoutInput(event: event("b"), voiceID: "voice", onset: Rational(1, 2)),
      LayoutInput(event: event("c"), voiceID: "voice", onset: .one),
    ]
    return SystemFormatter().format(
      inputs: inputs,
      systemCount: 2,
      justifyTo: 400,
      measureDuration: .one
    )
  }

  private func layoutsForAdjacentPedals() -> [HorizontalLayout] {
    let inputs = [
      LayoutInput(event: event("a"), voiceID: "voice", onset: .zero),
      LayoutInput(event: event("b"), voiceID: "voice", onset: Rational(1, 2)),
      LayoutInput(event: event("c"), voiceID: "voice", onset: .one),
      LayoutInput(event: event("d"), voiceID: "voice", onset: Rational(3, 2)),
    ]
    return SystemFormatter().format(
      inputs: inputs,
      systemCount: 1,
      justifyTo: 400,
      measureDuration: Rational(2, 1)
    )
  }

  private func event(_ id: String) -> NotationEvent {
    NotationEvent(
      id: eventID(id),
      content: .notes([NotatedPitch(midi: MIDIPitch(rawValue: 60), step: .c, octave: 4)]),
      duration: Rational(1, 2),
      staffID: "treble"
    )
  }

  private func eventID(_ value: String) -> NotationEventID {
    NotationEventID(rawValue: value)
  }
}
