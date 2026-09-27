import Foundation
import RealityKit

/// Marks an entity that should rotate continuously around its local Y axis.
struct SpinComponent: Component {
    /// Radians per second. Zero disables rotation without removing the component.
    var speed: Float
}

/// Rotates every entity that carries a `SpinComponent`, using the frame delta time.
final class SpinSystem: System {
    private static let query = EntityQuery(where: .has(SpinComponent.self))
    private static var isRegistered = false

    required init(scene: RealityKit.Scene) {}

    /// Registers the component and system once per process.
    static func registerIfNeeded() {
        guard !isRegistered else { return }
        isRegistered = true
        SpinComponent.registerComponent()
        SpinSystem.registerSystem()
    }

    func update(context: SceneUpdateContext) {
        let delta = Float(context.deltaTime)
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            guard let spin = entity.components[SpinComponent.self], spin.speed != 0 else { continue }
            let rotation = simd_quatf(angle: delta * spin.speed, axis: SIMD3<Float>(0, 1, 0))
            entity.orientation = rotation * entity.orientation
        }
    }
}
