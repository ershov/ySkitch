import AppKit
import Testing
@testable import YSkitchUI

@MainActor
struct MainMenuTests {
    private func menuItem(_ menu: String, _ title: String) throws -> NSMenuItem {
        let main = MainMenu.build()
        let submenu = try #require(main.items.first { $0.submenu?.title == menu }?.submenu)
        return try #require(submenu.items.first { $0.title == title })
    }

    @Test func topLevelTitles() {
        let titles = MainMenu.build().items.compactMap { $0.submenu?.title }
        #expect(titles == ["ySkitch", "File", "Edit", "Tools", "View", "Window", "Help"])
    }

    @Test func shortcuts() throws {
        let cases: [(String, String, String, NSEvent.ModifierFlags, Selector)] = [
            ("File", "New", "n", .command, #selector(AppDelegate.newDocument(_:))),
            ("File", "New Blank", "n", [.command, .shift], #selector(AppDelegate.newBlankDocument(_:))),
            ("File", "Open…", "o", .command, #selector(AppDelegate.openDocument(_:))),
            ("File", "Reopen Closed Window", "t", [.command, .shift], #selector(AppDelegate.reopenClosedWindow(_:))),
            ("File", "Save", "s", .command, #selector(DocumentWindowController.saveDocument(_:))),
            ("File", "Save As…", "s", [.command, .shift], #selector(DocumentWindowController.saveDocumentAs(_:))),
            ("Edit", "Copy Image", "c", [.command, .shift], #selector(DocumentWindowController.copyImage(_:))),
            ("File", "Close", "w", .command, #selector(NSWindow.performClose(_:))),
            ("ySkitch", "Quit ySkitch", "q", .command, #selector(NSApplication.terminate(_:))),
            ("Edit", "Undo", "z", .command, #selector(UndoActions.undo(_:))),
            ("Edit", "Redo", "z", [.command, .shift], #selector(UndoActions.redo(_:))),
            ("Edit", "Copy", "c", .command, #selector(NSText.copy(_:))),
            ("Edit", "Paste", "v", .command, #selector(NSText.paste(_:))),
            ("Edit", "Cut", "x", .command, #selector(DocumentWindowController.cut(_:))),
            ("Edit", "Duplicate", "d", .command, #selector(DocumentWindowController.duplicate(_:))),
            ("Edit", "Delete", "", [], #selector(NSText.delete(_:))),
            ("Edit", "Select All", "a", .command, #selector(NSText.selectAll(_:))),
            ("View", "Enter Full Screen", "f", [.command, .control], #selector(NSWindow.toggleFullScreen(_:))),
            ("Window", "Zoom", "", [], #selector(NSWindow.performZoom(_:))),
            ("Window", "Bring All to Front", "", [], #selector(NSApplication.arrangeInFront(_:))),
            ("Window", "Minimize", "m", .command, #selector(NSWindow.performMiniaturize(_:))),
            ("View", "Zoom In", "+", .command, #selector(DocumentWindowController.zoomIn(_:))),
            ("View", "Zoom Out", "-", .command, #selector(DocumentWindowController.zoomOut(_:))),
            ("View", "Actual Size", "0", .command, #selector(DocumentWindowController.zoomToActualSize(_:))),
            ("View", "Zoom to Fit", "9", .command, #selector(DocumentWindowController.zoomToFit(_:))),
        ]
        for (menu, title, key, modifiers, action) in cases {
            let item = try menuItem(menu, title)
            #expect(item.keyEquivalent == key, "\(title) key")
            if !key.isEmpty { #expect(item.keyEquivalentModifierMask == modifiers, "\(title) modifiers") }
            #expect(item.action == action, "\(title) action")
            #expect(item.target == nil, "\(title) target")
        }
    }

    @Test func zoomInWithoutShift() throws {
        let view = try #require(MainMenu.build().items.first { $0.submenu?.title == "View" }?.submenu)
        let item = try #require(view.items.first { $0.keyEquivalent == "=" })
        #expect(item.action == #selector(DocumentWindowController.zoomIn(_:)))
        #expect(item.keyEquivalentModifierMask == .command)
        #expect(item.isHidden)
        #expect(item.allowsKeyEquivalentWhenHidden)
    }

    @Test func viewMenuOrder() throws {
        let view = try #require(MainMenu.build().items.first { $0.submenu?.title == "View" }?.submenu)
        let visible = view.items.filter { !$0.isHidden }.map { $0.isSeparatorItem ? "-" : $0.title }
        #expect(visible == ["Zoom In", "Zoom Out", "Actual Size", "Zoom to Fit", "-", "Enter Full Screen"])
    }
}
