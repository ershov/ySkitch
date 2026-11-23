import AppKit
import UniformTypeIdentifiers
import YSkitchCore

@MainActor
final class DocumentWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    static let chromeSize = CGSize(width: ToolbarView.width, height: StatusBarView.height)

    private(set) var defaultFileName: String
    let model: DocumentModel
    let toolbar: ToolbarModel
    let selection: SelectionModel
    let scrollView: CanvasScrollView
    let canvasView: CanvasView
    let statusBar = StatusBarView()
    private(set) var savedURL: URL?

    init(document: Document, title: String, toolSettings: ToolSettings = .shared) {
        defaultFileName = title
        model = DocumentModel(document: document)
        toolbar = ToolbarModel(settings: toolSettings)
        selection = SelectionModel(model: model)
        toolbar.selection = selection
        canvasView = CanvasView(model: model, toolbar: toolbar, selection: selection)

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
        let toolbarView = ToolbarHostingView(rootView: ToolbarView(model: toolbar))
        toolbarView.sizingOptions = []
        window.contentView = DocumentContentView(
            scrollView: scrollView, statusBar: statusBar, toolbar: toolbarView, toolbarWidth: ToolbarView.width)
        window.initialFirstResponder = canvasView
        super.init(window: window)
        window.delegate = self

        model.onChange = { [weak self] in
            guard let self else { return }
            selection.documentDidChange()
            canvasView.documentDidChange()
            updateStatusSize()
        }
        selection.onChange = { [weak canvasView] in canvasView?.needsDisplay = true }
        statusBar.onActualSize = { [weak scrollView] in scrollView?.zoomToActualSize() }
        statusBar.onFit = { [weak scrollView] in scrollView?.zoomToFit() }
        statusBar.onZoomOut = { [weak scrollView] in scrollView?.zoomOut() }
        statusBar.onZoomIn = { [weak scrollView] in scrollView?.zoomIn() }
        scrollView.onMagnificationChange = { [weak statusBar] in statusBar?.update(magnification: $0) }
        statusBar.dragHandle.imageProvider = { [weak self] in
            guard let self else { return (Data(), "image", NSImage()) }
            return dragPayload()
        }
        updateStatusSize()
        scrollView.zoomToFit()
        statusBar.update(magnification: scrollView.magnification)
    }

    private func updateStatusSize() {
        statusBar.update(canvasSize: model.document.canvasRect.size, scale: model.document.scale)
    }

    private func dragPayload() -> DragHandleView.Payload {
        let document = model.document
        let bitmap = NSBitmapImageRep(cgImage: Renderer.flatten(document))
        let thumbnail = NSImage(size: document.canvasRect.size)
        thumbnail.addRepresentation(bitmap)
        bitmap.size = document.canvasRect.size
        return (ImageExporter.pngData(document), defaultFileName, thumbnail)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? { model.undoManager }

    func windowDidResignKey(_ notification: Notification) { canvasView.commitTextEditing() }

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

    @discardableResult
    func paste(from pasteboard: NSPasteboard) -> Bool {
        guard let image = PasteboardImageReader.read(from: pasteboard) else { return false }
        let sourceURL = PasteboardImageReader.imageFileURLs(in: pasteboard).first
        model.perform("Paste Image") { $0 = Document(image: image) }
        defaultFileName = DocumentNaming.title(sourceURL: sourceURL, date: .now)
        window?.title = defaultFileName
        savedURL = nil
        scrollView.zoomToFit()
        return true
    }

    @objc func paste(_ sender: Any?) {
        if !paste(from: .general) { NSSound.beep() }
    }

    @objc func delete(_ sender: Any?) { selection.deleteSelected() }

    /// Switches to the Select tool so the selection stays visible and editable.
    override func selectAll(_ sender: Any?) {
        toolbar.activeTool = .select
        selection.selectAll()
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(paste(_:)): PasteboardImageReader.containsImage(.general)
        case #selector(delete(_:)): !selection.isEmpty && !model.isInGesture
        case #selector(selectAll(_:)): !model.document.annotations.isEmpty && !model.isInGesture
        default: true
        }
    }

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
