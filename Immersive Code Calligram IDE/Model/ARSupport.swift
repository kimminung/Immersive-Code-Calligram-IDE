import Foundation
#if os(iOS) && !targetEnvironment(simulator)
import ARKit
#endif

/// Answers whether the AR placement mode can run here.
///
/// AR needs the device camera and ARKit world tracking, so it is compiled only for real
/// iPhone/iPad hardware. The simulator, macOS, and visionOS always report `false` and show
/// the virtual-camera preview (or the immersive space) instead.
enum ARSupport {
    static var isAvailable: Bool {
        #if os(iOS) && !targetEnvironment(simulator)
        return ARWorldTrackingConfiguration.isSupported
        #else
        return false
        #endif
    }
}
