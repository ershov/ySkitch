import AppKit

@MainActor
final class DragHandleView: NSView, NSDraggingSource {
    typealias Payload = (png: Data, fileName: String, thumbnail: NSImage)

    static let size = NSSize(width: 80, height: 20)
    private static let maxThumbnailSide: CGFloat = 128

    /// Returns nil when there is nothing to drag.
    var imageProvider: (() -> Payload?)?

    var isEnabled = true {
        didSet { alphaValue = isEnabled ? 1 : Self.disabledAlpha }
    }

    private static let disabledAlpha: CGFloat = 0.4

    private var mouseDownPoint: NSPoint?
    private var didDrag = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        toolTip = "Drag the image into another app"

        let symbol = NSImage(systemSymbolName: "hand.draw", accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
        let icon = NSImageView(image: symbol ?? NSImage())
        icon.contentTintColor = .secondaryLabelColor
        icon.symbolConfiguration = .init(pointSize: 11, weight: .regular)
        let label = NSTextField(labelWithString: "Drag")
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [icon, label])
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        wantsLayer = true
        layer?.cornerRadius = Self.size.height / 2
        layer?.borderWidth = 1
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.size.width),
            heightAnchor.constraint(equalToConstant: Self.size.height),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    convenience init() { self.init(frame: NSRect(origin: .zero, size: Self.size)) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override var wantsUpdateLayer: Bool { true }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled, !didDrag, mouseDownPoint != nil, let payload = imageProvider?() else { return }
        didDrag = true
        guard let item = try? Self.makePasteboardItem(png: payload.png, fileName: payload.fileName) else { return }

        let thumbnail = payload.thumbnail
        let longSide = max(thumbnail.size.width, thumbnail.size.height)
        let factor = longSide > Self.maxThumbnailSide ? Self.maxThumbnailSide / longSide : 1
        let size = NSSize(width: thumbnail.size.width * factor, height: thumbnail.size.height * factor)
        let cursor = convert(event.locationInWindow, from: nil)
        let draggingItem = NSDraggingItem(pasteboardWriter: item)
        draggingItem.setDraggingFrame(
            NSRect(x: cursor.x - size.width / 2, y: cursor.y - size.height / 2, width: size.width, height: size.height),
            contents: thumbnail)
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownPoint = nil
    }

    nonisolated func draggingSession(
        _ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    static func makePasteboardItem(png: Data, fileName: String) throws -> NSPasteboardItem {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ySkitch-drag", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName).appendingPathExtension("png")
        try png.write(to: url, options: .atomic)
        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)
        item.setData(png, forType: .png)
        return item
    }
}
