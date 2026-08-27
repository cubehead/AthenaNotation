import CoreText
import Foundation

public struct BravuraGlyphMetrics: Hashable, Sendable {
  public let bounds: CGRect
  public let advance: CGSize
}

/// Process-scoped registration for the bundled Bravura SMuFL font.
public enum BravuraFont {
  public static let familyName = "Bravura"

  public static let isRegistered: Bool = {
    guard let url = resourceBundle.url(forResource: "Bravura", withExtension: "otf") else {
      return false
    }

    var unmanagedError: Unmanaged<CFError>?
    if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &unmanagedError) {
      return true
    }

    guard let error = unmanagedError?.takeRetainedValue() else {
      return false
    }
    return CFErrorGetCode(error) == 105
  }()

  private static var resourceBundle: Bundle {
    #if SWIFT_PACKAGE
      return .module
    #else
      let host = Bundle(for: BundleToken.self)
      for bundle in [host, .main] {
        if let url = bundle.url(forResource: "AthenaNotationResources", withExtension: "bundle"),
          let resources = Bundle(url: url)
        {
          return resources
        }
      }
      return host
    #endif
  }

  public static func contains(_ glyph: SMuFLGlyph) -> Bool {
    guard isRegistered else { return false }
    let font = CTFontCreateWithName(familyName as CFString, 24, nil)
    var character = UniChar(glyph.rawValue)
    var output = CGGlyph()
    return CTFontGetGlyphsForCharacters(font, &character, &output, 1) && output != 0
  }

  public static func metrics(for glyph: SMuFLGlyph, size: Double) -> BravuraGlyphMetrics? {
    guard isRegistered else { return nil }
    let font = CTFontCreateWithName(familyName as CFString, size, nil)
    var character = UniChar(glyph.rawValue)
    var output = CGGlyph()
    guard CTFontGetGlyphsForCharacters(font, &character, &output, 1), output != 0 else {
      return nil
    }

    var bounds = CGRect.zero
    var advance = CGSize.zero
    CTFontGetBoundingRectsForGlyphs(font, .default, &output, &bounds, 1)
    CTFontGetAdvancesForGlyphs(font, .default, &output, &advance, 1)
    return BravuraGlyphMetrics(bounds: bounds, advance: advance)
  }

  /// Returns the glyph's native outline at the requested point size.
  ///
  /// The path remains in CoreText's baseline-based, y-up coordinate space.
  /// Renderers should apply their own transform instead of passing the symbol
  /// through a text layout engine, so engraving geometry and drawing share the
  /// same measurements.
  public static func path(for glyph: SMuFLGlyph, size: Double) -> CGPath? {
    guard isRegistered else { return nil }
    let font = CTFontCreateWithName(familyName as CFString, size, nil)
    var character = UniChar(glyph.rawValue)
    var output = CGGlyph()
    guard CTFontGetGlyphsForCharacters(font, &character, &output, 1), output != 0 else {
      return nil
    }
    return CTFontCreatePathForGlyph(font, output, nil)
  }
}

private final class BundleToken {}
