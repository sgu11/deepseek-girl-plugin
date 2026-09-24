import AppKit
import CoreGraphics

enum CodexWindowLocator {
    static func locate() -> NSRect? {
        let pids = Set(NSWorkspace.shared.runningApplications.compactMap { app -> pid_t? in
            let bundle = app.bundleIdentifier ?? ""
            let filename = app.bundleURL?.lastPathComponent ?? ""
            guard bundle == "com.openai.codex" || filename == "Codex.app" || filename == "ChatGPT.app" else {
                return nil
            }
            return app.processIdentifier
        })
        guard !pids.isEmpty,
              let windows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
              ) as? [[String: Any]] else { return nil }

        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        var first: CGRect?
        for info in windows {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  pids.contains(pid),
                  let details = info[kCGWindowBounds as String] as? NSDictionary,
                  let x = details["X"] as? CGFloat,
                  let y = details["Y"] as? CGFloat,
                  let width = details["Width"] as? CGFloat,
                  let height = details["Height"] as? CGFloat else { continue }
            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
            guard layer == 0, alpha > 0.01, width >= 320, height >= 200 else { continue }
            let bounds = CGRect(x: x, y: y, width: width, height: height)
            if pid == frontmost { return appKitBounds(from: bounds) }
            if first == nil { first = bounds }
        }
        return first.map(appKitBounds)
    }

    static func panelOrigin(for host: NSRect, panelSize: NSSize, offset: NSPoint = .zero,
                            anchor: SnapAnchor = SnapAnchor(horizontal: nil, vertical: nil)) -> NSPoint {
        let origin = WindowPlacement.origin(
            for: host, visibleFrame: visibleFrame(for: host), panelSize: panelSize, offset: offset
        )
        return WindowPlacement.anchored(origin, anchor: anchor, host: host,
                                        size: panelSize, visibleFrame: visibleFrame(for: host))
    }

    static func offset(for currentOrigin: NSPoint, host: NSRect, panelSize: NSSize) -> NSPoint {
        return WindowPlacement.offset(
            for: currentOrigin, host: host,
            visibleFrame: visibleFrame(for: host), panelSize: panelSize
        )
    }

    static func snapped(_ origin: NSPoint, host: NSRect, panelSize: NSSize) -> SnapResult {
        WindowPlacement.snapped(origin, host: host, size: panelSize,
                                visibleFrame: visibleFrame(for: host))
    }

    private static func visibleFrame(for host: NSRect) -> NSRect {
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(host) }) ?? NSScreen.screens.first
        return screen?.visibleFrame ?? host
    }

    private static func appKitBounds(from coreGraphicsBounds: CGRect) -> NSRect {
        // CGWindow coordinates have a top-left origin. AppKit uses bottom-left.
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        return NSRect(
            x: coreGraphicsBounds.minX,
            y: primaryTop - coreGraphicsBounds.maxY,
            width: coreGraphicsBounds.width,
            height: coreGraphicsBounds.height
        )
    }
}
