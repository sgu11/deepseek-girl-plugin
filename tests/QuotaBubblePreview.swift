import AppKit

@main
struct QuotaBubblePreview {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fatalError("Usage: preview asset.png output.png")
        }
        _ = NSApplication.shared
        let now = Date()
        let snapshot = QuotaSnapshot(
            schema: 1, status: "ok", reason: nil, fetchedAt: now.timeIntervalSince1970,
            windows: [
                QuotaWindow(bucket: "codex", bucketName: "Codex", durationMins: 300,
                            usedPercent: 42, resetsAt: now.addingTimeInterval(3_600).timeIntervalSince1970),
                QuotaWindow(bucket: "codex", bucketName: "Codex", durationMins: 10_080,
                            usedPercent: 8, resetsAt: now.addingTimeInterval(6 * 86_400).timeIntervalSince1970),
            ]
        )
        let panel = QuotaBubblePanel()
        panel.show(
            snapshot: snapshot, isRefreshing: false, message: "이 통통한 고래를 닦달한다고?",
            above: NSRect(x: -9_000, y: -9_000, width: 180, height: 180),
            in: NSRect(x: -10_000, y: -10_000, width: 1_200, height: 800), now: now
        )
        defer { panel.orderOut(nil) }
        guard let bubble = panel.contentView,
              let bubbleRep = bubble.bitmapImageRepForCachingDisplay(in: bubble.bounds),
              let art = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
            fatalError("Preview content unavailable")
        }
        bubble.cacheDisplay(in: bubble.bounds, to: bubbleRep)

        let canvas = NSView(frame: NSRect(x: 0, y: 0, width: 255, height: 180 + bubble.bounds.height - 9))
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = NSColor(
            calibratedRed: 0.985, green: 0.990, blue: 1.000, alpha: 1
        ).cgColor
        let whale = NSImageView(frame: NSRect(x: 70, y: 0, width: 180, height: 180))
        whale.image = art
        whale.imageScaling = .scaleProportionallyUpOrDown
        canvas.addSubview(whale)
        let expanded = NSImageView(frame: NSRect(x: 29, y: 171,
                                                 width: bubble.bounds.width,
                                                 height: bubble.bounds.height))
        expanded.image = NSImage(size: bubble.bounds.size)
        expanded.image?.addRepresentation(bubbleRep)
        canvas.addSubview(expanded)
        guard let previewRep = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else {
            fatalError("Could not allocate preview")
        }
        canvas.cacheDisplay(in: canvas.bounds, to: previewRep)
        guard let png = previewRep.representation(using: .png, properties: [:]) else {
            fatalError("Could not render preview")
        }
        try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
    }
}
