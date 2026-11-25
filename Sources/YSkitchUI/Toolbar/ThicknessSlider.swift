import AppKit
import SwiftUI
import YSkitchCore

/// Vertical; the top is the maximum.
struct ThicknessSlider: NSViewRepresentable {
    let tool: Tool
    let style: ToolStyle
    let range: ClosedRange<CGFloat>
    var onDragBegin: () -> Void = {}
    var onDragEnd: () -> Void = {}
    /// Receives the slider position (0 = minimum, 1 = maximum).
    let onChange: (Double) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider()
        let cell = WedgeSliderCell()
        cell.onTrackingBegin = { [weak coordinator = context.coordinator] in coordinator?.onDragBegin() }
        cell.onTrackingEnd = { [weak coordinator = context.coordinator] in coordinator?.onDragEnd() }
        slider.cell = cell
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
        CGSize(width: proposal.width ?? ToolbarView.colorColumnWidth, height: proposal.height ?? ToolbarView.rowHeight)
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.range = range
        context.coordinator.onChange = onChange
        context.coordinator.onDragBegin = onDragBegin
        context.coordinator.onDragEnd = onDragEnd
        slider.isEnabled = context.environment.isEnabled
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
        var onChange: (Double) -> Void = { _ in }
        var onDragBegin: () -> Void = {}
        var onDragEnd: () -> Void = {}

        @objc func changed(_ sender: NSSlider) {
            onChange(1 - sender.doubleValue)
        }
    }
}

/// Draws the track as a true size scale with a real-size sample of the current value.
/// `doubleValue` is only state; the geometry maps positions to y.
final class WedgeSliderCell: NSSliderCell {
    var tool: Tool = .arrow
    var color: RGBAColor = Palette.defaultColor
    var range: ClosedRange<CGFloat> = Tool.strokeRange
    var onTrackingBegin: (() -> Void)?
    var onTrackingEnd: (() -> Void)?
    private var dragOffset: CGFloat = 0

    /// 0 = minimum (bottom), 1 = maximum (top).
    var position: Double { 1 - normalizedValue }

    var thickness: CGFloat { ThicknessScale.value(at: position, in: range) }

    private var normalizedValue: Double {
        guard maxValue > minValue else { return 0 }
        return min(max((doubleValue - minValue) / (maxValue - minValue), 0), 1)
    }

    private var bounds: NSRect { controlView?.bounds ?? .zero }

    /// In top-down coordinates.
    private var geometry: ThicknessSliderGeometry {
        ThicknessSliderGeometry(track: NSRect(origin: .zero, size: bounds.size), range: range)
    }

    private var sampleRect: NSRect { geometry.sampleRect(value: thickness, at: position) }

    private func fromTop(_ rect: NSRect, flipped: Bool) -> NSRect {
        flipped ? rect : NSRect(x: rect.minX, y: bounds.height - rect.maxY, width: rect.width, height: rect.height)
    }

    override func knobRect(flipped: Bool) -> NSRect {
        fromTop(sampleRect.intersection(geometry.track), flipped: flipped)
    }

    override func barRect(flipped: Bool) -> NSRect { bounds }

    override func drawBar(inside rect: NSRect, flipped: Bool) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        if !flipped {
            let transform = NSAffineTransform()
            transform.translateX(by: 0, yBy: bounds.height)
            transform.scaleX(by: 1, yBy: -1)
            transform.concat()
        }
        let geometry = geometry
        let wedge = NSBezierPath(cgPath: geometry.wedge())
        NSColor.tertiaryLabelColor.setFill()
        wedge.fill()

        let y = geometry.y(at: position)
        drawIndicator(at: y, in: geometry.track)

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: geometry.track).addClip()
        drawSample(in: sampleRect, lineY: y)
        NSGraphicsContext.restoreGraphicsState()

        NSColor.secondaryLabelColor.setStroke()
        wedge.lineWidth = 1
        wedge.stroke()
    }

    /// Everything is drawn in `drawBar` to keep the layer order.
    override func drawKnob(_ knobRect: NSRect) {}

    private func drawIndicator(at y: CGFloat, in track: NSRect) {
        let width = ToolIcon.stroke
        let line = NSBezierPath()
        line.move(to: NSPoint(x: track.minX + width / 2, y: y))
        line.line(to: NSPoint(x: track.maxX - width / 2, y: y))
        line.lineCapStyle = .round
        NSColor.white.setStroke()
        line.lineWidth = width + 2
        line.stroke()
        NSColor.labelColor.setStroke()
        line.lineWidth = width
        line.stroke()
    }

    private func drawSample(in rect: NSRect, lineY: CGFloat) {
        let ring = min(2, rect.width / 6)
        let radius: CGFloat = tool == .text ? min(4, rect.width / 4) : 0
        func shape(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
            switch tool {
            case .text, .pixelate: NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            default: NSBezierPath(ovalIn: rect)
            }
        }
        let outer = shape(rect, radius: radius)
        NSColor.white.setFill()
        outer.fill()

        let fill = NSColor(cgColor: color.cgColor) ?? .black
        switch tool {
        case .pixelate: NSColor.labelColor.setFill()
        case .highlighter: fill.withAlphaComponent(HighlighterStyle.opacity).setFill()
        default: fill.setFill()
        }
        shape(rect.insetBy(dx: ring, dy: ring), radius: max(radius - ring / 2, 0)).fill()
        if tool == .text { drawLetter(in: rect, lineY: lineY) }

        NSColor.black.withAlphaComponent(0.35).setStroke()
        outer.lineWidth = 0.5
        outer.stroke()
    }

    /// The glyph's ink is centered on the track and on the indicator line.
    private func drawLetter(in rect: NSRect, lineY: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let font = TextStyle.font(size: rect.height * 0.8)
        let luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: luminance > 0.6 ? NSColor.black : NSColor.white,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: "a", attributes: attributes))
        let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: rect.midX - ink.midX, y: lineY + ink.midY)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    override func startTracking(at startPoint: NSPoint, in controlView: NSView) -> Bool {
        let y = topDownY(startPoint, in: controlView)
        dragOffset = knobRect(flipped: controlView.isFlipped).contains(startPoint) ? y - geometry.y(at: position) : 0
        onTrackingBegin?()
        track(to: startPoint, in: controlView)
        return true
    }

    override func stopTracking(last lastPoint: NSPoint, current stopPoint: NSPoint, in controlView: NSView, mouseIsUp flag: Bool) {
        super.stopTracking(last: lastPoint, current: stopPoint, in: controlView, mouseIsUp: flag)
        onTrackingEnd?()
    }

    override func continueTracking(last lastPoint: NSPoint, current currentPoint: NSPoint, in controlView: NSView) -> Bool {
        track(to: currentPoint, in: controlView)
        return true
    }

    private func topDownY(_ point: NSPoint, in controlView: NSView) -> CGFloat {
        controlView.isFlipped ? point.y : bounds.height - point.y
    }

    private func track(to point: NSPoint, in controlView: NSView) {
        let position = geometry.position(atY: topDownY(point, in: controlView) - dragOffset)
        doubleValue = minValue + (maxValue - minValue) * (1 - position)
        controlView.needsDisplay = true
    }
}
