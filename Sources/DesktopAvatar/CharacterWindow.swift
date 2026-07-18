import AppKit

/// Container view for the body window's content. Click-through is handled
/// at the window level (AppDelegate toggles `ignoresMouseEvents` based on
/// the character's live projected bounds), so this view just needs to let
/// a click-and-drag on the character move the window.
final class CharacterHitView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}
