import SwiftUI

/// Root content of the body window. Observes the shared selection store and
/// swaps the rendered character when it changes — `.id(...)` forces
/// SwiftUI/RealityKit to fully rebuild the scene for the new model rather
/// than trying to mutate a live one.
@available(macOS 15.0, *)
struct BodyRootView: View {
    @ObservedObject private var store = SelectedCharacterStore.shared

    var body: some View {
        if let vrmURL = Bundle.module.url(forResource: store.selected.vrmResourceName, withExtension: "vrm"),
           let idleURL = Bundle.module.url(forResource: "idle-maid", withExtension: "vrma") {
            CharacterView(vrmURL: vrmURL, idleAnimationURL: idleURL)
                .id(store.selected.id)
        } else {
            BodyView()
        }
    }
}
