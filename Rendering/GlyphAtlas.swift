import Foundation
import CoreGraphics
import CoreText
import simd

/// Layout of the glyph atlas texture: printable ASCII (32...127) in a 16 × 6 grid.
/// UV coordinates use RealityKit's convention: (0, 0) is the bottom-left of the image.
nonisolated enum GlyphAtlasLayout {
    static let columns = 16
    static let rows = 6
    static let cellSize = 64
    static let firstScalar: UInt32 = 32
    static let lastScalar: UInt32 = 127

    static var imageWidth: Int { columns * cellSize }
    static var imageHeight: Int { rows * cellSize }

    /// Index of the cell that displays `character`, falling back to '?' for unsupported glyphs.
    static func cellIndex(for character: Character) -> Int {
        guard let scalar = character.unicodeScalars.first?.value,
              scalar >= firstScalar, scalar <= lastScalar else {
            return Int(UInt32(UnicodeScalar("?").value) - firstScalar)
        }
        return Int(scalar - firstScalar)
    }

    /// UV rectangle (min, max) for a cell, with a small inset to avoid bleeding from neighbors.
    static func uvRect(forCell index: Int) -> (min: SIMD2<Float>, max: SIMD2<Float>) {
        let column = index % columns
        let row = index / columns
        let inset: Float = 0.5 / Float(cellSize)
        let u0 = Float(column) / Float(columns) + inset / Float(columns)
        let u1 = Float(column + 1) / Float(columns) - inset / Float(columns)
        // Row 0 is the top row of the image, which is v = 1 in RealityKit UV space.
        let v1 = 1 - Float(row) / Float(rows) - inset / Float(rows)
        let v0 = 1 - Float(row + 1) / Float(rows) + inset / Float(rows)
        return (SIMD2<Float>(u0, v0), SIMD2<Float>(u1, v1))
    }
}

/// Renders the glyph atlas with Core Text into a transparent RGBA image (white glyphs).
nonisolated enum GlyphAtlasRenderer {
    static func makeImage(fontName: String = "Menlo-Bold") -> CGImage? {
        let width = GlyphAtlasLayout.imageWidth
        let height = GlyphAtlasLayout.imageHeight
        let cell = CGFloat(GlyphAtlasLayout.cellSize)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setShouldSmoothFonts(true)
        context.textMatrix = .identity

        let font = CTFontCreateWithName(fontName as CFString, cell * 0.72, nil)
        let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): white,
        ]

        for scalar in GlyphAtlasLayout.firstScalar...GlyphAtlasLayout.lastScalar {
            let index = Int(scalar - GlyphAtlasLayout.firstScalar)
            guard let unicode = UnicodeScalar(scalar) else { continue }
            let character = Character(unicode)
            if character == " " || scalar == 127 { continue }

            let column = index % GlyphAtlasLayout.columns
            let row = index / GlyphAtlasLayout.columns
            // Core Graphics origin is bottom-left; row 0 must be the top row of the image.
            let cellX = CGFloat(column) * cell
            let cellY = CGFloat(height) - CGFloat(row + 1) * cell

            let attributed = NSAttributedString(string: String(character), attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributed)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let advance = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

            let x = cellX + (cell - advance) / 2
            let baseline = cellY + (cell - (ascent + descent)) / 2 + descent
            context.textPosition = CGPoint(x: x, y: baseline)
            CTLineDraw(line, context)
        }

        return context.makeImage()
    }
}
