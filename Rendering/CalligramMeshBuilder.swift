import Foundation
import simd

/// Raw vertex data for a calligram mesh, ready to be wrapped in a `MeshDescriptor` on the main actor.
nonisolated struct CalligramMeshData: Sendable {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var textureCoordinates: [SIMD2<Float>] = []
    var indices: [UInt32] = []
    /// One material index per triangle.
    var materialIndices: [UInt32] = []
    /// Distinct (quantized) RGBA colors; the index into this array is the material index.
    var palette: [SIMD4<Float>] = []

    var quadCount: Int { positions.count / 4 }
}

/// Turns emitted points into one quad per glyph, sharing a single glyph-atlas texture.
nonisolated enum CalligramMeshBuilder {
    static let maxPaletteSize = 48
    private static let quantizationSteps: Float = 31

    static func build(points: [CalligramPoint], settings: CalligramRenderSettings) -> CalligramMeshData {
        var data = CalligramMeshData()
        guard !points.isEmpty else { return data }

        data.positions.reserveCapacity(points.count * 4)
        data.normals.reserveCapacity(points.count * 4)
        data.textureCoordinates.reserveCapacity(points.count * 4)
        data.indices.reserveCapacity(points.count * 6)
        data.materialIndices.reserveCapacity(points.count * 2)

        var centroid = SIMD3<Float>.zero
        for point in points { centroid += point.position }
        centroid /= Float(points.count)

        var paletteLookup: [SIMD4<Float>: UInt32] = [:]

        for point in points {
            let facing = facingDirection(for: point.position, centroid: centroid, mode: settings.facing)
            let (right, up) = basis(for: facing)
            let half = point.size * settings.glyphScale * 0.5
            let center = point.position

            let base = UInt32(data.positions.count)
            data.positions.append(center - right * half - up * half)
            data.positions.append(center + right * half - up * half)
            data.positions.append(center + right * half + up * half)
            data.positions.append(center - right * half + up * half)

            for _ in 0..<4 { data.normals.append(facing) }

            let uv = GlyphAtlasLayout.uvRect(forCell: GlyphAtlasLayout.cellIndex(for: point.glyph))
            data.textureCoordinates.append(SIMD2<Float>(uv.min.x, uv.min.y))
            data.textureCoordinates.append(SIMD2<Float>(uv.max.x, uv.min.y))
            data.textureCoordinates.append(SIMD2<Float>(uv.max.x, uv.max.y))
            data.textureCoordinates.append(SIMD2<Float>(uv.min.x, uv.max.y))

            data.indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])

            let materialIndex = paletteIndex(for: point.color, palette: &data.palette, lookup: &paletteLookup)
            data.materialIndices.append(materialIndex)
            data.materialIndices.append(materialIndex)
        }

        return data
    }

    // MARK: - Orientation

    private static func facingDirection(for position: SIMD3<Float>, centroid: SIMD3<Float>, mode: GlyphFacing) -> SIMD3<Float> {
        switch mode {
        case .viewer:
            return SIMD3<Float>(0, 0, 1)
        case .outward:
            let offset = position - centroid
            let length = simd_length(offset)
            return length > 1e-5 ? offset / length : SIMD3<Float>(0, 0, 1)
        }
    }

    /// Builds right/up vectors perpendicular to `facing` so glyphs stay upright where possible.
    private static func basis(for facing: SIMD3<Float>) -> (right: SIMD3<Float>, up: SIMD3<Float>) {
        var reference = SIMD3<Float>(0, 1, 0)
        if abs(simd_dot(facing, reference)) > 0.98 {
            reference = SIMD3<Float>(0, 0, -1)
        }
        let right = simd_normalize(simd_cross(reference, facing))
        let up = simd_normalize(simd_cross(facing, right))
        return (right, up)
    }

    // MARK: - Palette

    private static func paletteIndex(for color: SIMD4<Float>,
                                     palette: inout [SIMD4<Float>],
                                     lookup: inout [SIMD4<Float>: UInt32]) -> UInt32 {
        let quantized = (color * quantizationSteps).rounded(.toNearestOrEven) / quantizationSteps
        if let existing = lookup[quantized] { return existing }
        if palette.count < maxPaletteSize {
            let index = UInt32(palette.count)
            palette.append(quantized)
            lookup[quantized] = index
            return index
        }
        // Palette is full: reuse the closest existing color.
        var bestIndex: UInt32 = 0
        var bestDistance = Float.greatestFiniteMagnitude
        for (index, candidate) in palette.enumerated() {
            let distance = simd_length_squared(candidate - quantized)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = UInt32(index)
            }
        }
        lookup[quantized] = bestIndex
        return bestIndex
    }
}
