import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers
import YSkitchCore
@testable import YSkitchUI

@MainActor
private final class Reports {
    var all: [[OpenProblem]] = []
}

@MainActor
struct LaunchCommandTests {
    private let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "ySkitch-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func pngData() -> Data {
        let ctx = CGContext(
            data: nil, width: 4, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, ctx.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private func file(_ name: String, _ data: Data? = nil) throws -> String {
        let url = directory.appending(path: name)
        try (data ?? pngData()).write(to: url)
        return url.path
    }

    private func pasteboard(withImage: Bool) -> NSPasteboard {
        let pasteboard = NSPasteboard(name: .init("ySkitch.tests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        if withImage { pasteboard.setData(pngData(), forType: .png) }
        return pasteboard
    }

    private func cleanUp(_ registry: WindowRegistry, _ pasteboard: NSPasteboard) {
        registry.controllers.forEach { $0.close() }
        pasteboard.releaseGlobally()
        try? FileManager.default.removeItem(at: directory)
    }

    @Test func windowsOpenInArgumentOrder() throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let pasteboard = pasteboard(withImage: true)
        defer { cleanUp(registry, pasteboard) }
        let a = try file("A.png")
        let b = try file("B.png")
        let stdin = try file("input.img")

        let result = registry.open(
            [.file(a), .clipboard, .file(b), .stdinFile(stdin), .file(a), .clipboard], pasteboard: pasteboard)

        #expect(result.opened == 6)
        #expect(result.problems.isEmpty)
        let titles = registry.controllers.compactMap { $0.window?.title }
        #expect(titles.count == 6)
        #expect(titles[0] == "A")
        #expect(titles[1].hasPrefix("ySkitch "))
        #expect(titles[2] == "B")
        #expect(titles[3].hasPrefix("ySkitch "))
        #expect(titles[4] == "A")
        #expect(titles[5].hasPrefix("ySkitch "))
        #expect(!FileManager.default.fileExists(atPath: stdin))
        #expect(FileManager.default.fileExists(atPath: a))
    }

    @Test func problemsAreCollectedAndGoodFilesStillOpen() throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let pasteboard = pasteboard(withImage: false)
        defer { cleanUp(registry, pasteboard) }
        let good = try file("Good.png")
        let text = try file("notes.txt", Data("x".utf8))
        let missing = directory.appending(path: "missing.png").path
        let stdin = try file("input.img", Data("garbage".utf8))

        let result = registry.open(
            [.file(missing), .file(good), .clipboard, .file(text), .stdinFile(stdin)], pasteboard: pasteboard)

        #expect(result.opened == 1)
        #expect(registry.controllers.first?.window?.title == "Good")
        #expect(result.problems == [
            OpenProblem(source: .file(missing), reason: .notFound),
            OpenProblem(source: .file(text), reason: .notImage),
            OpenProblem(source: .standardInput, reason: .notImage),
        ])
        #expect(!FileManager.default.fileExists(atPath: stdin))
    }

    @Test func launchWithArgumentsOpensOnlyRequestedWindows() throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let pasteboard = pasteboard(withImage: true)
        defer { cleanUp(registry, pasteboard) }
        let a = try file("A.png")
        let delegate = AppDelegate(
            registry: registry, launchCommand: .open([.file(a)]), pasteboard: pasteboard, presentProblems: { _ in })

        delegate.performLaunchCommand()

        #expect(registry.controllers.compactMap { $0.window?.title } == ["A"])
    }

    @Test func launchThatOpensNothingFallsBackToDefaultWindow() async throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let pasteboard = pasteboard(withImage: false)
        defer { cleanUp(registry, pasteboard) }
        let reported = Reports()
        let missing = directory.appending(path: "missing.png").path
        let delegate = AppDelegate(
            registry: registry, launchCommand: .open([.clipboard, .file(missing)]), pasteboard: pasteboard,
            presentProblems: { reported.all.append($0) })

        delegate.performLaunchCommand()
        await waitForMainQueue()

        #expect(registry.controllers.count == 1)
        #expect(registry.controllers.first?.model.document.base == nil)
        #expect(reported.all == [[OpenProblem(source: .file(missing), reason: .notFound)]])
    }

    @Test func launchWithoutArgumentsOpensDefaultWindow() throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let pasteboard = pasteboard(withImage: true)
        defer { cleanUp(registry, pasteboard) }
        let delegate = AppDelegate(registry: registry, pasteboard: pasteboard, presentProblems: { _ in })

        delegate.performLaunchCommand()

        #expect(registry.controllers.count == 1)
        #expect(registry.controllers.first?.model.document.base != nil)
    }

    @Test func commandOpensWindowsOnceAndReportsProblemsOnce() async throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let pasteboard = pasteboard(withImage: false)
        defer { cleanUp(registry, pasteboard) }
        let reported = Reports()
        let delegate = AppDelegate(
            registry: registry, pasteboard: pasteboard, presentProblems: { reported.all.append($0) })
        let a = try file("A.png")
        let missing = directory.appending(path: "missing.png").path
        let arguments = CommandLineArguments.encode(.open([.file(missing), .clipboard, .file(a), .file(missing)]))

        delegate.handleCommand(arguments: arguments, id: "1")
        delegate.handleCommand(arguments: arguments, id: "1")
        await waitForMainQueue()

        #expect(registry.controllers.compactMap { $0.window?.title } == ["A"])
        #expect(reported.all.count == 1)
        #expect(reported.all.first?.count == 2)
    }

    @Test func emptyCommandOpensNoWindowAndSuppressesReopenWindow() throws {
        let registry = WindowRegistry(toolSettings: .inMemory())
        let pasteboard = pasteboard(withImage: true)
        defer { cleanUp(registry, pasteboard) }
        let delegate = AppDelegate(registry: registry, pasteboard: pasteboard, presentProblems: { _ in })

        delegate.handleCommand(arguments: [], id: "1")
        #expect(registry.controllers.isEmpty)
        _ = delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        #expect(registry.controllers.isEmpty)
        _ = delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
        #expect(registry.controllers.count == 1)
    }

    private func waitForMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
}
