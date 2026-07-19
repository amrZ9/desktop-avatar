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
        let hosting = NSHostingView(rootView: BodyRootView())
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = container.bounds
        container.addSubview(hosting)
        window.contentView = container
        hosting.frame = container.bounds

        window.makeKeyAndOrderFront(nil)
        startMouseTracking()
        startRightClickMonitor()
        startTripleClickMonitor()
    }

    /// ARView (RealityKit's render view) sits on top of our container and
    /// swallows mouse events before they'd ever reach a view-level
    /// rightMouseDown override, so we catch the right-click at the window
    /// level instead. This only fires at all when the window isn't
    /// ignoring mouse events, which — per updateClickability() — is only
    /// when the cursor is over the character, so no extra position check
    /// is needed here.
    private func startRightClickMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard event.window === self?.window else { return event }
            self?.openControlPanel()
            return event
        }
    }

    /// Triple-click on the character opens the control panel. Same
    /// window-level trick as the right-click monitor — this only fires
    /// when the cursor is over her, since that's the only time the window
    /// stops ignoring mouse events at all.
    private func startTripleClickMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard event.window === self?.window, event.clickCount == 3 else { return event }
            self?.openControlPanel()
            return event
        }
    }

    private var controlPanelWindow: NSWindow?

    private func openControlPanel() {
        if let controlPanelWindow {
            controlPanelWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Choose Character"
        panel.isReleasedWhenClosed = false
        panel.center()
        panel.contentView = NSHostingView(
            rootView: ControlPanelView { [weak self] in self?.controlPanelWindow?.close() }
        )
        controlPanelWindow = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
