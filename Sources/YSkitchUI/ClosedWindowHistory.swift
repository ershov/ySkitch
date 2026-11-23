import AppKit
import YSkitchCore

/// In-memory LIFO stack of closed windows; keeps each document model alive so its undo history survives.
@MainActor
final class ClosedWindowHistory {
    static let capacity = 20

    struct Entry {
        let model: DocumentModel
        let title: String
        let savedURL: URL?
        let frame: NSRect
        let magnification: CGFloat
        let scrollOrigin: NSPoint
        let tool: Tool

        @MainActor init(_ controller: DocumentWindowController) {
            model = controller.model
            title = controller.defaultFileName
            savedURL = controller.savedURL
            frame = controller.window?.frame ?? .zero
            magnification = controller.scrollView.magnification
            scrollOrigin = controller.scrollView.contentView.bounds.origin
            let toolbar = controller.toolbar
            // A cancelled crop session leaves the crop tool selected; restore the tool used before it.
            tool = toolbar.activeTool == .crop ? toolbar.previousTool : toolbar.activeTool
        }
    }

    private(set) var entries: [Entry] = []

    var isEmpty: Bool { entries.isEmpty }

    func push(_ entry: Entry) {
        entries.append(entry)
        if entries.count > Self.capacity { entries.removeFirst(entries.count - Self.capacity) }
    }

    func popLast() -> Entry? { entries.popLast() }
}
