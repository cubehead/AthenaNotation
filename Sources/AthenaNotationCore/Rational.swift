// Portions of this design are adapted from VexFlow 5.0.0's Fraction type.
// VexFlow is Copyright (c) VexFlow contributors and Mohit Muthanna Cheppudira.
// Licensed under the MIT License. See ThirdPartyNotices/VEXFLOW.md.

/// An exact rational number used for musical time.
///
/// Integer ticks alone become awkward when tuplets introduce new divisors. Keeping
/// time rational follows VexFlow's model and lets importers postpone resolution loss.
public struct Rational: Hashable, Sendable, Codable, Comparable, CustomStringConvertible {
  public let numerator: Int64
  public let denominator: Int64

  public static let zero = Rational(0, 1)
  public static let one = Rational(1, 1)

  public init(_ numerator: Int64, _ denominator: Int64 = 1) {
    precondition(denominator != 0, "A rational denominator cannot be zero")

    let sign: Int64 = denominator < 0 ? -1 : 1
    let divisor = Self.greatestCommonDivisor(numerator, denominator)
    self.numerator = sign * numerator / divisor
    self.denominator = sign * denominator / divisor
  }

  public var doubleValue: Double {
    Double(numerator) / Double(denominator)
  }

  public var description: String {
    "\(numerator)/\(denominator)"
  }

  public static func + (lhs: Self, rhs: Self) -> Self {
    Self(
      lhs.numerator * rhs.denominator + rhs.numerator * lhs.denominator,
      lhs.denominator * rhs.denominator
    )
  }

  public static func - (lhs: Self, rhs: Self) -> Self {
    Self(
      lhs.numerator * rhs.denominator - rhs.numerator * lhs.denominator,
      lhs.denominator * rhs.denominator
    )
  }

  public static func * (lhs: Self, rhs: Self) -> Self {
    Self(lhs.numerator * rhs.numerator, lhs.denominator * rhs.denominator)
  }

  public static func / (lhs: Self, rhs: Self) -> Self {
    precondition(rhs.numerator != 0, "Cannot divide by zero")
    return Self(lhs.numerator * rhs.denominator, lhs.denominator * rhs.numerator)
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.numerator * rhs.denominator < rhs.numerator * lhs.denominator
  }

  private static func greatestCommonDivisor(_ first: Int64, _ second: Int64) -> Int64 {
    var a = Swift.abs(first)
    var b = Swift.abs(second)

    while b != 0 {
      (a, b) = (b, a % b)
    }

    return max(a, 1)
  }
}
