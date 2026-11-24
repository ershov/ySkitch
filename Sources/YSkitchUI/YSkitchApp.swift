import AppKit
import YSkitchCore

@MainActor
public enum YSkitchApp {
    private static var delegate: AppDelegate?

    /// Started by LaunchServices: the launch arguments come from the launcher in forwarded form.
    public static var isLaunchedByLaunchServices: Bool { getppid() == 1 }

    public static func run() {
        run(command: CommandLineArguments.decode(Array(CommandLine.arguments.dropFirst())))
    }

    static func run(command: CommandLineCommand) {
        // Otherwise AppKit also opens plain launch arguments as documents.
        UserDefaults.standard.register(defaults: ["NSTreatUnknownArgumentsAsOpen": "NO"])
        NSWindow.allowsAutomaticWindowTabbing = false
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate(launchCommand: command)
        self.delegate = delegate
        app.delegate = delegate
        app.run()
    }
}
