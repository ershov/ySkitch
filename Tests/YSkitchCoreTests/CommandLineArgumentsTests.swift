import Foundation
import Testing
@testable import YSkitchCore

struct CommandLineArgumentsTests {
    private func parse(_ arguments: [String]) -> CommandLineCommand? {
        try? CommandLineArguments.parse(arguments).get()
    }

    private func errors(_ arguments: [String]) -> [String] {
        guard case .failure(let error) = CommandLineArguments.parse(arguments) else { return [] }
        return error.messages
    }

    @Test func noArgumentsOpensNothing() {
        #expect(parse([]) == .open([]))
    }

    @Test func itemsKeepArgumentOrderAndRepeats() {
        #expect(parse(["a.png", "--clipboard", "b.png", "a.png", "--clipboard", "-"]) == .open([
            .file("a.png"), .clipboard, .file("b.png"), .file("a.png"), .clipboard, .stdin,
        ]))
    }

    @Test func doubleDashMakesTheRestFiles() {
        #expect(parse(["--clipboard", "--", "--clipboard", "-", "--quit", "-x"]) == .open([
            .clipboard, .file("--clipboard"), .file("-"), .file("--quit"), .file("-x"),
        ]))
    }

    @Test func repeatedStdinIsAnError() {
        #expect(errors(["-", "a.png", "-"]) == ["'-' (standard input) can be given only once"])
        #expect(errors(["-", "-", "-"]).count == 1)
    }

    @Test func unknownOptionsAreAllReported() {
        #expect(errors(["a.png", "-x", "--bogus", "b.png"]) == ["unknown option: -x", "unknown option: --bogus"])
        #expect(errors(["-psn_0_123"]) == ["unknown option: -psn_0_123"])
    }

    @Test func helpWinsOverEverything() {
        #expect(parse(["--help"]) == .help)
        #expect(parse(["a.png", "--bogus", "--help", "--quit"]) == .help)
        #expect(parse(["--", "--help"]) == .open([.file("--help")]))
    }

    @Test func versionAndQuitMustStandAlone() {
        #expect(parse(["--version"]) == .version)
        #expect(parse(["--quit"]) == .quit)
        #expect(errors(["--quit", "a.png"]) == ["--quit can't be combined with other arguments"])
        #expect(errors(["--version", "--clipboard"]) == ["--version can't be combined with other arguments"])
        #expect(errors(["--quit", "--quit"]) == ["--quit can't be combined with other arguments"])
    }

    @Test func absolutePaths() {
        #expect(CommandLineArguments.absolute("a.png", relativeTo: "/Users/me") == "/Users/me/a.png")
        #expect(CommandLineArguments.absolute("../x/./a b.png", relativeTo: "/Users/me/dir") == "/Users/me/x/a b.png")
        #expect(CommandLineArguments.absolute("/tmp/a.png", relativeTo: "/Users/me") == "/tmp/a.png")
        #expect(CommandLineArguments.absolute("-", relativeTo: "/Users/me") == "/Users/me/-")
    }

    @Test func encodeDecodeRoundTrip() {
        let open = CommandLineCommand.open([
            .file("/a/x=y.png"), .clipboard, .stdinFile("/tmp/in.img"), .file("/a/x=y.png"), .clipboard,
        ])
        #expect(CommandLineArguments.decode(CommandLineArguments.encode(open)) == open)
        #expect(CommandLineArguments.decode(CommandLineArguments.encode(.quit)) == .quit)
        #expect(CommandLineArguments.decode(CommandLineArguments.encode(.open([]))) == .open([]))
    }

    @Test func encodedFilesNeverLookLikePlainArguments() {
        let encoded = CommandLineArguments.encode(.open([.file("/a.png"), .stdinFile("/b.img"), .stdin]))
        #expect(encoded == ["--file=/a.png", "--stdin-file=/b.img"])
    }

    @Test func decodeSkipsInjectedArguments() {
        let arguments = [
            "-psn_0_12345", "--file=/a.png", "-NSDocumentRevisionsDebugMode", "YES",
            "-AppleLanguages", "(en)", "stray", "--clipboard",
        ]
        #expect(CommandLineArguments.decode(arguments) == .open([.file("/a.png"), .clipboard]))
        #expect(CommandLineArguments.decode(["-NSQuitAlwaysKeepsWindows", "--quit"]) == .open([]))
    }

    @Test func usageNamesTheProgram() {
        let usage = CommandLineArguments.usage(program: "yskitch")
        #expect(usage.hasPrefix("Usage: yskitch "))
        for option in ["--clipboard", "--quit", "--help", "--version", "--"] { #expect(usage.contains(option)) }
    }

    @Test func versionFromInfoDictionary() {
        let info: [String: Any] = ["CFBundleShortVersionString": "0.3.1", "CFBundleVersion": "142"]
        #expect(CommandLineArguments.version(infoDictionary: info) == "0.3.1+142")
        #expect(CommandLineArguments.version(infoDictionary: [:]) == nil)
    }
}
