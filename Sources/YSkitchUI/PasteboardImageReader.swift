import AppKit
import YSkitchCore

@MainActor
enum PasteboardImageReader {
    static func read(from pasteboard: NSPasteboard) -> BaseImage? {
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        for url in urls {
            if let image = try? ImageImporter.load(url: url) { return image }
        }

        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pasteboard.data(forType: type), let image = try? ImageImporter.load(data: data) {
                return image
            }
        }

        guard let nsImage = NSImage(pasteboard: pasteboard),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let scale = ImageImporter.scale(pixelWidth: cgImage.width, pointWidth: nsImage.size.width)
        return BaseImage(cgImage: ImageImporter.opaqueOnWhite(cgImage), scale: scale)
    }
}
