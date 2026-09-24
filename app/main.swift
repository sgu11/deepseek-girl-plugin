import AppKit
import Foundation

private func argument(_ name: String) -> String? {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    return args[index + 1]
}

if CommandLine.arguments.contains("--probe") {
    if let host = CodexWindowLocator.locate() {
        print("Codex window bounds=\(host)")
    } else {
        print("No visible Codex window")
    }
} else if let data = argument("--data-dir"), let asset = argument("--asset") {
    let app = NSApplication.shared
    let delegate = Companion(
        dataURL: URL(fileURLWithPath: data),
        assetURL: URL(fileURLWithPath: asset)
    )
    app.delegate = delegate
    app.run()
} else {
    FileHandle.standardError.write(Data("usage: deepseek-girl --data-dir DIR --asset PNG\n".utf8))
    exit(2)
}
