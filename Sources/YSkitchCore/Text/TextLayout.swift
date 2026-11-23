import CoreGraphics
import CoreText
import Foundation

public enum TextLayout {
    /// Geometry relative to the text origin, y down. Lines break at any newline character, as in a text view.
    public static func layout(string: String, fontSize: CGFloat) -> (size: CGSize, path: CGPath) {
        let font = TextStyle.font(size: fontSize)
        let ascent = CTFontGetAscent(font)
        let lineHeight = TextStyle.lineHeight(font)
        let lines = string.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let path = CGMutablePath()
        var width: CGFloat = 0
        for (index, text) in lines.enumerated() where !text.isEmpty {
            let attributed = NSAttributedString(
                string: String(text), attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
            let line = CTLineCreateWithAttributedString(attributed)
            width = max(width, CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
            addGlyphs(of: line, baseline: CGFloat(index) * lineHeight + ascent, to: path)
        }
        return (CGSize(width: width, height: CGFloat(lines.count) * lineHeight), path)
    }

    private static func addGlyphs(of line: CTLine, baseline: CGFloat, to path: CGMutablePath) {
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }
            let attributes = CTRunGetAttributes(run) as NSDictionary
            guard let value = attributes[kCTFontAttributeName as String] else { continue }
            let runFont = value as! CTFont
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
            for (glyph, position) in zip(glyphs, positions) {
                var transform = CGAffineTransform(translationX: position.x, y: baseline - position.y)
                    .scaledBy(x: 1, y: -1)
                if let outline = CTFontCreatePathForGlyph(runFont, glyph, &transform) {
                    path.addPath(outline)
                }
            }
        }
    }
}

extension TextLayout {
    /// Glyph outlines in document coordinates; nil when there are no glyphs.
    public static func path(of content: TextContent, fontSize: CGFloat) -> CGPath? {
        let glyphs = layout(string: content.string, fontSize: fontSize).path
        guard !glyphs.isEmpty else { return nil }
        var transform = CGAffineTransform(translationX: content.origin.x, y: content.origin.y)
        return glyphs.copy(using: &transform)
    }
}
