import AppKit

/// Container view for the body window's content. Click-through is handled
/// at the window level (AppDelegate toggles `ignoresMouseEvents` based on
/// the character's live projected bounds), so this view just needs to let
/// a click-and-drag on the character move the window, and surface a
/// right-click as the entry point into the control panel.
final class CharacterHitView: NSView {
    var onRightClick: (() -> Void)?

    override var mouseDownCanMoveWindow: Bool { true }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }
}
