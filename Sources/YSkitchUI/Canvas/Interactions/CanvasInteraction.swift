import AppKit

/// A tool's mouse handling on the canvas; points are document coordinates.
@MainActor
protocol CanvasInteraction: AnyObject {
    func mouseDown(at point: CGPoint, event: NSEvent)
    func mouseDragged(to point: CGPoint, event: NSEvent)
    func mouseUp(at point: CGPoint, event: NSEvent)
    func flagsChanged(_ event: NSEvent)
    func cancel()
    var cursor: NSCursor { get }
    /// Called when the tool becomes active.
    func activate()
    /// Offered key-down events first; returns true when handled.
    func handleKey(_ event: NSEvent) -> Bool
}

extension CanvasInteraction {
    func activate() {}
    func handleKey(_ event: NSEvent) -> Bool { false }
}
