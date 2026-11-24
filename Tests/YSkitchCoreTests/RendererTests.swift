import CoreGraphics
import Foundation
import Testing
@testable import YSkitchCore

struct Pixel: Equatable {
    var r, g, b, a: UInt8
}

func readPixels(_ image: CGImage) -> (pixel: (Int, Int) -> Pixel, width: Int, height: Int) {
    let w = image.width, h = image.height
    var data = [UInt8](repeating: 0, count: w * h * 4)
    data.withUnsafeMutableBytes { buf in
        let ctx = CGContext(
            data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return ({ x, y in
        let i = (y * w + x) * 4
        return Pixel(r: data[i], g: data[i + 1], b: data[i + 2], a: data[i + 3])
    }, w, h)
}

/// Pixels are row-major from the top, RGBA.
func makeImage(width: Int, height: Int, pixels: [Pixel]) -> CGImage {
    var data = pixels.flatMap { [$0.r, $0.g, $0.b, $0.a] }
    return data.withUnsafeMutableBytes { buf in
        let ctx = CGContext(
            data: buf.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return ctx.makeImage()!
    }
}

let red = Pixel(r: 255, g: 0, b: 0, a: 255)
let blue = Pixel(r: 0, g: 0, b: 255, a: 255)
let white = Pixel(r: 255, g: 255, b: 255, a: 255)

@Suite struct RendererTests {
    @Test func blankSize() {
        let image = Renderer.flatten(Document(blankSize: CGSize(width: 100, height: 50), scale: 2))
        #expect(image.width == 200)
        #expect(image.height == 100)
    }

    @Test func imageDocumentUsesPixelSize() {
        let cg = makeImage(width: 6, height: 4, pixels: Array(repeating: red, count: 24))
        let image = Renderer.flatten(Document(image: BaseImage(cgImage: cg, scale: 2)))
        #expect(image.width == 6)
        #expect(image.height == 4)
    }

    @Test func outputIsOpaque() {
        let image = Renderer.flatten(Document(blankSize: CGSize(width: 10, height: 10), scale: 1))
        #expect(image.alphaInfo == .noneSkipLast)
    }

    @Test func blankIsWhite() {
        let image = Renderer.flatten(Document(blankSize: CGSize(width: 8, height: 6), scale: 2))
        let p = readPixels(image)
        for y in 0..<p.height { for x in 0..<p.width { #expect(p.pixel(x, y) == white) } }
    }

    @Test func orientation() {
        let cg = makeImage(width: 2, height: 2, pixels: [red, white, white, blue])
        let image = Renderer.flatten(Document(image: BaseImage(cgImage: cg)))
        let p = readPixels(image)
        #expect(p.pixel(0, 0) == red)
        #expect(p.pixel(1, 1) == blue)
        #expect(p.pixel(1, 0) == white)
        #expect(p.pixel(0, 1) == white)
    }

    @Test func scaledBaseImage() {
        var pixels = [Pixel](repeating: white, count: 400)
        for y in 0..<10 { for x in 0..<10 { pixels[y * 20 + x] = red } }
        for y in 10..<20 { for x in 10..<20 { pixels[y * 20 + x] = blue } }
        let cg = makeImage(width: 20, height: 20, pixels: pixels)
        let document = Document(image: BaseImage(cgImage: cg, scale: 2))
        #expect(document.imageRect.size == CGSize(width: 10, height: 10))
        let image = Renderer.flatten(document)
        #expect(image.width == 20)
        #expect(image.height == 20)
        let p = readPixels(image)
        for (x, y) in [(0, 0), (9, 9), (15, 15), (19, 19), (15, 2), (2, 15)] {
            #expect(p.pixel(x, y) == pixels[y * 20 + x])
        }
    }

    @Test func rectangleAnnotation() {
        var document = Document(blankSize: CGSize(width: 100, height: 100), scale: 1)
        document.annotations = [
            Annotation(
                style: AnnotationStyle(color: RGBAColor(hex: 0xFF0000), thickness: 4),
                shape: .rectangle(CGRect(x: 20, y: 30, width: 50, height: 40))
            )
        ]
        let p = readPixels(Renderer.flatten(document))
        #expect(p.pixel(45, 30) == red)
        #expect(p.pixel(20, 50) == red)
        #expect(p.pixel(45, 50) == white)
        #expect(p.pixel(5, 5) == white)
    }

    @Test func onTopAnnotationDrawsLastWithoutReordering() {
        func stroke(_ hex: UInt32) -> Annotation {
            Annotation(
                style: AnnotationStyle(color: RGBAColor(hex: hex), thickness: 4),
                shape: .rectangle(CGRect(x: 20, y: 30, width: 50, height: 40)))
        }
        var document = Document(blankSize: CGSize(width: 100, height: 100), scale: 1)
        document.annotations = [stroke(0xFF0000), stroke(0x0000FF)]
        func topPixel(onTop: UUID?) -> Pixel {
            let context = CGContext(
                data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: 0, y: -100)
            Renderer.draw(document, onTop: onTop, in: context)
            return readPixels(context.makeImage()!).pixel(45, 30)
        }
        #expect(topPixel(onTop: nil) == blue)
        #expect(topPixel(onTop: document.annotations[0].id) == red)
        #expect(document.annotations[0].style.color == RGBAColor(hex: 0xFF0000))
    }
}
