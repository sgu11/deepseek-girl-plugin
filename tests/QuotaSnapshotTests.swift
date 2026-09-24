import Foundation

@main
struct QuotaSnapshotTests {
    static func main() throws {
        let now = Date(timeIntervalSince1970: 1_790_160_000)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deepseek-girl-quota-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("rate-limits.json")
        try Data("""
        {"schema":1,"status":"ok","fetchedAt":1790160000,"windows":[
          {"bucket":"codex","bucketName":"Codex","durationMins":10080,
           "usedPercent":96,"resetsAt":1790508615},
          {"bucket":"codex","bucketName":"Codex","durationMins":300,
           "usedPercent":50,"resetsAt":1790163600},
          {"bucket":"codex_other","bucketName":"Other","durationMins":60,
           "usedPercent":20,"resetsAt":1790163600}]}
        """.utf8).write(to: file)
        let snapshot = try XCTUnwrap(QuotaSnapshot.load(from: directory))
        precondition(snapshot.usable(now: now))
        precondition(snapshot.menuRows(now: now).count == 2)
        precondition(snapshot.codexWindows(now: now).count == 2)
        precondition(snapshot.menuRows(now: now)[0].contains("7일 · 4% 남음"))
        precondition(snapshot.menuRows(now: now)[1].contains("5시간 · 50% 남음"))
        precondition(!snapshot.menuRows(now: now).joined().contains("Other"))
        precondition(!snapshot.usable(now: now.addingTimeInterval(601)))
        precondition(snapshot.codexWindows(now: now.addingTimeInterval(601)).isEmpty)
        precondition(snapshot.statusText(now: now.addingTimeInterval(601)).contains("만료"))

        try Data("""
        {"schema":1,"status":"ok","fetchedAt":1790160000,"windows":[
          {"bucket":"codex_other","bucketName":"Other","durationMins":60,
           "usedPercent":20,"resetsAt":1790163600}]}
        """.utf8).write(to: file)
        let otherOnly = try XCTUnwrap(QuotaSnapshot.load(from: directory))
        precondition(otherOnly.codexWindows(now: now).isEmpty)
        precondition(otherOnly.menuRows(now: now) == ["Codex 한도가 표시되지 않았습니다"])
        print("Quota snapshot tests passed")
    }

    private static func XCTUnwrap<T>(_ value: T?) throws -> T {
        guard let value else { throw NSError(domain: "QuotaSnapshotTests", code: 1) }
        return value
    }
}
