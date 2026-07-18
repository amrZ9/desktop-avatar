import AppKit
import RealityKit
import VRMKitRuntime
import VRMRealityKit

/// Shared handle to the live scene so window-level logic (click-through
/// hit testing in AppDelegate) can ask where the character actually is
/// on screen, rather than guessing with a fixed rectangle.
@available(macOS 15.0, *)
@MainActor
final class CharacterState {
    static let shared = CharacterState()

    weak var arView: ARView?
    weak var vrmEntity: VRMEntity?

    /// Bones that outline the body silhouette in the current pose.
    /// (Mesh visualBounds can't be used: RealityKit reports the rest-pose
    /// T-pose bounds, which are far wider than any real standing pose.)
    private let silhouetteBones: [VRMKitRuntime.Humanoid<Entity>.Bones] = [
        .head, .neck, .chest, .hips,
        .leftShoulder, .rightShoulder,
        .leftLowerArm, .rightLowerArm,
        .leftHand, .rightHand,
        .leftLowerLeg, .rightLowerLeg,
        .leftFoot, .rightFoot,
    ]

    /// The character's current on-screen rectangle in screen coordinates,
    /// computed by projecting live bone positions through the camera.
    /// Nil until the character is loaded.
    func characterScreenRect() -> NSRect? {
        guard let arView, let vrmEntity, let window = arView.window else { return nil }

        var points: [SIMD3<Float>] = []
        for bone in silhouetteBones {
            guard let entity = vrmEntity.humanoid.node(for: bone) else { continue }
            let p = entity.position(relativeTo: nil as Entity?)
            points.append(p)
            if bone == .head {
                // The head bone sits at the neck; include the skull and hair.
                points.append(p + SIMD3<Float>(0, 0.16, 0))
            }
        }
        guard !points.isEmpty else { return nil }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        var projectedAny = false

        for point in points {
            guard let p = arView.project(point) else { continue }
            projectedAny = true
            minX = Swift.min(minX, p.x)
            minY = Swift.min(minY, p.y)
            maxX = Swift.max(maxX, p.x)
            maxY = Swift.max(maxY, p.y)
        }
        guard projectedAny else { return nil }

        let viewRect = NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let windowRect = arView.convert(viewRect, to: nil)
        let screenRect = window.convertToScreen(windowRect)
        // Bones are body centerlines, not surfaces — pad out to the visible edges.
        return screenRect.insetBy(dx: -16, dy: -10)
    }
}
