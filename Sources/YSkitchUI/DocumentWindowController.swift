import AppKit
import YSkitchCore

@MainActor
final class DocumentWindowController: NSWindowController {
    static let chromeSize = CGSize.zero

    let defaultFileName: String
    let model: DocumentModel
    let scrollView: CanvasScrollView
    let canvasView: CanvasView

    init(document: Document, title: String) {
        defaultFileName = title
        model = DocumentModel(document: document)
        canvasView = CanvasView(model: model)

        let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let contentSize = WindowSizing.contentSize(
            documentSize: document.canvasRect.size, chrome: Self.chromeSize, visibleFrame: visible)
        scrollView = CanvasScrollView(frame: NSRect(origin: .zero, size: contentSize))
        scrollView.documentView = canvasView

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
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
