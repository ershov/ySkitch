import AppKit
import Testing
import YSkitchCore
@testable import YSkitchUI

@MainActor
struct CanvasEdgeTests {
    private static let deviceScale: CGFloat = 2

    private static func blackImage(width: Int, height: Int) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private struct Rendering {
        let rep: NSBitmapImageRep
        /// Canvas and clip view in rep pixels, origin top-left.
        let canvas: CGRect
        let clip: CGRect

        func brightness(x: Int, y: Int) -> CGFloat {
            rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB)?.brightnessComponent ?? 1
        }
    }

    /// `layerBacked` draws through the layer tree at `deviceScale`, as on screen; otherwise via `cacheDisplay`.
    private func render(
        _ document: Document = Document(image: BaseImage(cgImage: blackImage(width: 848, height: 168), scale: 2)),
        magnification: CGFloat, layerBacked: Bool
    ) throws -> Rendering {
        let controller = DocumentWindowController(document: document, title: "Test", toolSettings: .inMemory())
        defer { controller.close() }
        let window = try #require(controller.window)
        window.appearance = NSAppearance(named: .darkAqua)
        window.setContentSize(NSSize(width: 1600, height: 700))
        let content = try #require(window.contentView)
        content.wantsLayer = layerBacked
        content.layoutSubtreeIfNeeded()
        controller.scrollView.magnification = magnification
        let clipView = controller.scrollView.contentView
        clipView.scroll(to: clipView.constrainBoundsRect(clipView.bounds).origin)

        let rep: NSBitmapImageRep
        if layerBacked {
            window.displayIfNeeded()
            content.display()
            let layer = try #require(content.layer)
            let context = try #require(CGContext(
                data: nil, width: Int(content.bounds.width * Self.deviceScale),
                height: Int(content.bounds.height * Self.deviceScale), bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.scaleBy(x: Self.deviceScale, y: Self.deviceScale)
            layer.render(in: context)
            rep = NSBitmapImageRep(cgImage: try #require(context.makeImage()))
        } else {
            rep = try #require(content.bitmapImageRepForCachingDisplay(in: content.bounds))
            content.cacheDisplay(in: content.bounds, to: rep)
        }
        let scale = CGFloat(rep.pixelsWide) / content.bounds.width
        func pixels(_ rect: NSRect) -> CGRect {
            CGRect(
                x: rect.minX * scale, y: (content.bounds.height - rect.maxY) * scale,
                width: rect.width * scale, height: rect.height * scale)
        }
        return Rendering(
            rep: rep,
            canvas: pixels(content.convert(controller.canvasView.bounds, from: controller.canvasView)),
            clip: pixels(content.convert(clipView.bounds, from: clipView)))
    }

    @Test(arguments: [0.5, 0.73, 1.37, 2.03, 2.71, 3.17] as [CGFloat], [false, true])
    func trailingEdgesShowNoWhite(magnification: CGFloat, layerBacked: Bool) throws {
        try expectDarkTrailingEdges(render(magnification: magnification, layerBacked: layerBacked))
    }

    /// On a 2× screen the canvas shows the output's own pixels.
    @Test(arguments: [0.73, 1.37, 2.03, 3.17] as [CGFloat], [false, true])
    func trailingEdgesShowNoWhiteAtLowerOutputScale(magnification: CGFloat, layerBacked: Bool) throws {
        var document = Document(image: BaseImage(cgImage: Self.blackImage(width: 848, height: 168), scale: 2))
        document.setScale(1)
        try expectDarkTrailingEdges(render(document, magnification: magnification, layerBacked: layerBacked))
    }

    private func expectDarkTrailingEdges(_ rendering: Rendering) {
        let canvas = rendering.canvas
        #expect(rendering.clip.contains(canvas.insetBy(dx: -2, dy: -2)))
        let surround = rendering.brightness(x: Int(rendering.clip.minX) + 2, y: Int(rendering.clip.minY) + 2)
        #expect(surround > 0.03 && surround < 0.3)
        let limit = surround + 0.05
        let right = Int(canvas.maxX.rounded(.down)), bottom = Int(canvas.maxY.rounded(.down))
        for y in stride(from: Int(canvas.minY) + 2, to: bottom - 1, by: 7) {
            for x in (right - 1)...(right + 1) {
                #expect(rendering.brightness(x: x, y: y) <= limit, "x \(x), y \(y)")
            }
        }
        for x in stride(from: Int(canvas.minX) + 2, to: right - 1, by: 7) {
            for y in (bottom - 1)...(bottom + 1) {
                #expect(rendering.brightness(x: x, y: y) <= limit, "x \(x), y \(y)")
            }
        }
    }

    @Test(arguments: [0.73, 2.03] as [CGFloat], [false, true])
    func blankCanvasStaysWhiteUpToEdges(magnification: CGFloat, layerBacked: Bool) throws {
        let rendering = try render(
            Document(blankSize: CGSize(width: 424, height: 84), scale: 2),
            magnification: magnification, layerBacked: layerBacked)
        let canvas = rendering.canvas
        let right = Int(canvas.maxX.rounded(.down)) - 1, bottom = Int(canvas.maxY.rounded(.down)) - 1
        #expect(rendering.brightness(x: right, y: Int(canvas.midY)) > 0.99)
        #expect(rendering.brightness(x: Int(canvas.midX), y: bottom) > 0.99)
        #expect(rendering.brightness(x: Int(canvas.minX), y: Int(canvas.minY)) > 0.99)
    }
}
