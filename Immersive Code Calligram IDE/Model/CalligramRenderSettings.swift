import Foundation

/// How each glyph quad is oriented in space.
nonisolated enum GlyphFacing: String, Sendable, CaseIterable, Identifiable {
    /// Every glyph faces +Z (toward the viewer standing in front of the entity).
    case viewer
    /// Each glyph faces away from the shape's centroid.
    case outward

    var id: String { rawValue }

    var title: String {
        switch self {
        case .viewer: return "정면"
        case .outward: return "바깥"
        }
    }
}

/// User-adjustable rendering options that don't live in the script itself.
nonisolated struct CalligramRenderSettings: Sendable, Equatable {
    var glyphScale: Float = 1.0
    var facing: GlyphFacing = .viewer
    var isSpinning = true
    var spinSpeed: Float = 0.25

    /// Builds every glyph as two perpendicular quads (an "X" seen from above) so the calligram
    /// never turns edge-on and vanishes while it spins or when viewed from the side.
    var alwaysVisible = true

    /// Strength of the view-angle dependent hue shift (0 = flat color, 1 = full rainbow sweep).
    var iridescence: Float = 0.65

    /// Where the entity sits in the immersive space (meters, relative to the floor origin).
    var immersivePosition = SIMD3<Float>(0, 1.4, -1.6)
}
