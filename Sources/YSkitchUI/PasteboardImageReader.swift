import AppKit
import UniformTypeIdentifiers
import YSkitchCore

@MainActor
enum PasteboardImageReader {
    static func imageFileURLs(in pasteboard: NSPasteboard) -> [URL] {
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        return urls.filter { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true }
    }

    static func containsImage(_ pasteboard: NSPasteboard) -> Bool {
        !imageFileURLs(in: pasteboard).isEmpty
            || pasteboard.availableType(from: [.png, .tiff]) != nil
    }

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
