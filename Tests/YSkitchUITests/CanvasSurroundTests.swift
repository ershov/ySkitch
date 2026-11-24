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
        let content = try #require(window.contentView)
        content.layoutSubtreeIfNeeded()
        let clip = try #require(controller.canvasView.superview as? CenteringClipView)
        let rep = try #require(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: rep)
        let corner = NSPoint(x: clip.frame.minX + 2, y: clip.frame.minY + 2)
        let origin = content.convert(corner, from: clip.superview)
        let y = Int(content.bounds.height - origin.y)
        return try #require(rep.colorAt(x: Int(origin.x), y: y)?.usingColorSpace(.sRGB))
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
