import SwiftUI

/// The character picker — big live preview on top, a horizontal row of
/// selectable characters along the bottom. Same shape as a game skin
/// picker: one large focused view, a strip of alternatives underneath.
@available(macOS 15.0, *)
struct ControlPanelView: View {
    @ObservedObject private var store = SelectedCharacterStore.shared
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            preview
            characterStrip
            footer
        }
        .frame(width: 420, height: 520)
        .background(Color(red: 0.09, green: 0.09, blue: 0.13))
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(store.selected.displayName)
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text(store.selected.rarity)
                .font(.caption.bold())
                .foregroundStyle(.yellow)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var preview: some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.2, green: 0.2, blue: 0.3), Color(red: 0.05, green: 0.05, blue: 0.08)],
                center: .center, startRadius: 10, endRadius: 220
            )
            if let vrmURL = Bundle.module.url(forResource: store.selected.vrmResourceName, withExtension: "vrm"),
               let idleURL = Bundle.module.url(forResource: "idle-maid", withExtension: "vrma") {
                CharacterView(vrmURL: vrmURL, idleAnimationURL: idleURL, registersForHitTesting: false)
                    .id(store.selected.id)
            }
        }
        .frame(height: 300)
        .clipped()
    }

    private var characterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(CharacterLibrary.all) { option in
                    CharacterThumbnail(option: option, isSelected: option.id == store.selected.id) {
                        store.selected = option
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 96)
        .background(Color.black.opacity(0.25))
    }

    private var footer: some View {
        Button(action: onDone) {
            Text("Done")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(16)
    }
}

@available(macOS 15.0, *)
private struct CharacterThumbnail: View {
    let option: CharacterOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.orange.opacity(0.85) : Color.white.opacity(0.08))
                    .frame(width: 68, height: 68)
                    .overlay(
                        Text(String(option.displayName.prefix(1)))
                            .font(.title.bold())
                            .foregroundStyle(.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.yellow : Color.white.opacity(0.15), lineWidth: isSelected ? 3 : 1)
                    )
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .background(Circle().fill(.white))
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
