// Renders the app icon iconset: swift scripts/make-icon.swift <output-dir>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let canvas: CGFloat = 1024
let shapeRect = CGRect(x: 100, y: 100, width: 824, height: 824)

func srgb(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let pink = srgb(0xFF2E6C)

/// Rounded rect with continuous (curvature-matched) corners: each corner is a superellipse quadrant.
func squircle(in rect: CGRect, radius: CGFloat = 185) -> CGPath {
    let extent = radius * 1.528
    let n: CGFloat = 3.3
    let centers = [
        CGPoint(x: rect.maxX - extent, y: rect.maxY - extent), CGPoint(x: rect.minX + extent, y: rect.maxY - extent),
        CGPoint(x: rect.minX + extent, y: rect.minY + extent), CGPoint(x: rect.maxX - extent, y: rect.minY + extent),
    ]
    let path = CGMutablePath()
    let steps = 90
    for (k, center) in centers.enumerated() {
        for i in 0...steps {
            let t = (CGFloat(k) + CGFloat(i) / CGFloat(steps)) * .pi / 2
            let c = cos(t), s = sin(t)
            let p = CGPoint(
                x: center.x + extent * copysign(pow(abs(c), 2 / n), c),
                y: center.y + extent * copysign(pow(abs(s), 2 / n), s))
            if k == 0 && i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
    }
    path.closeSubpath()
    return path
}

/// Same shape as the app's arrow (`ArrowGeometry.path`), with the point-based constants scaled by `unit`.
func arrowPath(tail: CGPoint, head: CGPoint, thickness: CGFloat, unit: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let dx = head.x - tail.x, dy = head.y - tail.y
    let length = hypot(dx, dy)
    guard length > 0 else { return path }
    let ux = dx / length, uy = dy / length
    let normal = CGPoint(x: -uy, y: ux)
    let thickness = min(thickness, length / 5)
    var headLength = 3.5 * thickness + 8 * unit
    var headWidth = 3 * thickness + 8 * unit
    let minimum = headLength * 1.2
    if length < minimum {
        headLength *= length / minimum
        headWidth *= length / minimum
    }
    func point(_ distance: CGFloat, _ offset: CGFloat) -> CGPoint {
        CGPoint(x: head.x - ux * distance + normal.x * offset, y: head.y - uy * distance + normal.y * offset)
    }
    let notch = headLength * 0.8
    path.addLines(between: [
        point(length, 0.2 * thickness), point(notch, thickness / 2), point(headLength, headWidth / 2),
        head,
        point(headLength, -headWidth / 2), point(notch, -thickness / 2), point(length, -0.2 * thickness),
    ])
    path.closeSubpath()
    return path
}

func drawBackground(_ context: CGContext, scale: CGFloat) {
    let shape = squircle(in: shapeRect)
    let small = scale * canvas <= 32

    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -max(10 * scale, 0.5)), blur: max(22 * scale, 1),
        color: CGColor(gray: 0, alpha: small ? 0.18 : 0.28))
    context.addPath(shape)
    context.setFillColor(srgb(0xF4F5F8))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [srgb(0xFFFFFF), srgb(0xE9EBF0)] as CFArray,
        locations: [0, 1])!
    context.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: shapeRect.maxY), end: CGPoint(x: 0, y: shapeRect.minY), options: [])
    context.restoreGState()

    // Hairline edge keeps the light shape distinct on light backgrounds.
    context.saveGState()
    context.addPath(shape)
    context.setStrokeColor(CGColor(gray: 0, alpha: small ? 0.05 : 0.10))
    context.setLineWidth(max(2, 1 / scale))
    context.strokePath()
    context.restoreGState()
}

func drawArrow(_ context: CGContext, scale: CGFloat, size: Int) {
    // Unit = icon pixels per app point; widths follow the app's proportions, boosted at small sizes.
    let unit: CGFloat = 7
    let boost: CGFloat = size <= 16 ? 1.45 : size <= 32 ? 1.25 : 1
    let thickness = 12 * unit * boost
    let tail = CGPoint(x: 238, y: 232)
    let head = CGPoint(x: 778, y: 772)
    let path = arrowPath(tail: tail, head: head, thickness: thickness, unit: unit)

    let white = max(0.25 * 12 * unit, 1.1 / scale)
    let haloBlur = max(2.6 * unit * scale, 1.2)

    context.saveGState()
    context.setShadow(offset: .zero, blur: haloBlur, color: CGColor(gray: 0, alpha: 0.5))
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.setStrokeColor(CGColor(gray: 1, alpha: 1))
    context.setLineWidth(2 * white)
    context.setLineJoin(.round)
    context.addPath(path)
    context.drawPath(using: .fillStroke)
    context.endTransparencyLayer()
    context.restoreGState()

    context.saveGState()
    context.addPath(path)
    context.clip()
    let box = path.boundingBoxOfPath
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [srgb(0xFF4A80), pink, srgb(0xF0215F)] as CFArray,
        locations: [0, 0.5, 1])!
    context.drawLinearGradient(
        gradient, start: CGPoint(x: box.minX, y: box.maxY), end: CGPoint(x: box.maxX, y: box.minY), options: [])
    context.restoreGState()
}

func render(size: Int) -> CGImage {
    let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(size) / canvas
    context.scaleBy(x: scale, y: scale)
    drawBackground(context, scale: scale)
    drawArrow(context, scale: scale, size: size)
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot write \(url.path)") }
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <output-dir>\n".data(using: .utf8)!)
    exit(1)
}
let iconset = URL(fileURLWithPath: arguments[1]).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    writePNG(render(size: base), to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    writePNG(render(size: base * 2), to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
print(iconset.path)
