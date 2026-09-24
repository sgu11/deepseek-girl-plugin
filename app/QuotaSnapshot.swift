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
            return "\(durationMins / 1440)天"
        }
        if durationMins >= 60 && durationMins % 60 == 0 {
            return "\(durationMins / 60)h"
        }
        return "\(durationMins)分钟"
    }

    var remainingText: String {
        let rounded = (remainingPercent * 10).rounded() / 10
        return rounded.rounded() == rounded
            ? "\(Int(rounded))%" : String(format: "%.1f%%", rounded)
    }

    func resetText(now: Date) -> String? {
        guard let resetsAt else { return nil }
        let remaining = Int(resetsAt - now.timeIntervalSince1970)
        if remaining <= 0 { return "即将重置" }
        if remaining >= 86_400 {
            return "\(remaining / 86_400)天\((remaining % 86_400) / 3_600)小时后重置"
        }
        if remaining >= 3_600 {
            return "\(remaining / 3_600)小时\((remaining % 3_600) / 60)分后重置"
        }
        return "\(max(1, remaining / 60))分钟后重置"
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
        if isRefreshing { return "正在读取 Codex 用量…" }
        if status == "unavailable" {
            switch reason {
            case "codex_not_found": return "未找到 Codex CLI"
            case "account_unavailable": return "请用 ChatGPT 登录 Codex CLI"
            case "no_windows": return "此账户没有可显示的 Codex 限额"
            default: return "余量暂不可用，请稍后刷新"
            }
        }
        if usable(now: now) { return "暂未返回 Codex 限额" }
        return "用量数据已过期，正在等待刷新"
    }

    func menuRows(now: Date) -> [String] {
        let selected = codexWindows(now: now)
        guard !selected.isEmpty else { return [statusText(now: now)] }
        return selected.map { window in
            let reset = window.resetText(now: now).map { " · \($0)" } ?? ""
            return "\(window.label) 剩余 \(window.remainingText)\(reset)"
        }
    }
}
