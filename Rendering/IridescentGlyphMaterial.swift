import Foundation
import RealityKit

/// A view-dependent "thin film" glyph material built as a MaterialX shader graph.
///
/// The graph is unlit (so it looks the same in the immersive space and in the window preview) and:
/// - samples the glyph atlas for the opacity mask,
/// - measures how much the surface faces the viewer, `f = 1 − |N·V|`,
/// - rotates the base color's hue by `iridescence · (f + 0.2·|N·L|)`, boosts saturation and
///   brightness toward grazing angles, so every glyph shifts through the spectrum as it turns.
///
/// Parameters exposed to Swift: `atlas` (texture), `baseColor` (float3), `baseOpacity`, `iridescence`.
@MainActor
enum IridescentGlyphMaterial {
    static let primPath = "/Root/IridescentGlyph"

    /// Loads the material, or returns `nil` if this platform rejects the shader graph.
    static func load() async -> ShaderGraphMaterial? {
        if let data = usda.data(using: .utf8),
           let material = try? await ShaderGraphMaterial(named: primPath, from: data) {
            return configured(material)
        }
        // Some loaders only sniff the format from the file extension; retry from a temp file.
        do {
            let url = try writeTemporaryFile()
            let material = try await ShaderGraphMaterial(named: primPath, from: url)
            return configured(material)
        } catch {
            print("[IridescentGlyphMaterial] load failed: \(error)")
            return nil
        }
    }

    private static func configured(_ material: ShaderGraphMaterial) -> ShaderGraphMaterial {
        var material = material
        material.faceCulling = .none
        return material
    }

    private static func writeTemporaryFile() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("CalligramMaterials", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("IridescentGlyph.usda")
        try usda.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Shader graph source

    /// USD + MaterialX description of the graph. Node ids follow the MaterialX 1.38 standard
    /// library plus RealityKit's `ND_realitykit_*` extensions.
    ///
    /// Note: the unlit surface node's inputs are camelCase (`opacityThreshold`,
    /// `applyPostProcessToneMap`, `hasPremultipliedAlpha`); the snake_case names shown in the
    /// documentation make the loader fail with `invalidTypeFound`.
    static let usda = """
    #usda 1.0
    (
        defaultPrim = "Root"
        metersPerUnit = 1
        upAxis = "Y"
    )

    def Xform "Root"
    {
        def Material "IridescentGlyph"
        {
            asset inputs:atlas = @@
            float3 inputs:baseColor = (1, 1, 1)
            float inputs:baseOpacity = 1
            float inputs:iridescence = 0.65
            token outputs:mtlx:surface.connect = </Root/IridescentGlyph/Surface.outputs:out>
            token outputs:realitykit:vertex

            def Shader "Surface"
            {
                uniform token info:id = "ND_realitykit_unlit_surfaceshader"
                color3f inputs:color.connect = </Root/IridescentGlyph/FinalColor.outputs:out>
                float inputs:opacity.connect = </Root/IridescentGlyph/Opacity.outputs:out>
                float inputs:opacityThreshold = 0.35
                bool inputs:applyPostProcessToneMap = 0
                bool inputs:hasPremultipliedAlpha = 0
                token outputs:out
            }

            // --- Opacity from the glyph atlas -------------------------------------------------
            def Shader "UV"
            {
                uniform token info:id = "ND_texcoord_vector2"
                int inputs:index = 0
                float2 outputs:out
            }

            def Shader "Atlas"
            {
                uniform token info:id = "ND_image_color4"
                asset inputs:file.connect = </Root/IridescentGlyph.inputs:atlas>
                float2 inputs:texcoord.connect = </Root/IridescentGlyph/UV.outputs:out>
                string inputs:filtertype = "linear"
                string inputs:uaddressmode = "clamp"
                string inputs:vaddressmode = "clamp"
                color4f outputs:out
            }

            def Shader "AtlasChannels"
            {
                uniform token info:id = "ND_separate4_color4"
                color4f inputs:in.connect = </Root/IridescentGlyph/Atlas.outputs:out>
                float outputs:outr
                float outputs:outg
                float outputs:outb
                float outputs:outa
            }

            def Shader "Opacity"
            {
                uniform token info:id = "ND_multiply_float"
                float inputs:in1.connect = </Root/IridescentGlyph/AtlasChannels.outputs:outr>
                float inputs:in2.connect = </Root/IridescentGlyph.inputs:baseOpacity>
                float outputs:out
            }

            // --- View-angle terms -------------------------------------------------------------
            def Shader "ViewDir"
            {
                uniform token info:id = "ND_realitykit_viewdirection_vector3"
                string inputs:space = "world"
                float3 outputs:out
            }

            def Shader "Normal"
            {
                uniform token info:id = "ND_normal_vector3"
                string inputs:space = "world"
                float3 outputs:out
            }

            def Shader "NdotV"
            {
                uniform token info:id = "ND_dotproduct_vector3"
                float3 inputs:in1.connect = </Root/IridescentGlyph/Normal.outputs:out>
                float3 inputs:in2.connect = </Root/IridescentGlyph/ViewDir.outputs:out>
                float outputs:out
            }

            def Shader "Facing"
            {
                uniform token info:id = "ND_absval_float"
                float inputs:in.connect = </Root/IridescentGlyph/NdotV.outputs:out>
                float outputs:out
            }

            def Shader "Grazing"
            {
                uniform token info:id = "ND_subtract_float"
                float inputs:in1 = 1
                float inputs:in2.connect = </Root/IridescentGlyph/Facing.outputs:out>
                float outputs:out
            }

            def Shader "NdotL"
            {
                uniform token info:id = "ND_dotproduct_vector3"
                float3 inputs:in1.connect = </Root/IridescentGlyph/Normal.outputs:out>
                float3 inputs:in2 = (0.36, 0.48, 0.8)
                float outputs:out
            }

            def Shader "LightTerm"
            {
                uniform token info:id = "ND_absval_float"
                float inputs:in.connect = </Root/IridescentGlyph/NdotL.outputs:out>
                float outputs:out
            }

            def Shader "LightScaled"
            {
                uniform token info:id = "ND_multiply_float"
                float inputs:in1.connect = </Root/IridescentGlyph/LightTerm.outputs:out>
                float inputs:in2 = 0.2
                float outputs:out
            }

            def Shader "PhaseSum"
            {
                uniform token info:id = "ND_add_float"
                float inputs:in1.connect = </Root/IridescentGlyph/Grazing.outputs:out>
                float inputs:in2.connect = </Root/IridescentGlyph/LightScaled.outputs:out>
                float outputs:out
            }

            def Shader "Phase"
            {
                uniform token info:id = "ND_multiply_float"
                float inputs:in1.connect = </Root/IridescentGlyph/PhaseSum.outputs:out>
                float inputs:in2.connect = </Root/IridescentGlyph.inputs:iridescence>
                float outputs:out
            }

            def Shader "Amount"
            {
                uniform token info:id = "ND_multiply_float"
                float inputs:in1.connect = </Root/IridescentGlyph/Grazing.outputs:out>
                float inputs:in2.connect = </Root/IridescentGlyph.inputs:iridescence>
                float outputs:out
            }

            // --- Hue rotation in HSV space ----------------------------------------------------
            def Shader "BaseColor3"
            {
                uniform token info:id = "ND_convert_vector3_color3"
                float3 inputs:in.connect = </Root/IridescentGlyph.inputs:baseColor>
                color3f outputs:out
            }

            def Shader "BaseHSV"
            {
                uniform token info:id = "ND_rgbtohsv_color3"
                color3f inputs:in.connect = </Root/IridescentGlyph/BaseColor3.outputs:out>
                color3f outputs:out
            }

            def Shader "HSVParts"
            {
                uniform token info:id = "ND_separate3_color3"
                color3f inputs:in.connect = </Root/IridescentGlyph/BaseHSV.outputs:out>
                float outputs:outr
                float outputs:outg
                float outputs:outb
            }

            def Shader "HueShifted"
            {
                uniform token info:id = "ND_add_float"
                float inputs:in1.connect = </Root/IridescentGlyph/HSVParts.outputs:outr>
                float inputs:in2.connect = </Root/IridescentGlyph/Phase.outputs:out>
                float outputs:out
            }

            def Shader "HueWrapped"
            {
                uniform token info:id = "ND_modulo_float"
                float inputs:in1.connect = </Root/IridescentGlyph/HueShifted.outputs:out>
                float inputs:in2 = 1
                float outputs:out
            }

            def Shader "SatBoost"
            {
                uniform token info:id = "ND_multiply_float"
                float inputs:in1.connect = </Root/IridescentGlyph/Amount.outputs:out>
                float inputs:in2 = 0.5
                float outputs:out
            }

            def Shader "SatSum"
            {
                uniform token info:id = "ND_add_float"
                float inputs:in1.connect = </Root/IridescentGlyph/HSVParts.outputs:outg>
                float inputs:in2.connect = </Root/IridescentGlyph/SatBoost.outputs:out>
                float outputs:out
            }

            def Shader "SatClamped"
            {
                uniform token info:id = "ND_clamp_float"
                float inputs:in.connect = </Root/IridescentGlyph/SatSum.outputs:out>
                float inputs:low = 0
                float inputs:high = 1
                float outputs:out
            }

            def Shader "ValBoost"
            {
                uniform token info:id = "ND_multiply_float"
                float inputs:in1.connect = </Root/IridescentGlyph/Amount.outputs:out>
                float inputs:in2 = 0.6
                float outputs:out
            }

            def Shader "ValFactor"
            {
                uniform token info:id = "ND_add_float"
                float inputs:in1.connect = </Root/IridescentGlyph/ValBoost.outputs:out>
                float inputs:in2 = 1
                float outputs:out
            }

            def Shader "ValScaled"
            {
                uniform token info:id = "ND_multiply_float"
                float inputs:in1.connect = </Root/IridescentGlyph/HSVParts.outputs:outb>
                float inputs:in2.connect = </Root/IridescentGlyph/ValFactor.outputs:out>
                float outputs:out
            }

            def Shader "ValClamped"
            {
                uniform token info:id = "ND_clamp_float"
                float inputs:in.connect = </Root/IridescentGlyph/ValScaled.outputs:out>
                float inputs:low = 0
                float inputs:high = 1
                float outputs:out
            }

            def Shader "NewHSV"
            {
                uniform token info:id = "ND_combine3_color3"
                float inputs:in1.connect = </Root/IridescentGlyph/HueWrapped.outputs:out>
                float inputs:in2.connect = </Root/IridescentGlyph/SatClamped.outputs:out>
                float inputs:in3.connect = </Root/IridescentGlyph/ValClamped.outputs:out>
                color3f outputs:out
            }

            def Shader "FinalColor"
            {
                uniform token info:id = "ND_hsvtorgb_color3"
                color3f inputs:in.connect = </Root/IridescentGlyph/NewHSV.outputs:out>
                color3f outputs:out
            }
        }
    }
    """
}
