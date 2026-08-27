#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif

/// Bravura/SMuFL code points used by the Android scene renderer.
public enum AndroidSMuFLGlyph: UInt32, Hashable, Sendable {
  case gClef = 0xE050
  case fClef = 0xE062
  case timeSignature0 = 0xE080
  case timeSignature1 = 0xE081
  case timeSignature2 = 0xE082
  case timeSignature3 = 0xE083
  case timeSignature4 = 0xE084
  case timeSignature5 = 0xE085
  case timeSignature6 = 0xE086
  case timeSignature7 = 0xE087
  case timeSignature8 = 0xE088
  case timeSignature9 = 0xE089
  case noteheadWhole = 0xE0A2
  case noteheadHalf = 0xE0A3
  case noteheadBlack = 0xE0A4
  case augmentationDot = 0xE1E7
  case flag8thUp = 0xE240
  case flag8thDown = 0xE241
  case flag16thUp = 0xE242
  case flag16thDown = 0xE243
  case accidentalFlat = 0xE260
  case accidentalNatural = 0xE261
  case accidentalSharp = 0xE262
  case accidentalDoubleSharp = 0xE263
  case accidentalDoubleFlat = 0xE264
  case restWhole = 0xE4E3
  case restHalf = 0xE4E4
  case restQuarter = 0xE4E5
  case restEighth = 0xE4E6
  case articAccentAbove = 0xE4A0
  case articAccentBelow = 0xE4A1
  case articStaccatoAbove = 0xE4A2
  case articStaccatoBelow = 0xE4A3
  case articTenutoAbove = 0xE4A4
  case articTenutoBelow = 0xE4A5
  case articStaccatissimoAbove = 0xE4A6
  case articStaccatissimoBelow = 0xE4A7
  case articMarcatoAbove = 0xE4AC
  case articMarcatoBelow = 0xE4AD
  case fermataAbove = 0xE4C0
  case fermataBelow = 0xE4C1
  case breathMarkComma = 0xE4CE
  case caesura = 0xE4D1
  case ornamentTrill = 0xE566
  case ornamentTurn = 0xE567
  case ornamentTurnInverted = 0xE568
  case ornamentMordent = 0xE56C
  case ornamentMordentInverted = 0xE56D

  public var character: String { String(UnicodeScalar(rawValue)!) }

  public static func timeSignatureDigit(_ value: UInt8) -> Self? {
    switch value {
    case 0: .timeSignature0
    case 1: .timeSignature1
    case 2: .timeSignature2
    case 3: .timeSignature3
    case 4: .timeSignature4
    case 5: .timeSignature5
    case 6: .timeSignature6
    case 7: .timeSignature7
    case 8: .timeSignature8
    case 9: .timeSignature9
    default: nil
    }
  }

  public static func accidental(_ value: AccidentalKind) -> Self? {
    switch value {
    case .flat: .accidentalFlat
    case .natural: .accidentalNatural
    case .sharp: .accidentalSharp
    case .doubleFlat: .accidentalDoubleFlat
    case .doubleSharp: .accidentalDoubleSharp
    default: nil
    }
  }

  public static func named(_ name: String) -> Self? {
    switch name {
    case "gClef": .gClef
    case "fClef": .fClef
    case "noteheadBlack": .noteheadBlack
    case "noteheadHalf": .noteheadHalf
    case "noteheadWhole": .noteheadWhole
    case "augmentationDot": .augmentationDot
    case "flag8thUp": .flag8thUp
    case "flag8thDown": .flag8thDown
    case "flag16thUp": .flag16thUp
    case "flag16thDown": .flag16thDown
    case "restQuarter": .restQuarter
    case "restHalf": .restHalf
    case "restWhole": .restWhole
    case "rest8th": .restEighth
    case "accidentalFlat": .accidentalFlat
    case "accidentalNatural": .accidentalNatural
    case "accidentalSharp": .accidentalSharp
    case "accidentalDoubleFlat": .accidentalDoubleFlat
    case "accidentalDoubleSharp": .accidentalDoubleSharp
    case "articAccentAbove": .articAccentAbove
    case "articAccentBelow": .articAccentBelow
    case "articStaccatoAbove": .articStaccatoAbove
    case "articStaccatoBelow": .articStaccatoBelow
    case "articTenutoAbove": .articTenutoAbove
    case "articTenutoBelow": .articTenutoBelow
    case "articStaccatissimoAbove": .articStaccatissimoAbove
    case "articStaccatissimoBelow": .articStaccatissimoBelow
    case "articMarcatoAbove": .articMarcatoAbove
    case "articMarcatoBelow": .articMarcatoBelow
    case "fermataAbove": .fermataAbove
    case "fermataBelow": .fermataBelow
    case "breathMarkComma": .breathMarkComma
    case "caesura": .caesura
    case "ornamentTrill": .ornamentTrill
    case "ornamentTurn": .ornamentTurn
    case "ornamentTurnInverted": .ornamentTurnInverted
    case "ornamentMordent": .ornamentMordent
    case "ornamentMordentInverted": .ornamentMordentInverted
    default: nil
    }
  }
}
