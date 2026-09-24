import Foundation

final class QuotaMonitor {
    private let dataURL: URL
    private let pluginRoot: URL
    private let helperURL: URL
    private var process: Process?
    private var lastAttempt = Date.distantPast
    private(set) var snapshot: QuotaSnapshot?
    var isRefreshing: Bool { process != nil }

    init(dataURL: URL, pluginRoot: URL) {
        self.dataURL = dataURL
        self.pluginRoot = pluginRoot
        helperURL = pluginRoot.appendingPathComponent("hooks/quota.py")
        snapshot = QuotaSnapshot.load(from: dataURL)
    }

    func refreshIfDue(minimumInterval: TimeInterval = 300) {
        guard process == nil,
              Date().timeIntervalSince(lastAttempt) >= minimumInterval,
              FileManager.default.fileExists(atPath: helperURL.path) else { return }
        lastAttempt = Date()
        let worker = Process()
        worker.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        worker.arguments = ["python3", helperURL.path, "--data-dir", dataURL.path]
        worker.currentDirectoryURL = pluginRoot
        var environment = ProcessInfo.processInfo.environment
        // Subscription windows belong to ChatGPT sign-in, not API-key billing.
        environment.removeValue(forKey: "OPENAI_API_KEY")
        environment.removeValue(forKey: "CODEX_API_KEY")
        environment["PATH"] = [environment["PATH"] ?? "", "/opt/homebrew/bin", "/usr/local/bin",
                               "/usr/bin", "/bin"].joined(separator: ":")
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        worker.environment = environment
        worker.standardOutput = FileHandle.nullDevice
        worker.standardError = FileHandle.nullDevice
        worker.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.process = nil
                self.snapshot = QuotaSnapshot.load(from: self.dataURL)
            }
        }
        do {
            try worker.run()
            process = worker
        } catch {
            process = nil
        }
    }
}
