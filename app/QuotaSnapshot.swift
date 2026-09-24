import Foundation

struct QuotaWindow: Decodable {
    let bucket: String
    let bucketName: String
    let durationMins: Int
    let usedPercent: Double
    let resetsAt: TimeInterval?

    var remainingPercent: Double { max(0, min(100, 100 - usedPercent)) }

    var label: String {
        if durationMins >= 1440 && durationMins % 1440 == 0 {
            return "\(durationMins / 1440)일"
        }
        if durationMins >= 60 && durationMins % 60 == 0 {
            return "\(durationMins / 60)시간"
        }
        return "\(durationMins)분"
    }

    var remainingText: String {
        let rounded = (remainingPercent * 10).rounded() / 10
        return rounded.rounded() == rounded
            ? "\(Int(rounded))%" : String(format: "%.1f%%", rounded)
    }

    func resetText(now: Date) -> String? {
        guard let resetsAt else { return nil }
        let remaining = Int(resetsAt - now.timeIntervalSince1970)
        if remaining <= 0 { return "곧 재설정" }
        if remaining >= 86_400 {
            let days = remaining / 86_400
            let hours = (remaining % 86_400) / 3_600
            return hours > 0 ? "\(days)일 \(hours)시간 후 재설정" : "\(days)일 후 재설정"
        }
        if remaining >= 3_600 {
            let hours = remaining / 3_600
            let minutes = (remaining % 3_600) / 60
            return minutes > 0 ? "\(hours)시간 \(minutes)분 후 재설정" : "\(hours)시간 후 재설정"
        }
        return "\(max(1, remaining / 60))분 후 재설정"
    }
}

struct QuotaSnapshot: Decodable {
    let schema: Int
    let status: String
    let reason: String?
    let fetchedAt: TimeInterval?
    let windows: [QuotaWindow]

    static func load(from dataURL: URL) -> QuotaSnapshot? {
        let url = dataURL.appendingPathComponent("rate-limits.json")
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 64_000,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Self.self, from: data),
              snapshot.schema == 1 else { return nil }
        return snapshot
    }

    func usable(now: Date) -> Bool {
        guard status == "ok", let fetchedAt, !windows.isEmpty else { return false }
        let age = now.timeIntervalSince1970 - fetchedAt
        return age >= -60 && age <= 600 && windows.allSatisfy {
            $0.usedPercent.isFinite && (0...100).contains($0.usedPercent)
                && $0.durationMins > 0
        }
    }

    func codexWindows(now: Date) -> [QuotaWindow] {
        guard usable(now: now) else { return [] }
        return Array(windows.filter { $0.bucket == "codex" }.prefix(2))
    }

    func statusText(now: Date, isRefreshing: Bool = false) -> String {
        if isRefreshing { return "Codex 사용량 확인 중…" }
        if status == "unavailable" {
            switch reason {
            case "codex_not_found": return "Codex CLI를 찾을 수 없음"
            case "account_unavailable": return "Codex CLI에 ChatGPT로 로그인하세요"
            case "no_windows": return "표시할 Codex 한도가 없습니다"
            default: return "한도를 확인할 수 없습니다"
            }
        }
        if usable(now: now) { return "Codex 한도가 표시되지 않았습니다" }
        return "사용량 정보가 만료되었습니다"
    }

    func menuRows(now: Date) -> [String] {
        let selected = codexWindows(now: now)
        guard !selected.isEmpty else { return [statusText(now: now)] }
        return selected.map { window in
            let reset = window.resetText(now: now).map { " · \($0)" } ?? ""
            return "\(window.label) · \(window.remainingText) 남음\(reset)"
        }
    }
}
