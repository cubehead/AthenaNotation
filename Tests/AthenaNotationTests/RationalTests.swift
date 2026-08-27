import AthenaNotationCore
import XCTest

final class RationalTests: XCTestCase {
  func testSimplifiesAndNormalizesSign() {
    XCTAssertEqual(Rational(6, -8), Rational(-3, 4))
  }

  func testExactTupletArithmetic() {
    let tripletEighth = Rational(1, 12)
    XCTAssertEqual(tripletEighth + tripletEighth + tripletEighth, Rational(1, 4))
  }
}
