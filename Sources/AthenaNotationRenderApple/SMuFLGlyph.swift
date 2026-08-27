#if SWIFT_PACKAGE
  import AthenaNotationCore
#endif

/// Initial SMuFL subset sourced from the metadata used by VexFlow 5.0.0.
public enum SMuFLGlyph: UInt32, Hashable, Sendable {
  case gClef = 0xE050
  case fClef = 0xE062

  case timeSignature2 = 0xE082
  case timeSignature3 = 0xE083
  case timeSignature4 = 0xE084
  case timeSignature6 = 0xE086
  case timeSignature8 = 0xE088

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

  public var character: String {
    String(UnicodeScalar(rawValue)!)
  }

  public static func timeSignatureDigit(_ value: UInt8) -> Self? {
    switch value {
    case 2: .timeSignature2
    case 3: .timeSignature3
    case 4: .timeSignature4
    case 6: .timeSignature6
    case 8: .timeSignature8
    default: nil
    }
  }

  public static func accidental(_ accidental: AccidentalKind) -> Self? {
    switch accidental {
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
    default: nil
    }
  }
}
