import Foundation

@main
struct QuotaMonitorTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("deepseek-girl-quota-cwd-\(UUID().uuidString)")
        let plugin = root.appendingPathComponent("plugin")
        let hooks = plugin.appendingPathComponent("hooks")
        let caller = root.appendingPathComponent("caller")
        let data = root.appendingPathComponent("data")
        for directory in [hooks, caller, data] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let helper = hooks.appendingPathComponent("quota.py")
        try """
        import os
        import sys
        from pathlib import Path
        data = Path(sys.argv[sys.argv.index('--data-dir') + 1])
        (data / 'cwd.txt').write_text(os.getcwd())
        """.write(to: helper, atomically: true, encoding: .utf8)

        let original = FileManager.default.currentDirectoryPath
        defer {
            _ = FileManager.default.changeCurrentDirectoryPath(original)
            try? FileManager.default.removeItem(at: root)
        }
        precondition(FileManager.default.changeCurrentDirectoryPath(caller.path))

        let monitor = QuotaMonitor(dataURL: data, pluginRoot: plugin)
        monitor.refreshIfDue(minimumInterval: 0)
        let marker = data.appendingPathComponent("cwd.txt")
        let deadline = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: marker.path) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        let observed = try String(contentsOf: marker, encoding: .utf8)
        let actualDirectory = URL(fileURLWithPath: observed).resolvingSymlinksInPath().path
        let expectedDirectory = plugin.resolvingSymlinksInPath().path
        precondition(actualDirectory == expectedDirectory,
                     "quota worker used \(actualDirectory), expected \(expectedDirectory)")
        print("Quota monitor working directory tests passed")
    }
}
