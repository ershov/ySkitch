import Foundation

/// Launcher → running app commands over distributed notifications, acknowledged per request.
enum CommandChannel {
    static let command = Notification.Name("dev.yskitch.command")
    static let done = Notification.Name("dev.yskitch.command.done")
    static let argumentsKey = "arguments"

    static func post(arguments: [String], id: String) {
        DistributedNotificationCenter.default().postNotificationName(
            command, object: id, userInfo: [argumentsKey: arguments], deliverImmediately: true)
    }

    static func acknowledge(id: String) {
        DistributedNotificationCenter.default().postNotificationName(
            done, object: id, userInfo: nil, deliverImmediately: true)
    }

    @MainActor
    static func listen(_ handler: @escaping @MainActor (_ arguments: [String], _ id: String) -> Void) -> any NSObjectProtocol {
        DistributedNotificationCenter.default().addObserver(forName: command, object: nil, queue: .main) { note in
            guard let id = note.object as? String,
                  let arguments = note.userInfo?[argumentsKey] as? [String]
            else { return }
            MainActor.assumeIsolated { handler(arguments, id) }
        }
    }
}
