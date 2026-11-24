import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import YSkitchCore

struct OpenProblemTests {
    private func pngData() -> Data {
        let image = makeImage(width: 2, height: 2, pixels: Array(repeating: red, count: 4))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        precondition(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func withTempDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ySkitch-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func reason(_ result: Result<BaseImage, OpenProblem.Reason>) -> OpenProblem.Reason? {
        if case .failure(let reason) = result { return reason }
        return nil
    }

    @Test func loaderReportsWhyAFileCantBeOpened() throws {
        try withTempDirectory { directory in
            let good = directory.appending(path: "good.png")
            let text = directory.appending(path: "notes.txt")
            let empty = directory.appending(path: "empty.png")
            let locked = directory.appending(path: "locked.png")
            try pngData().write(to: good)
            try Data("x".utf8).write(to: text)
            try Data().write(to: empty)
            try pngData().write(to: locked)
            try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: locked.path)

            #expect(reason(ImageFileLoader.load(path: good.path)) == nil)
            #expect(reason(ImageFileLoader.load(path: text.path)) == .notImage)
            #expect(reason(ImageFileLoader.load(path: empty.path)) == .empty)
            #expect(reason(ImageFileLoader.load(path: locked.path)) == .unreadable)
            #expect(reason(ImageFileLoader.load(path: directory.path)) == .isFolder)
            #expect(reason(ImageFileLoader.load(path: directory.appending(path: "missing.png").path)) == .notFound)
        }
    }

    @Test func loaderChecksData() {
        #expect(reason(ImageFileLoader.load(data: pngData())) == nil)
        #expect(reason(ImageFileLoader.load(data: Data())) == .empty)
        #expect(reason(ImageFileLoader.load(data: Data("x".utf8))) == .notImage)
    }

    @Test func singleProblemAlertNamesTheFile() throws {
        let alert = try #require(OpenProblem.alert(for: [OpenProblem(source: .file("/a/b/shot.png"), reason: .notImage)]))
        #expect(alert.message == "“shot.png” couldn't be opened.")
        #expect(alert.information == "The file is not a supported image.")

        let stdin = try #require(OpenProblem.alert(for: [OpenProblem(source: .standardInput, reason: .empty)]))
        #expect(stdin.message == "The image from standard input couldn't be opened.")
    }

    @Test func problemsAreCollectedIntoOneAlert() throws {
        let alert = try #require(OpenProblem.alert(for: [
            OpenProblem(source: .file("/a/missing.png"), reason: .notFound),
            OpenProblem(source: .standardInput, reason: .notImage),
            OpenProblem(source: .file("/a/dir"), reason: .isFolder),
        ]))
        #expect(alert.message == "3 images couldn't be opened.")
        #expect(alert.information == """
            missing.png: no such file
            Standard input: not a supported image
            dir: is a folder
            """)
        #expect(OpenProblem.alert(for: []) == nil)
    }
}

struct AppBundleLocationTests {
    @Test func findsBundleThroughSymlink() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "ySkitch-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let macOS = root.appending(path: "Apps/ySkitch.app/Contents/MacOS")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        let executable = macOS.appending(path: "ySkitch")
        try Data().write(to: executable)
        let bin = root.appending(path: "bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let link = bin.appending(path: "yskitch")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: executable)

        let expected = AppBundleLocation.realPath(root).appending(path: "Apps/ySkitch.app").path
        #expect(AppBundleLocation.bundleURL(executable: executable)?.path == expected)
        #expect(AppBundleLocation.bundleURL(executable: link)?.path == expected)
        #expect(AppBundleLocation.bundleURL(executable: bin) == nil)
        #expect(AppBundleLocation.bundleURL(executable: URL(filePath: "/usr/bin/true")) == nil)
    }

    @Test func currentExecutableIsAbsolute() throws {
        let url = try #require(AppBundleLocation.currentExecutable)
        #expect(url.path.hasPrefix("/"))
    }
}
