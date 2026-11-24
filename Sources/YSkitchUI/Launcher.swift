import AppKit
import os
import YSkitchCore

/// Runs when the binary is started from a shell: hands the request to the app and exits.
/// Uses only NSWorkspace/NSRunningApplication, never NSApplication, so no Dock icon appears.
@MainActor
public enum Launcher {
    private static let responseTimeout: TimeInterval = 10

    public static func run(arguments: [String]) -> Never {
        let program = arguments.first.map { URL(filePath: $0).lastPathComponent } ?? "ySkitch"
        let command: CommandLineCommand
        switch CommandLineArguments.parse(Array(arguments.dropFirst())) {
        case .success(let parsed): command = parsed
        case .failure(let error): usageFailure(error.messages, program: program)
        }

        let bundleURL = AppBundleLocation.currentExecutable.flatMap(AppBundleLocation.bundleURL(executable:))
        let info = bundleURL.flatMap { Bundle(url: $0)?.infoDictionary }
        let bundleID = info?["CFBundleIdentifier"] as? String

        switch command {
        case .help:
            print(CommandLineArguments.usage(program: program), terminator: "")
            exit(0)
        case .version:
            guard let version = info.flatMap(CommandLineArguments.version(infoDictionary:)) else {
                fail("version unknown: not running from ySkitch.app", program: program)
            }
            print(version)
            exit(0)
        case .quit:
            guard let bundleID else { fail("not running from ySkitch.app", program: program) }
            guard runningApp(bundleID) != nil else { exit(0) }
            guard send(.quit, bundleID: bundleID) else { fail("ySkitch is not responding", program: program) }
            guard waitUntil({ runningApp(bundleID) == nil }) else { fail("ySkitch did not quit", program: program) }
            exit(0)
        case .open(let items):
            if items.contains(.stdin), isatty(STDIN_FILENO) != 0 {
                usageFailure(["'-' needs an image piped to standard input"], program: program)
            }
            let (resolved, hasProblems) = resolve(items, program: program)
            guard let bundleURL, let bundleID else {
                YSkitchApp.run(command: .open(resolved))
                exit(0)
            }
            if !deliver(.open(resolved), bundleURL: bundleURL, bundleID: bundleID, program: program) { exit(1) }
            exit(hasProblems ? 1 : 0)
        }
    }

    /// Reports file problems without dropping the files: the app reports them again in its alert.
    private static func resolve(_ items: [LaunchItem], program: String) -> ([LaunchItem], hasProblems: Bool) {
        let directory = FileManager.default.currentDirectoryPath
        var resolved: [LaunchItem] = []
        var hasProblems = false
        for item in items {
            switch item {
            case .file(let path):
                if case .failure(let reason) = ImageFileLoader.load(path: path) {
                    printError("\(path): \(reason.short)", program: program)
                    hasProblems = true
                }
                resolved.append(.file(CommandLineArguments.absolute(path, relativeTo: directory)))
            case .stdin:
                let data = FileHandle.standardInput.readDataToEndOfFile()
                if case .failure(let reason) = ImageFileLoader.load(data: data) {
                    printError("standard input: \(reason.short)", program: program)
                    hasProblems = true
                }
                do {
                    resolved.append(.stdinFile(try saveStandardInput(data).path(percentEncoded: false)))
                } catch {
                    printError("standard input: \(error.localizedDescription)", program: program)
                    hasProblems = true
                }
            case .clipboard, .stdinFile:
                resolved.append(item)
            }
        }
        return (resolved, hasProblems)
    }

    /// Not under `DragTempFiles`: the app clears that on launch, possibly before reading this file.
    private static func saveStandardInput(_ data: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ySkitch-stdin", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "\(UUID().uuidString).img")
        try data.write(to: url)
        return url
    }

    private static func deliver(_ command: CommandLineCommand, bundleURL: URL, bundleID: String, program: String) -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        if let running = runningApp(bundleID) {
            guard send(command, bundleID: bundleID) else {
                printError("ySkitch is not responding", program: program)
                return false
            }
            return open(running.bundleURL ?? bundleURL, configuration: configuration, program: program)
        }
        configuration.arguments = CommandLineArguments.encode(command)
        return open(bundleURL, configuration: configuration, program: program)
    }

    private static func runningApp(_ bundleID: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first { !$0.isTerminated && $0.processIdentifier != getpid() }
    }

    /// Re-posts until the app acknowledges: it may still be launching and not yet listening.
    private static func send(_ command: CommandLineCommand, bundleID: String) -> Bool {
        let id = UUID().uuidString
        let arguments = CommandLineArguments.encode(command)
        let acknowledged = OSAllocatedUnfairLock(initialState: false)
        let center = DistributedNotificationCenter.default()
        let observer = center.addObserver(forName: CommandChannel.done, object: id, queue: nil) { _ in
            acknowledged.withLock { $0 = true }
        }
        defer { center.removeObserver(observer) }
        let timer = Timer(timeInterval: 0.5, repeats: true) { _ in
            CommandChannel.post(arguments: arguments, id: id)
        }
        RunLoop.current.add(timer, forMode: .default)
        defer { timer.invalidate() }
        CommandChannel.post(arguments: arguments, id: id)
        return waitUntil { acknowledged.withLock { $0 } }
    }

    private static func open(_ url: URL, configuration: NSWorkspace.OpenConfiguration, program: String) -> Bool {
        let result = OSAllocatedUnfairLock<Result<Void, any Error>?>(initialState: nil)
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            result.withLock { $0 = error.map { .failure($0) } ?? .success(()) }
        }
        guard waitUntil({ result.withLock { $0 } != nil }) else {
            printError("ySkitch did not start", program: program)
            return false
        }
        if case .failure(let error) = result.withLock({ $0 }) {
            printError(error.localizedDescription, program: program)
            return false
        }
        return true
    }

    private static func waitUntil(_ condition: () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(responseTimeout)
        while !condition() {
            guard Date.now < deadline else { return false }
            if !RunLoop.current.run(mode: .default, before: Date.now.addingTimeInterval(0.05)) {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        return true
    }

    private static func printError(_ message: String, program: String) {
        FileHandle.standardError.write(Data("\(program): \(message)\n".utf8))
    }

    private static func fail(_ message: String, program: String) -> Never {
        printError(message, program: program)
        exit(1)
    }

    private static func usageFailure(_ messages: [String], program: String) -> Never {
        messages.forEach { printError($0, program: program) }
        FileHandle.standardError.write(Data("Try '\(program) --help'.\n".utf8))
        exit(2)
    }
}
