import AppKit

@MainActor
final class DocumentWindowController: NSWindowController {
    static let defaultContentSize = NSSize(width: 900, height: 600)

    init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Untitled"
        window.isReleasedWhenClosed = false
        window.contentView = PlaceholderView()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

private final class PlaceholderView: NSView {
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.white.cgColor
    }
}
