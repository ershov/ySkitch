import AppKit
import SwiftUI
import YSkitchCore

/// Vertical; the top is the minimum so it lines up with the `[` (thinner) label.
struct ThicknessSlider: NSViewRepresentable {
    let tool: Tool
    let style: ToolStyle
    let range: ClosedRange<CGFloat>
    let onChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider()
        slider.cell = WedgeSliderCell()
        slider.minValue = 0
        slider.maxValue = 1
        slider.isVertical = true
        slider.isContinuous = true
        slider.refusesFirstResponder = true
        slider.target = context.coordinator
        slider.action = #selector(Coordinator.changed(_:))
        return slider
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSlider, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? ToolbarView.swatchSize, height: proposal.height ?? ToolbarView.rowHeight)
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.range = range
        context.coordinator.onChange = onChange
        if let cell = slider.cell as? WedgeSliderCell {
            cell.tool = tool
            cell.color = style.color
            cell.range = range
        }
        // Leave the knob where the user dragged it when it already maps to the current value.
        if ThicknessScale.value(at: 1 - slider.doubleValue, in: range) != style.thickness {
            slider.doubleValue = 1 - ThicknessScale.position(of: style.thickness, in: range)
        }
        slider.needsDisplay = true
    }

    @MainActor
    final class Coordinator: NSObject {
        var range: ClosedRange<CGFloat> = Tool.strokeRange
        var onChange: (CGFloat) -> Void = { _ in }

        @objc func changed(_ sender: NSSlider) {
            onChange(ThicknessScale.value(at: 1 - sender.doubleValue, in: range))
        }
    }
}

/// Draws the track as a wedge (thin at the top, thick at the bottom) and the knob as a size preview.
/// `doubleValue` 1 is the top (minimum thickness).
final class WedgeSliderCell: NSSliderCell {
    static let minKnob: CGFloat = 8
    static let minLabelKnob: CGFloat = 14
    static let wedgeTop: CGFloat = 2
    static let wedgeBottom: CGFloat = 12

    var tool: Tool = .arrow
    var color: RGBAColor = Palette.defaultColor
    var range: ClosedRange<CGFloat> = Tool.strokeRange
    private var dragOffset: CGFloat = 0

    /// 0 at the top (minimum), 1 at the bottom (maximum).
    var position: Double { 1 - normalizedValue }

    var thickness: CGFloat { ThicknessScale.value(at: position, in: range) }

    private var normalizedValue: Double {
        guard maxValue > minValue else { return 0 }
        return min(max((doubleValue - minValue) / (maxValue - minValue), 0), 1)
    }

    private var bounds: NSRect { controlView?.bounds ?? .zero }

    private var maxKnob: CGFloat { max(bounds.width, Self.minKnob) }

    func knobSide(at position: Double) -> CGFloat {
        switch tool {
        case .text, .pixelate:
            return Self.minLabelKnob + (maxKnob - Self.minLabelKnob) * CGFloat(position)
        default:
            return min(max(ThicknessScale.value(at: position, in: range), Self.minKnob), maxKnob)
        }
    }

    /// Knob centers at the ends of travel, measured from the top; the same for every tool.
    private var travel: (top: CGFloat, bottom: CGFloat) {
        let top = Self.minLabelKnob / 2
        return (top, max(bounds.height - maxKnob / 2, top))
    }

    private func centerY(flipped: Bool) -> CGFloat {
        let (top, bottom) = travel
        let y = top + (bottom - top) * CGFloat(position)
        return flipped ? y : bounds.height - y
    }

    override func knobRect(flipped: Bool) -> NSRect {
        let side = knobSide(at: position)
        return NSRect(x: bounds.midX - side / 2, y: centerY(flipped: flipped) - side / 2, width: side, height: side)
    }

    override func barRect(flipped: Bool) -> NSRect {
        let (top, bottom) = travel
        let y = flipped ? top : bounds.height - bottom
        return NSRect(x: bounds.midX - Self.wedgeBottom / 2, y: y, width: Self.wedgeBottom, height: bottom - top)
    }

    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let bar = barRect(flipped: flipped)
        let thin = Self.wedgeTop / 2, thick = Self.wedgeBottom / 2
        let topCenter = NSPoint(x: bar.midX, y: flipped ? bar.minY : bar.maxY)
        let bottomCenter = NSPoint(x: bar.midX, y: flipped ? bar.maxY : bar.minY)
        let length = abs(bottomCenter.y - topCenter.y)
        guard length > thick - thin else { return }
        // Hull of the two end circles: tangent lines joined by arcs around the far sides.
        let s: CGFloat = bottomCenter.y > topCenter.y ? 1 : -1
        let alpha = asin((thick - thin) / length) * 180 / .pi
        let right = -s * alpha, left = 180 + s * alpha
        let path = NSBezierPath()
        path.appendArc(withCenter: bottomCenter, radius: thick, startAngle: right, endAngle: left, clockwise: s < 0)
        path.appendArc(withCenter: topCenter, radius: thin, startAngle: left, endAngle: right, clockwise: s < 0)
        path.close()
        NSColor.tertiaryLabelColor.setFill()
        path.fill()
    }

    override func drawKnob(_ knobRect: NSRect) {
        let rect = knobRect.insetBy(dx: 0.5, dy: 0.5)
        let ring = min(2, rect.width / 6)
        let outer: NSBezierPath
        let inner: NSBezierPath
        switch tool {
        case .text, .pixelate:
            outer = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
            inner = NSBezierPath(roundedRect: rect.insetBy(dx: ring, dy: ring), xRadius: 3, yRadius: 3)
        default:
            outer = NSBezierPath(ovalIn: rect)
            inner = NSBezierPath(ovalIn: rect.insetBy(dx: ring, dy: ring))
        }
        NSColor.white.setFill()
        outer.fill()

        let fill = NSColor(cgColor: color.cgColor) ?? .black
        switch tool {
        case .pixelate:
            drawMosaic(in: inner)
        case .highlighter:
            fill.withAlphaComponent(HighlighterStyle.opacity).setFill()
            inner.fill()
        default:
            fill.setFill()
            inner.fill()
        }
        if tool == .text { drawLabel(in: rect) }

        NSColor.black.withAlphaComponent(0.35).setStroke()
        outer.lineWidth = 0.5
        outer.stroke()
    }

    private func drawMosaic(in path: NSBezierPath) {
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        let shades: [CGFloat] = [0.55, 0.75, 0.65, 0.85]
        let box = path.bounds
        let block = box.width / 3
        for row in 0..<3 {
            for column in 0..<3 {
                NSColor(white: shades[(row * 3 + column * 2 + row * column) % shades.count], alpha: 1).setFill()
                NSRect(x: box.minX + CGFloat(column) * block, y: box.minY + CGFloat(row) * block,
                       width: block, height: block).fill()
            }
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawLabel(in rect: NSRect) {
        let luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: rect.height * 0.45, weight: .bold),
            .foregroundColor: luminance > 0.6 ? NSColor.black : NSColor.white,
        ]
        let text = NSAttributedString(string: "Aa", attributes: attributes)
        let size = text.size()
        text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
    }

    override func startTracking(at startPoint: NSPoint, in controlView: NSView) -> Bool {
        let knob = knobRect(flipped: controlView.isFlipped)
        dragOffset = knob.contains(startPoint) ? startPoint.y - knob.midY : 0
        track(to: startPoint, in: controlView)
        return true
    }

    override func continueTracking(last lastPoint: NSPoint, current currentPoint: NSPoint, in controlView: NSView) -> Bool {
        track(to: currentPoint, in: controlView)
        return true
    }

    private func track(to point: NSPoint, in controlView: NSView) {
        let y = point.y - dragOffset
        let fromTop = controlView.isFlipped ? y : bounds.height - y
        let (top, bottom) = travel
        let position = bottom > top ? min(max((fromTop - top) / (bottom - top), 0), 1) : 0
        doubleValue = minValue + (maxValue - minValue) * (1 - Double(position))
        controlView.needsDisplay = true
    }
}
