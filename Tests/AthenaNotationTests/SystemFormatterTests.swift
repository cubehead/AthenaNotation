import AthenaNotationCore
import AthenaNotationLayout
import XCTest

final class SystemFormatterTests: XCTestCase {
  func testAutomaticBreaksUseActualEngravingWidthAndKeepEveryEvent() {
    let inputs = (0..<12).map { index in
      LayoutInput(
        event: event("event-\(index)"),
        voiceID: "voice",
        onset: Rational(Int64(index), 4),
        metrics: EventLayoutMetrics(noteWidth: 16, leftExtent: 2, rightExtent: 18)
      )
    }

    let systems = SystemFormatter().format(
      inputs: inputs,
      fittingWidth: 180,
      measureDuration: .one
    )

    XCTAssertGreaterThan(systems.count, 1)
    XCTAssertEqual(systems.flatMap(\.events).count, inputs.count)
    XCTAssertTrue(systems.allSatisfy { $0.minimumWidth <= 180 })
  }

  func testAutomaticBreaksDoNotImposeMeasuresPerSystemLimit() {
    let inputs = (0..<20).map { index in
      LayoutInput(
        event: event("event-\(index)"),
        voiceID: "voice",
        onset: Rational(Int64(index), 4),
        metrics: EventLayoutMetrics(noteWidth: 4)
      )
    }

    let systems = SystemFormatter().format(
      inputs: inputs,
      fittingWidth: 1_000,
      measureDuration: .one
    )

    XCTAssertEqual(systems.count, 1)
  }

  func testAutomaticBreaksPreferMeasureBoundaryBeforeOverflow() throws {
    let inputs = (0..<9).map { index in
      LayoutInput(
        event: event("event-\(index)"),
        voiceID: "voice",
        onset: Rational(Int64(index), 4),
        metrics: EventLayoutMetrics(noteWidth: 20, leftExtent: 2, rightExtent: 10)
      )
    }

    let systems = SystemFormatter().format(
      inputs: inputs,
      fittingWidth: 190,
      measureDuration: .one
    )

    XCTAssertEqual(try XCTUnwrap(systems.dropFirst().first?.contexts.first?.onset), .one)
  }

  func testBalancesContextsAcrossTwoSystems() {
    let inputs = (0..<5).map { index in
      LayoutInput(
        event: event("event-\(index)"),
        voiceID: "voice",
        onset: Rational(Int64(index), 4)
      )
    }

    let systems = SystemFormatter().format(inputs: inputs, systemCount: 2, justifyTo: 400)

    XCTAssertEqual(systems.count, 2)
    XCTAssertEqual(systems[0].contexts.count, 3)
    XCTAssertEqual(systems[1].contexts.count, 2)
  }

  func testKeepsSharedOnsetVoicesOnSameSystem() throws {
    let sharedOnset = Rational(1, 4)
    let inputs = [
      LayoutInput(event: event("upper"), voiceID: "upper", onset: sharedOnset),
      LayoutInput(event: event("lower"), voiceID: "lower", onset: sharedOnset),
      LayoutInput(event: event("before"), voiceID: "upper", onset: .zero),
      LayoutInput(event: event("after"), voiceID: "upper", onset: Rational(1, 2)),
    ]

    let systems = SystemFormatter().format(inputs: inputs, systemCount: 2, justifyTo: 400)
    let containingSystem = try XCTUnwrap(
      systems.first { system in
        system.events.contains { $0.input.event.id.rawValue == "upper" }
      })

    XCTAssertTrue(containingSystem.events.contains { $0.input.event.id.rawValue == "lower" })
  }

  func testPrefersMeasureBoundaryWhenSplittingSystems() {
    let onsets: [Rational] = [
      .zero, Rational(1, 4), Rational(1, 2), Rational(3, 4),
      .one, Rational(5, 4), Rational(3, 2),
    ]
    let inputs = onsets.enumerated().map { index, onset in
      LayoutInput(event: event("event-\(index)"), voiceID: "voice", onset: onset)
    }

    let systems = SystemFormatter().format(
      inputs: inputs,
      systemCount: 2,
      justifyTo: 400,
      measureDuration: .one
    )

    XCTAssertEqual(systems.map { $0.contexts.first?.onset }, [.zero, .one])
  }

  private func event(_ id: String) -> NotationEvent {
    NotationEvent(
      id: NotationEventID(rawValue: id),
      content: .notes([
        NotatedPitch(midi: MIDIPitch(rawValue: 60), step: .c, octave: 4)
      ]),
      duration: Rational(1, 4),
      staffID: "treble"
    )
  }
}
