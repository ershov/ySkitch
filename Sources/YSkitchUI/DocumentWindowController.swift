import AppKit
import YSkitchCore

@MainActor
final class DocumentWindowController: NSWindowController {
    static let defaultContentSize = NSSize(width: 900, height: 600)

    static func blankDocument() -> Document {
        Document(blankSize: CGSize(width: 1024, height: 768), scale: NSScreen.main?.backingScaleFactor ?? 2)
    }

    let model: DocumentModel
    let scrollView: CanvasScrollView
    let canvasView: CanvasView

    init(document: Document) {
        model = DocumentModel(document: document)
        canvasView = CanvasView(model: model)
        scrollView = CanvasScrollView(frame: NSRect(origin: .zero, size: Self.defaultContentSize))
        scrollView.documentView = canvasView

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Untitled"
        window.isReleasedWhenClosed = false
        window.contentView = scrollView
        window.initialFirstResponder = canvasView
        super.init(window: window)

        model.onChange = { [weak canvasView] in canvasView?.documentDidChange() }
        scrollView.zoomToFit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc func zoomIn(_ sender: Any?) { scrollView.zoomIn() }
    @objc func zoomOut(_ sender: Any?) { scrollView.zoomOut() }
    @objc func zoomToActualSize(_ sender: Any?) { scrollView.zoomToActualSize() }
    @objc func zoomToFit(_ sender: Any?) { scrollView.zoomToFit() }
}
