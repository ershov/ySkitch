import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct CanvasSurroundTests {
    private func surroundPixel(appearance: NSAppearance.Name) throws -> NSColor {
        let settings = ToolSettings(preferences: Preferences(store: InMemoryPreferencesStore()))
        let controller = DocumentWindowController(
            document: Document(blankSize: CGSize(width: 100, height: 100), scale: 1),
            title: "Test", toolSettings: settings)
        defer { controller.close() }
        let window = try #require(controller.window)
        window.appearance = NSAppearance(named: appearance)
        window.setContentSize(NSSize(width: 900, height: 560))
        window.contentView?.layoutSubtreeIfNeeded()
        // Caching the window content returns stale layer contents for the surround in light mode.
        let view = controller.scrollView
        let rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        return try #require(rep.colorAt(x: 2, y: 2)?.usingColorSpace(.sRGB))
    }

    @Test func surroundFollowsAppearance() throws {
        let light = try surroundPixel(appearance: .aqua)
        let dark = try surroundPixel(appearance: .darkAqua)
        #expect(light.brightnessComponent < 0.99)
        #expect(light.brightnessComponent > dark.brightnessComponent)
    }

    @Test func surroundUsesUnderPageBackground() {
        #expect(CanvasStyle.surroundColor == NSColor.underPageBackgroundColor)
    }
}
