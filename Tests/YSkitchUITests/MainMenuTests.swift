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
        #expect(titles == ["ySkitch", "File", "Edit", "View", "Window", "Help"])
    }

    @Test func shortcuts() throws {
        let cases: [(String, String, String, NSEvent.ModifierFlags, Selector)] = [
            ("File", "New", "n", .command, #selector(AppDelegate.newDocument(_:))),
            ("File", "Close", "w", .command, #selector(NSWindow.performClose(_:))),
            ("ySkitch", "Quit ySkitch", "q", .command, #selector(NSApplication.terminate(_:))),
            ("Edit", "Undo", "z", .command, Selector(("undo:"))),
            ("Edit", "Redo", "z", [.command, .shift], Selector(("redo:"))),
            ("Edit", "Copy", "c", .command, #selector(NSText.copy(_:))),
            ("Edit", "Paste", "v", .command, #selector(NSText.paste(_:))),
            ("Window", "Minimize", "m", .command, #selector(NSWindow.performMiniaturize(_:))),
        ]
        for (menu, title, key, modifiers, action) in cases {
            let item = try menuItem(menu, title)
            #expect(item.keyEquivalent == key, "\(title) key")
            #expect(item.keyEquivalentModifierMask == modifiers, "\(title) modifiers")
            #expect(item.action == action, "\(title) action")
            #expect(item.target == nil, "\(title) target")
        }
    }
}
