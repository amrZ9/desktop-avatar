import AppKit
import SwiftUI

/// Owns the body window — a borderless, transparent, always-on-top panel
/// that will host the character. Everything about this app runs in this
/// one process; there is no separate engine or HTTP API to talk to.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = makeBodyWindow()

        let container = CharacterHitView()
        let hosting = NSHostingView(rootView: rootContent())
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = container.bounds
        container.addSubview(hosting)
        window.contentView = container
        hosting.frame = container.bounds

        window.makeKeyAndOrderFront(nil)
        startMouseTracking()
    }

    /// Click-through is all-or-nothing per window on macOS, so we flip
    /// `ignoresMouseEvents` live: over the character the window takes clicks
    /// (drag her around); anywhere else every click falls through to
    /// whatever app is underneath, as if this window didn't exist.
    private var mouseTimer: Timer?

    private func startMouseTracking() {
        window.ignoresMouseEvents = true
        // Event monitors are unreliable for mouseMoved delivery; a fast poll
        // of the cursor position always works and costs next to nothing.
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            Task { @MainActor in
                self.updateClickability()
            }
        }
    }

    private func updateClickability() {
        let mouse = NSEvent.mouseLocation

        // Prefer the character's actual projected on-screen bounds; fall back
        // to a central band of the window until the model has loaded.
        let clickableRect: NSRect
        if let projected = CharacterState.shared.characterScreenRect() {
            clickableRect = projected
        } else {
            let frame = window.frame
            clickableRect = NSRect(
                x: frame.minX + frame.width * 0.30,
                y: frame.minY + frame.height * 0.02,
                width: frame.width * 0.40,
                height: frame.height * 0.92
            )
        }
        window.ignoresMouseEvents = !clickableRect.contains(mouse)
    }

    @ViewBuilder
    private func rootContent() -> some View {
        if let vrmURL = Bundle.module.url(forResource: "Elmer", withExtension: "vrm"),
           let idleURL = Bundle.module.url(forResource: "idle-maid", withExtension: "vrma") {
            CharacterView(vrmURL: vrmURL, idleAnimationURL: idleURL)
        } else {
            BodyView()
        }
    }

    private func makeBodyWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = true
        positionBottomRight(window)
        return window
    }

    private func positionBottomRight(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let margin: CGFloat = 40
        let origin = NSPoint(
            x: screen.visibleFrame.maxX - window.frame.width - margin,
            y: screen.visibleFrame.minY + margin
        )
        window.setFrameOrigin(origin)
    }
}
