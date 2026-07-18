import Foundation
import RealityKit
import VRMKitRuntime
import VRMRealityKit
import simd

/// Drives a VRMEntity's bones frame by frame from a parsed VRMAAnimation,
/// looping forever. This is the "always animated, never a static T-pose"
/// baseline behavior — the default state a character is in before any
/// specific gesture/reaction system decides to override it.
@available(macOS 15.0, *)
@MainActor
final class VRMAPlayer {
    private let animation: VRMAAnimation
    private let vrmEntity: VRMEntity

    /// Elmer's own rest-pose local rotation/translation per bone, captured
    /// once before any animation is applied. Retargeting reapplies each
    /// keyframe as a *delta from the clip's own rest pose* on top of this,
    /// rather than substituting the clip's raw values directly — otherwise
    /// any difference between the two rigs' authored rest poses folds the
    /// character into a contorted shape.
    private var targetRestRotation: [String: simd_quatf] = [:]
    private var targetRestTranslation: [String: SIMD3<Float>] = [:]

    init(animation: VRMAAnimation, vrmEntity: VRMEntity) {
        self.animation = animation
        self.vrmEntity = vrmEntity

        for track in animation.tracks {
            guard let bone = Humanoid<Entity>.Bones(rawValue: track.bone),
                  let boneEntity = vrmEntity.humanoid.node(for: bone)
            else { continue }
            targetRestRotation[track.bone] = boneEntity.transform.rotation
            targetRestTranslation[track.bone] = boneEntity.transform.translation
        }
    }

    private var elapsedTime: Float = 0

    func update(deltaTime: Float) {
        guard animation.duration > 0 else { return }
        elapsedTime += deltaTime
        let loopTime = elapsedTime.truncatingRemainder(dividingBy: animation.duration)

        for track in animation.tracks {
            guard let bone = Humanoid<Entity>.Bones(rawValue: track.bone),
                  let boneEntity = vrmEntity.humanoid.node(for: bone)
            else { continue }
            if let rotations = track.rotations, let targetRest = targetRestRotation[track.bone] {
                let animated = Self.sample(times: track.times, values: rotations, at: loopTime, interpolate: simd_slerp)
                let delta = track.sourceRestRotation.inverse * animated
                boneEntity.transform.rotation = (targetRest * delta).normalized
            }
            if let translations = track.translations, let targetRest = targetRestTranslation[track.bone] {
                let animated = Self.sample(times: track.times, values: translations, at: loopTime) { a, b, t in
                    a + (b - a) * t
                }
                boneEntity.transform.translation = targetRest + (animated - track.sourceRestTranslation)
            }
        }

        // Bone entities moving isn't enough — VRMEntity caches skin pose in a
        // SkeletalPosesComponent that only refreshes here.
        vrmEntity.update(at: TimeInterval(deltaTime))
    }

    private static func sample<Value>(
        times: [Float],
        values: [Value],
        at time: Float,
        interpolate: (Value, Value, Float) -> Value
    ) -> Value {
        guard times.count == values.count, !times.isEmpty else { return values[0] }
        if time <= times[0] { return values[0] }
        if time >= times[times.count - 1] { return values[values.count - 1] }

        var lo = 0
        var hi = times.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if times[mid] <= time { lo = mid } else { hi = mid }
        }
        let span = times[hi] - times[lo]
        let alpha = span > 0 ? (time - times[lo]) / span : 0
        return interpolate(values[lo], values[hi], alpha)
    }
}
