import AppKit
import UniformTypeIdentifiers
import YSkitchCore

@MainActor
final class DocumentWindowController: NSWindowController {
    static let chromeSize = CGSize.zero

    let defaultFileName: String
    let model: DocumentModel
    let scrollView: CanvasScrollView
    let canvasView: CanvasView
    private(set) var savedURL: URL?

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

    func copyImage(to pasteboard: NSPasteboard) {
        let document = model.document
        let flattened = Renderer.flatten(document)
        let bitmap = NSBitmapImageRep(cgImage: flattened)
        bitmap.size = document.canvasRect.size
        pasteboard.clearContents()
        pasteboard.setData(ImageExporter.pngData(document), forType: .png)
        if let tiff = bitmap.tiffRepresentation { pasteboard.setData(tiff, forType: .tiff) }
    }

    @objc func copyImage(_ sender: Any?) { copyImage(to: .general) }
    @objc func copy(_ sender: Any?) { copyImage(sender) }

    func write(to url: URL) throws {
        try ImageExporter.pngData(model.document).write(to: url, options: .atomic)
    }

    @objc func saveDocument(_ sender: Any?) {
        guard let savedURL else { return saveDocumentAs(sender) }
        do { try write(to: savedURL) } catch { present(error) }
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        guard let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = defaultFileName
        panel.directoryURL = Preferences.shared.lastSaveFolder
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                do {
                    try self.write(to: url)
                    self.savedURL = url
                    Preferences.shared.lastSaveFolder = url.deletingLastPathComponent()
                } catch {
                    self.present(error)
                }
            }
        }
    }

    private func present(_ error: Error) {
        guard let window else { return }
        NSAlert(error: error).beginSheetModal(for: window)
    }
}
