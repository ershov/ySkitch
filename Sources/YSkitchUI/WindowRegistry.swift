import AppKit
import YSkitchCore

@MainActor
final class WindowRegistry {
    static let shared = WindowRegistry(toolSettings: .shared)

    let toolSettings: ToolSettings
    let closedWindows = ClosedWindowHistory()
    private(set) var controllers: [DocumentWindowController] = []
    private var cascadePoint = NSPoint.zero
    private var closeObservers: [ObjectIdentifier: any NSObjectProtocol] = [:]

    init(toolSettings: ToolSettings) {
        self.toolSettings = toolSettings
    }

    @discardableResult
    func openFromPasteboard(_ pasteboard: NSPasteboard) -> DocumentWindowController {
        if let pasted = PasteboardImageReader.read(from: pasteboard) {
            return show(
                Document(image: pasted.image),
                title: DocumentNaming.title(sourceURL: pasted.sourceURL, date: .now))
        }
        return show(Self.blankDocument(), title: DocumentNaming.title(sourceURL: nil, date: .now))
    }

    @discardableResult
    func openBlank() -> DocumentWindowController {
        show(Self.blankDocument(), title: DocumentNaming.title(sourceURL: nil, date: .now))
    }

    @discardableResult
    func open(url: URL) throws -> DocumentWindowController {
        let image = try ImageImporter.load(url: url)
        return show(Document(image: image), title: DocumentNaming.title(sourceURL: url, date: .now))
    }

    /// One window per loadable item, in order. A clipboard without an image opens nothing and is not a problem.
    func open(_ items: [LaunchItem], pasteboard: NSPasteboard) -> (opened: Int, problems: [OpenProblem]) {
        var opened = 0
        var problems: [OpenProblem] = []
        for item in items {
            switch item {
            case .clipboard:
                guard let pasted = PasteboardImageReader.read(from: pasteboard) else { continue }
                show(Document(image: pasted.image), title: DocumentNaming.title(sourceURL: pasted.sourceURL, date: .now))
                opened += 1
            case .stdin:
                continue
            case .file(let path):
                switch ImageFileLoader.load(path: path) {
                case .success(let image):
                    show(Document(image: image), title: DocumentNaming.title(sourceURL: URL(filePath: path), date: .now))
                    opened += 1
                case .failure(let reason):
                    problems.append(OpenProblem(source: .file(path), reason: reason))
                }
            case .stdinFile(let path):
                defer { try? FileManager.default.removeItem(atPath: path) }
                switch ImageFileLoader.load(path: path) {
                case .success(let image):
                    show(Document(image: image), title: DocumentNaming.title(sourceURL: nil, date: .now))
                    opened += 1
                case .failure(let reason):
                    problems.append(OpenProblem(source: .standardInput, reason: reason == .notFound ? .empty : reason))
                }
            }
        }
        return (opened, problems)
    }

    @discardableResult
    func openDropped(_ pasteboard: NSPasteboard) -> Bool {
        let urls = PasteboardImageReader.imageFileURLs(in: pasteboard)
        if !urls.isEmpty {
            return urls.reduce(false) { opened, url in ((try? open(url: url)) != nil) || opened }
        }
        guard let pasted = PasteboardImageReader.read(from: pasteboard) else { return false }
        show(Document(image: pasted.image), title: DocumentNaming.title(sourceURL: pasted.sourceURL, date: .now))
        return true
    }

    static let blankSize = CGSize(width: 800, height: 600)

    private static func blankDocument() -> Document {
        Document(blankSize: blankSize, scale: NSScreen.main?.backingScaleFactor ?? 2)
    }

    @discardableResult
    func show(_ document: Document, title: String) -> DocumentWindowController {
        let controller = DocumentWindowController(document: document, title: title, toolSettings: toolSettings)
        guard let window = controller.window else { return controller }
        if controllers.isEmpty {
            window.center()
            cascadePoint = .zero
        }
        cascadePoint = window.cascadeTopLeft(from: cascadePoint)
        controller.scrollView.onDrop = { [weak self] in self?.openDropped($0) ?? false }
        register(controller, window: window)
        controller.showWindow(nil)
        // The window frame is constrained to the screen only when shown.
        window.contentView?.layoutSubtreeIfNeeded()
        controller.scrollView.zoomToFit()
        return controller
    }

    private func register(_ controller: DocumentWindowController, window: NSWindow) {
        controllers.append(controller)
        let id = ObjectIdentifier(controller)
        closeObservers[id] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self, weak controller] _ in
            MainActor.assumeIsolated {
                guard let self, let controller else { return }
                self.unregister(controller)
            }
        }
    }

    private func unregister(_ controller: DocumentWindowController) {
        let id = ObjectIdentifier(controller)
        if let observer = closeObservers.removeValue(forKey: id) {
            NotificationCenter.default.removeObserver(observer)
        }
        controllers.removeAll { $0 === controller }
        controller.canvasView.cancelActiveGesture()
        closedWindows.push(ClosedWindowHistory.Entry(controller))
    }

    @discardableResult
    func reopenLastClosed() -> DocumentWindowController? {
        guard let entry = closedWindows.popLast() else { return nil }
        let controller = DocumentWindowController(
            model: entry.model, title: entry.title, savedURL: entry.savedURL, toolSettings: toolSettings)
        guard let window = controller.window else { return controller }
        window.setFrame(entry.frame, display: false)
        window.contentView?.layoutSubtreeIfNeeded()
        let scrollView = controller.scrollView
        scrollView.magnification = entry.magnification
        scrollView.contentView.scroll(to: entry.scrollOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        if controller.toolbar.activeTool != entry.tool { controller.toolbar.activeTool = entry.tool }
        scrollView.onDrop = { [weak self] in self?.openDropped($0) ?? false }
        register(controller, window: window)
        controller.showWindow(nil)
        return controller
    }
}
