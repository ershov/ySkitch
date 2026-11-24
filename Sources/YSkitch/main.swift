import YSkitchUI

MainActor.assumeIsolated {
    if YSkitchApp.isLaunchedByLaunchServices {
        YSkitchApp.run()
    } else {
        Launcher.run(arguments: CommandLine.arguments)
    }
}
