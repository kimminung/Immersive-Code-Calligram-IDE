import Foundation
import CoreGraphics
import CoreText

/// Procedurally draws the sky dome and ground grid textures with Core Graphics.
nonisolated enum EnvironmentTextureRenderer {
    /// Equirectangular sky: deep gradient, faint latitude/longitude grid, and scattered code glyphs.
    static func makeSkyImage(width: Int = 2048, height: Int = 1024) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        let w = CGFloat(width)
        let h = CGFloat(height)

        // Vertical gradient: zenith (top) → horizon → ground (bottom).
        let colors: [CGColor] = [
            CGColor(srgbRed: 0.02, green: 0.03, blue: 0.09, alpha: 1),
            CGColor(srgbRed: 0.05, green: 0.09, blue: 0.20, alpha: 1),
            CGColor(srgbRed: 0.10, green: 0.26, blue: 0.34, alpha: 1),
            CGColor(srgbRed: 0.04, green: 0.06, blue: 0.09, alpha: 1),
            CGColor(srgbRed: 0.01, green: 0.01, blue: 0.02, alpha: 1),
        ]
        let locations: [CGFloat] = [0, 0.35, 0.5, 0.56, 1]
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: [])
        }

        // Horizon glow band.
        let glowColors: [CGColor] = [
            CGColor(srgbRed: 0.2, green: 0.8, blue: 0.9, alpha: 0),
            CGColor(srgbRed: 0.2, green: 0.8, blue: 0.9, alpha: 0.22),
            CGColor(srgbRed: 0.2, green: 0.8, blue: 0.9, alpha: 0),
        ]
        if let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors as CFArray, locations: [0, 0.5, 1]) {
            context.drawLinearGradient(glow, start: CGPoint(x: 0, y: h * 0.56), end: CGPoint(x: 0, y: h * 0.44), options: [])
        }

        // Latitude / longitude grid every 15 degrees.
        context.setStrokeColor(CGColor(srgbRed: 0.5, green: 0.85, blue: 1, alpha: 0.07))
        context.setLineWidth(1.5)
        for k in 0...24 {
            let x = w * CGFloat(k) / 24
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: h))
        }
        for k in 0...12 {
            let y = h * CGFloat(k) / 12
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: w, y: y))
        }
        context.strokePath()

        // Emphasized horizon line.
        context.setStrokeColor(CGColor(srgbRed: 0.5, green: 0.9, blue: 1, alpha: 0.25))
        context.setLineWidth(3)
        context.move(to: CGPoint(x: 0, y: h * 0.5))
        context.addLine(to: CGPoint(x: w, y: h * 0.5))
        context.strokePath()

        // Scattered faint code glyphs in the upper hemisphere.
        drawScatteredGlyphs(in: context, width: w, height: h)

        return context.makeImage()
    }

    private static func drawScatteredGlyphs(in context: CGContext, width: CGFloat, height: CGFloat) {
        let glyphPool = Array("{}[]()<>=+-*/;:.,_$#@!?&|^~%0123456789letvarforinifemitcossinsqrt")
        var generator = SeededGenerator(seed: 20260927)
        let font = CTFontCreateWithName("Menlo" as CFString, 22, nil)
        context.textMatrix = .identity

        for _ in 0..<520 {
            let x = CGFloat.random(in: 0..<width, using: &generator)
            // Keep glyphs above the horizon (upper half of the image).
            let y = CGFloat.random(in: (height * 0.53)..<height, using: &generator)
            let alpha = CGFloat.random(in: 0.04...0.18, using: &generator)
            let character = glyphPool[Int.random(in: 0..<glyphPool.count, using: &generator)]
            let color = CGColor(srgbRed: 0.6, green: 0.9, blue: 1, alpha: alpha)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(character), attributes: attributes))
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
        }
    }

    /// Square transparent grid with a radial fade, used as the floor reference plane.
    static func makeGroundGridImage(size: Int = 1024, divisions: Int = 24) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        let s = CGFloat(size)
        context.clear(CGRect(x: 0, y: 0, width: s, height: s))

        context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55))
        context.setLineWidth(2)
        for k in 0...divisions {
            let position = s * CGFloat(k) / CGFloat(divisions)
            context.move(to: CGPoint(x: position, y: 0))
            context.addLine(to: CGPoint(x: position, y: s))
            context.move(to: CGPoint(x: 0, y: position))
            context.addLine(to: CGPoint(x: s, y: position))
        }
        context.strokePath()

        // Center axes slightly brighter.
        context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.9))
        context.setLineWidth(3)
        context.move(to: CGPoint(x: s / 2, y: 0))
        context.addLine(to: CGPoint(x: s / 2, y: s))
        context.move(to: CGPoint(x: 0, y: s / 2))
        context.addLine(to: CGPoint(x: s, y: s / 2))
        context.strokePath()

        // Radial fade so the grid dissolves toward the edges.
        let fadeColors: [CGColor] = [
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0),
        ]
        if let fade = CGGradient(colorsSpace: colorSpace, colors: fadeColors as CFArray, locations: [0, 0.35, 1]) {
            context.setBlendMode(.destinationIn)
            let center = CGPoint(x: s / 2, y: s / 2)
            context.drawRadialGradient(fade, startCenter: center, startRadius: 0, endCenter: center, endRadius: s / 2, options: [])
            context.setBlendMode(.normal)
        }

        return context.makeImage()
    }
}

/// Small deterministic generator so procedural textures look identical on every launch.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
