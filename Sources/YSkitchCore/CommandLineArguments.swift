import Foundation

public enum LaunchItem: Equatable, Sendable {
    case clipboard
    /// User-facing `-`; the launcher replaces it with `stdinFile` before forwarding.
    case stdin
    case file(String)
    /// Copy of standard input; titled like a clipboard image and deleted after loading.
    case stdinFile(String)
}

public enum CommandLineCommand: Equatable, Sendable {
    case help
    case version
    case quit
    case open([LaunchItem])
}

public struct CommandLineUsageError: Error, Equatable, Sendable {
    public let messages: [String]
}

public enum CommandLineArguments {
    /// Parses arguments typed by the user (without the program name).
    public static func parse(_ arguments: [String]) -> Result<CommandLineCommand, CommandLineUsageError> {
        var items: [LaunchItem] = []
        var errors: [String] = []
        var options: [String] = []
        var onlyFiles = false
        var stdinCount = 0

        for argument in arguments {
            if onlyFiles {
                items.append(.file(argument))
                continue
            }
            switch argument {
            case "--": onlyFiles = true
            case "-":
                stdinCount += 1
                if stdinCount == 2 { errors.append("'-' (standard input) can be given only once") }
                items.append(.stdin)
            case "--clipboard": items.append(.clipboard)
            case "--help", "--version", "--quit": options.append(argument)
            case _ where argument.hasPrefix("-"): errors.append("unknown option: \(argument)")
            default: items.append(.file(argument))
            }
        }

        if options.contains("--help") { return .success(.help) }
        for option in ["--version", "--quit"] where options.contains(option) && arguments.count > 1 {
            errors.append("\(option) can't be combined with other arguments")
        }
        if !errors.isEmpty { return .failure(CommandLineUsageError(messages: errors)) }
        switch options.first {
        case "--version": return .success(.version)
        case "--quit": return .success(.quit)
        default: return .success(.open(items))
        }
    }

    /// Makes file paths absolute so they survive the hand-off to the app's working directory.
    public static func absolute(_ path: String, relativeTo directory: String) -> String {
        let base = URL(filePath: directory, directoryHint: .isDirectory)
        return URL(filePath: path, directoryHint: .notDirectory, relativeTo: base)
            .standardizedFileURL.path(percentEncoded: false)
    }

    // MARK: Forwarding to the app

    private static let fileKey = "--file="
    private static let stdinFileKey = "--stdin-file="

    /// Arguments passed to the app at launch or in a command notification.
    /// `.stdin` must be replaced with `.stdinFile` beforehand; it is dropped otherwise.
    public static func encode(_ command: CommandLineCommand) -> [String] {
        switch command {
        case .help, .version: return []
        case .quit: return ["--quit"]
        case .open(let items):
            return items.compactMap {
                switch $0 {
                case .clipboard: "--clipboard"
                case .stdin: nil
                case .file(let path): fileKey + path
                case .stdinFile(let path): stdinFileKey + path
                }
            }
        }
    }

    /// Decodes `encode` output. Skips arguments injected by LaunchServices and AppKit
    /// (`-psn_…`, `-NS…`/`-Apple…` key-value pairs) and anything unrecognized.
    public static func decode(_ arguments: [String]) -> CommandLineCommand {
        var items: [LaunchItem] = []
        var index = arguments.startIndex
        while index < arguments.endIndex {
            let argument = arguments[index]
            index += 1
            if argument == "--quit" { return .quit }
            if argument == "--clipboard" {
                items.append(.clipboard)
            } else if argument.hasPrefix(fileKey) {
                items.append(.file(String(argument.dropFirst(fileKey.count))))
            } else if argument.hasPrefix(stdinFileKey) {
                items.append(.stdinFile(String(argument.dropFirst(stdinFileKey.count))))
            } else if argument.hasPrefix("-NS") || argument.hasPrefix("-Apple") {
                index += 1
            }
        }
        return .open(items)
    }

    // MARK: Output

    public static func usage(program: String) -> String {
        """
        Usage: \(program) [--clipboard | - | FILE]...
               \(program) --quit | --help | --version

        Opens each image in a new ySkitch window, in argument order.
        Starts ySkitch if it isn't running; with no arguments, starts it or brings it to the front.

          FILE          open an image file
          -             read an image from standard input
          --clipboard   open the clipboard image
          --            treat all following arguments as files
          --quit        quit ySkitch
          --help        show this help
          --version     show the version

        """
    }

    /// `./version.sh full` format.
    public static func version(infoDictionary: [String: Any]) -> String? {
        guard let version = infoDictionary["CFBundleShortVersionString"] as? String,
              let build = infoDictionary["CFBundleVersion"] as? String
        else { return nil }
        return "\(version)+\(build)"
    }
}
