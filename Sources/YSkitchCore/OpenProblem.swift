import Foundation

public struct OpenProblem: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case file(String)
        case standardInput
    }

    public enum Reason: Error, Equatable, Sendable {
        case notFound
        case isFolder
        case unreadable
        case empty
        case notImage

        /// For command-line output.
        public var short: String {
            switch self {
            case .notFound: "no such file"
            case .isFolder: "is a folder"
            case .unreadable: "permission denied"
            case .empty: "no data"
            case .notImage: "not a supported image"
            }
        }

        /// For alerts.
        public var sentence: String {
            switch self {
            case .notFound: "The file doesn't exist."
            case .isFolder: "It's a folder."
            case .unreadable: "The file can't be read."
            case .empty: "No data."
            case .notImage: "The file is not a supported image."
            }
        }
    }

    public var source: Source
    public var reason: Reason

    public init(source: Source, reason: Reason) {
        self.source = source
        self.reason = reason
    }

    public var displayName: String {
        switch source {
        case .file(let path): URL(filePath: path).lastPathComponent
        case .standardInput: "Standard input"
        }
    }

    /// One alert per batch: the single problem by name, or a list.
    public static func alert(for problems: [OpenProblem]) -> (message: String, information: String)? {
        guard let first = problems.first else { return nil }
        if problems.count == 1 {
            let name = first.source == .standardInput ? "The image from standard input" : "“\(first.displayName)”"
            return ("\(name) couldn't be opened.", first.reason.sentence)
        }
        let lines = problems.map { "\($0.displayName): \($0.reason.short)" }
        return ("\(problems.count) images couldn't be opened.", lines.joined(separator: "\n"))
    }
}

public enum ImageFileLoader {
    public static func load(path: String, fileManager: FileManager = .default) -> Result<BaseImage, OpenProblem.Reason> {
        if let reason = problem(path: path, fileManager: fileManager) { return .failure(reason) }
        guard let image = try? ImageImporter.load(url: URL(filePath: path)) else { return .failure(.notImage) }
        return .success(image)
    }

    public static func load(data: Data) -> Result<BaseImage, OpenProblem.Reason> {
        if data.isEmpty { return .failure(.empty) }
        guard let image = try? ImageImporter.load(data: data) else { return .failure(.notImage) }
        return .success(image)
    }

    private static func problem(path: String, fileManager: FileManager) -> OpenProblem.Reason? {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { return .notFound }
        if isDirectory.boolValue { return .isFolder }
        guard fileManager.isReadableFile(atPath: path) else { return .unreadable }
        let size = (try? fileManager.attributesOfItem(atPath: path)[.size] as? NSNumber)?.intValue
        return size == 0 ? .empty : nil
    }
}
