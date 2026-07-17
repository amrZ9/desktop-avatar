import SwiftUI

/// Placeholder content for the body shell. This is where the actual
/// character (3D model, sprite, whatever we land on) will render later.
struct BodyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(.blue.opacity(0.85))
                .frame(width: 96, height: 96)
                .overlay(
                    Text("👋")
                        .font(.system(size: 40))
                )
            Text("Desktop Avatar")
                .font(.headline)
                .foregroundStyle(.white)
                .shadow(radius: 2)
        }
        .padding(20)
    }
}
