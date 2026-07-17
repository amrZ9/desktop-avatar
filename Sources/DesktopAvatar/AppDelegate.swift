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
        window.contentView = NSHostingView(rootView: BodyView())
        window.makeKeyAndOrderFront(nil)
    }

    private func makeBodyWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
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
