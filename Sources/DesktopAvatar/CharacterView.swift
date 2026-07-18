import AppKit
import Combine
import RealityKit
import SwiftUI
import VRMKit
import VRMRealityKit

/// Native RealityKit viewport rendering a VRM character, no external engine.
/// Plays its bundled idle animation on an endless loop by default — a
/// character should never just stand frozen, even before any reaction
/// system decides to interrupt it with something specific.
@available(macOS 15.0, *)
struct CharacterView: NSViewRepresentable {
    let vrmURL: URL
    let idleAnimationURL: URL

    final class Coordinator {
        var player: VRMAPlayer?
        var cancellable: Cancellable?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.environment.background = .color(.clear)
        configureCamera(in: view)
        loadCharacter(into: view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: ARView, context: Context) {}

    private func configureCamera(in view: ARView) {
        let camera = PerspectiveCamera()
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(camera)
        camera.look(at: [0, 1, 0], from: [0, 1, -3], relativeTo: nil)
        view.scene.addAnchor(cameraAnchor)

        let light = DirectionalLight()
        light.light.intensity = 3000
        let lightAnchor = AnchorEntity(world: .zero)
        lightAnchor.addChild(light)
        light.look(at: [0, 0, 0], from: [2, 4, 2], relativeTo: nil)
        view.scene.addAnchor(lightAnchor)
    }

    private func loadCharacter(into view: ARView, coordinator: Coordinator) {
        do {
            let rawData = try Data(contentsOf: vrmURL)
            let repairedData = VRMCompatibility.makeLoadable(rawData)
            let loader = try VRMEntityLoader(withData: repairedData)
            let vrmEntity = try loader.loadEntity()
            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(vrmEntity.entity)
            // VRM models' authored "forward" doesn't match our camera side — turn her around.
            vrmEntity.entity.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            view.scene.addAnchor(anchor)
            CharacterState.shared.arView = view
            CharacterState.shared.vrmEntity = vrmEntity

            let animation = try VRMAAnimation.load(contentsOf: idleAnimationURL)
            let player = VRMAPlayer(animation: animation, vrmEntity: vrmEntity)
            coordinator.player = player
            coordinator.cancellable = view.scene.subscribe(to: SceneEvents.Update.self) { [weak coordinator] event in
                coordinator?.player?.update(deltaTime: Float(event.deltaTime))
            }
        } catch {
            NSLog("DesktopAvatar: failed to load character or animation: \(error)")
        }
    }
}
