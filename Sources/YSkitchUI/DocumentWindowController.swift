import AppKit
import UniformTypeIdentifiers
import YSkitchCore

extension NSPasteboard.PasteboardType {
    static let annotations = NSPasteboard.PasteboardType("dev.yskitch.annotations")
}

extension Annotation {
    func withNewID() -> Annotation {
        var copy = self
        copy.id = UUID()
        copy.extendsCanvas = true
        return copy
    }
}

@MainActor
final class DocumentWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    static let chromeSize = CGSize(width: ToolbarView.width, height: StatusBarView.height)
    static let minimumCanvasWidth: CGFloat = 200

    static func minimumContentSize(statusBar: StatusBarView) -> CGSize {
        CGSize(
            width: max(ToolbarView.width + minimumCanvasWidth, statusBar.minimumWidth),
            height: ToolbarView.minimumHeight + StatusBarView.height)
    }

    private(set) var defaultFileName: String
    let model: DocumentModel
    let toolbar: ToolbarModel
    let selection: SelectionModel
    let scrollView: CanvasScrollView
    let canvasView: CanvasView
    let statusBar = StatusBarView()
    private(set) var savedURL: URL?

    convenience init(document: Document, title: String, toolSettings: ToolSettings) {
        self.init(model: DocumentModel(document: document), title: title, savedURL: nil, toolSettings: toolSettings)
    }

    init(model: DocumentModel, title: String, savedURL: URL?, toolSettings: ToolSettings) {
        defaultFileName = title
        self.savedURL = savedURL
        self.model = model
        toolbar = ToolbarModel(settings: toolSettings)
        selection = SelectionModel(model: model)
        toolbar.selection = selection
        canvasView = CanvasView(model: model, toolbar: toolbar, selection: selection)

        let visible = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1440, height: 900)
        let minimumSize = Self.minimumContentSize(statusBar: statusBar)
        let contentSize = WindowSizing.contentSize(
            documentSize: model.document.canvasRect.size, chrome: Self.chromeSize, visibleFrame: visible,
            minimum: minimumSize)
        scrollView = CanvasScrollView(frame: NSRect(origin: .zero, size: contentSize))
        scrollView.documentView = canvasView

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentMinSize = minimumSize
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
            updateStatusInfo()
        }
        selection.onChange = { [weak self] in
            self?.canvasView.needsDisplay = true
            self?.updateStatusInfo()
        }
        toolbar.onThicknessDragChange = { [weak self] in self?.updateStatusInfo() }
        canvasView.onStatusChange = { [weak self] in self?.updateStatusInfo() }
        statusBar.onActualSize = { [weak scrollView] in scrollView?.zoomToActualSize() }
        statusBar.onFit = { [weak scrollView] in scrollView?.zoomToFit() }
        statusBar.onZoomOut = { [weak scrollView] in scrollView?.zoomOut() }
        statusBar.onZoomIn = { [weak scrollView] in scrollView?.zoomIn() }
        scrollView.onMagnificationChange = { [weak statusBar] in statusBar?.update(magnification: $0) }
        statusBar.dragHandle.imageProvider = { [weak self] in self?.dragPayload() }
        canvasView.onCropSessionChange = { [weak statusBar] in statusBar?.dragHandle.isEnabled = !$0 }
        updateStatusInfo()
        window.contentView?.layoutSubtreeIfNeeded()
        scrollView.zoomToFit()
        statusBar.update(magnification: scrollView.magnification)
    }

    /// Slider value while dragging, else geometry of the element being drawn or selected, else the image size.
    private func updateStatusInfo() {
        let document = model.document
        if toolbar.isDraggingThickness,
            let text = StatusText.thickness(tool: toolbar.styleTool, value: toolbar.displayedStyle.thickness)
        {
            statusBar.update(info: text)
            return
        }
        statusBar.update(info: canvasView.statusGeometry.map {
            StatusText.geometry($0, canvasOrigin: document.canvasRect.origin, scale: document.scale)
        } ?? StatusText.size(canvas: document.canvasRect.size, scale: document.scale))
    }

    /// Nil during a crop session: the document is uncropped until the session ends.
    private func dragPayload() -> DragHandleView.Payload? {
        guard !canvasView.isCropping else { return nil }
        let document = model.document
        let flattened = Renderer.flatten(document)
        let bitmap = NSBitmapImageRep(cgImage: flattened)
        bitmap.size = document.canvasRect.size
        let thumbnail = NSImage(size: document.canvasRect.size)
        thumbnail.addRepresentation(bitmap)
        return (ImageExporter.pngData(flattened, scale: document.scale), defaultFileName, thumbnail)
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
        pasteboard.setData(ImageExporter.pngData(flattened, scale: document.scale), forType: .png)
        if let tiff = bitmap.tiffRepresentation { pasteboard.setData(tiff, forType: .tiff) }
    }

    @objc func copyImage(_ sender: Any?) { copyImage(to: .general) }

    func copy(to pasteboard: NSPasteboard) {
        let selected = selection.selectedAnnotations
        let ids = Set(selected.map(\.id))
        let ordered = model.document.annotations.filter { ids.contains($0.id) }
        guard !ordered.isEmpty, let data = try? JSONEncoder().encode(ordered) else {
            return copyImage(to: pasteboard)
        }
        pasteboard.clearContents()
        pasteboard.setData(data, forType: .annotations)
    }

    @objc func copy(_ sender: Any?) { copy(to: .general) }

    func cut(to pasteboard: NSPasteboard) {
        guard !selection.isEmpty else { return }
        copy(to: pasteboard)
        selection.deleteSelected(actionName: "Cut")
    }

    @objc func cut(_ sender: Any?) { cut(to: .general) }

    @objc func duplicate(_ sender: Any?) {
        let copies = selection.selectedAnnotations.map { $0.translated(by: Self.pasteOffset).withNewID() }
        insert(copies, actionName: "Duplicate")
    }

    private static let pasteOffset = CGVector(dx: 10, dy: 10)

    private func insert(_ annotations: [Annotation], actionName: String) {
        guard !annotations.isEmpty else { return }
        model.perform(actionName) { $0.annotations.append(contentsOf: annotations) }
        toolbar.activeTool = .select
        selection.select(annotations.map(\.id))
    }

    private func pasteAnnotations(_ data: Data) -> Bool {
        guard var pasted = try? JSONDecoder().decode([Annotation].self, from: data), !pasted.isEmpty else {
            return false
        }
        pasted = pasted.map { $0.withNewID() }
        let existing = model.document.annotations.map(\.shape)
        while pasted.contains(where: { existing.contains($0.shape) }) {
            pasted = pasted.map { $0.translated(by: Self.pasteOffset) }
        }
        insert(pasted, actionName: "Paste")
        return true
    }

    @discardableResult
    func paste(from pasteboard: NSPasteboard) -> Bool {
        guard !model.isInGesture else { return false }
        if let data = pasteboard.data(forType: .annotations), pasteAnnotations(data) { return true }
        guard let pasted = PasteboardImageReader.read(from: pasteboard) else { return false }
        let undoManager = model.undoManager
        undoManager.beginUndoGrouping()
        model.perform("Paste Image") { $0 = Document(image: pasted.image) }
        setIdentity(
            fileName: DocumentNaming.title(sourceURL: pasted.sourceURL, date: .now), savedURL: nil,
            actionName: "Paste Image")
        undoManager.setActionName("Paste Image")
        undoManager.endUndoGrouping()
        scrollView.zoomToFit()
        return true
    }

    /// Sets title, default file name and saved URL, registering the inverse so undo and redo keep them with the document.
    private func setIdentity(fileName: String, savedURL: URL?, actionName: String) {
        let previousName = defaultFileName
        let previousURL = self.savedURL
        model.undoManager.registerUndo(withTarget: self) {
            $0.setIdentity(fileName: previousName, savedURL: previousURL, actionName: actionName)
        }
        model.undoManager.setActionName(actionName)
        defaultFileName = fileName
        window?.title = fileName
        self.savedURL = savedURL
    }

    @objc func paste(_ sender: Any?) {
        if !paste(from: .general), !model.isInGesture { NSSound.beep() }
    }

    @objc func delete(_ sender: Any?) { selection.deleteSelected() }

    @objc func nudge(_ sender: NSMenuItem) {
        guard let delta = sender.representedObject as? CGVector else { return }
        selection.nudge(by: delta)
    }

    /// Switches to the Select tool so the selection stays visible and editable.
    override func selectAll(_ sender: Any?) {
        toolbar.activeTool = .select
        selection.selectAll()
    }

    /// The action comes from the item's key equivalent; the Tools menu builds items from `ToolShortcut`.
    @objc func performToolShortcut(_ sender: NSMenuItem) {
        guard let action = ToolShortcut.action(for: sender.keyEquivalent) else { return }
        toolbar.perform(action)
    }

    @objc func applyCrop(_ sender: Any?) { canvasView.applyCrop() }

    @objc func cancelCrop(_ sender: Any?) { canvasView.cancelCrop() }

    /// Actions that read or replace the document; it is uncropped while a crop session is open.
    private static let blockedWhileCropping: Set<Selector> = [
        #selector(paste(_:)), #selector(cut(_:)), #selector(copy(_:)), #selector(copyImage(_:)),
        #selector(duplicate(_:)), #selector(delete(_:)), #selector(selectAll(_:)),
        #selector(saveDocument(_:)), #selector(saveDocumentAs(_:)),
    ]

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if canvasView.isCropping, let action = item.action, Self.blockedWhileCropping.contains(action) {
            return false
        }
        return switch item.action {
        case #selector(performToolShortcut(_:)):
            validateToolShortcut(item)
        case #selector(applyCrop(_:)), #selector(cancelCrop(_:)):
            canvasView.isCropping
        case #selector(paste(_:)):
            !model.isInGesture && (NSPasteboard.general.availableType(from: [.annotations]) != nil
                || PasteboardImageReader.containsImage(.general))
        case #selector(cut(_:)), #selector(duplicate(_:)), #selector(delete(_:)):
            !selection.isEmpty && !model.isInGesture
        case #selector(nudge(_:)):
            !selection.isEmpty && !model.isInGesture && !canvasView.textEditor.isEditing
        case #selector(selectAll(_:)): !model.document.annotations.isEmpty && !model.isInGesture
        default: true
        }
    }

    private func validateToolShortcut(_ item: NSMenuItem) -> Bool {
        guard let action = ToolShortcut.action(for: item.keyEquivalent) else { return false }
        item.state = toolbar.isCurrent(action) ? .on : .off
        return toolbar.canPerform(action)
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
        panel.directoryURL = preferences.lastSaveFolder
            ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                guard let self else { return }
                do {
                    try self.write(to: url)
                    self.savedURL = url
                    self.preferences.lastSaveFolder = url.deletingLastPathComponent()
                } catch {
                    self.present(error)
                }
            }
        }
    }

    private var preferences: Preferences { toolbar.settings.preferences }

    private func present(_ error: Error) {
        guard let window else { return }
        NSAlert(error: error).beginSheetModal(for: window)
    }
}
