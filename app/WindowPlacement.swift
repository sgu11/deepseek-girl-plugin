import AppKit

struct SnapAnchor: Codable, Equatable {
    enum Horizontal: String, Codable { case left, right }
    enum Vertical: String, Codable { case bottom, top }

    var horizontal: Horizontal?
    var vertical: Vertical?

    var isEmpty: Bool { horizontal == nil && vertical == nil }
}

struct SnapResult {
    let origin: NSPoint
    let anchor: SnapAnchor
}

enum WindowPlacement {
    static func origin(
        for host: NSRect, visibleFrame: NSRect,
        panelSize: NSSize, offset: NSPoint = .zero
    ) -> NSPoint {
        let anchor = NSPoint(x: host.maxX - panelSize.width + 10, y: host.minY + 8)
        let base = clamped(anchor, size: panelSize, to: visibleFrame)
        let proposed = NSPoint(x: base.x + offset.x, y: base.y + offset.y)
        return clamped(proposed, size: panelSize, to: visibleFrame)
    }

    static func offset(
        for currentOrigin: NSPoint, host: NSRect,
        visibleFrame: NSRect, panelSize: NSSize
    ) -> NSPoint {
        let anchor = origin(for: host, visibleFrame: visibleFrame, panelSize: panelSize)
        return NSPoint(x: currentOrigin.x - anchor.x, y: currentOrigin.y - anchor.y)
    }

    static func clamped(_ origin: NSPoint, size: NSSize, to visible: NSRect,
                        attachment: NSRect? = nil) -> NSPoint {
        let bounds = attachment ?? NSRect(origin: .zero, size: size)
        return NSPoint(
            x: min(max(origin.x, visible.minX - bounds.minX), visible.maxX - bounds.maxX),
            y: min(max(origin.y, visible.minY - bounds.minY), visible.maxY - bounds.maxY)
        )
    }

    static func anchored(_ origin: NSPoint, anchor: SnapAnchor, host: NSRect,
                         size: NSSize, visibleFrame: NSRect, attachment: NSRect? = nil) -> NSPoint {
        let bounds = attachment ?? NSRect(origin: .zero, size: size)
        var result = origin
        switch anchor.horizontal {
        case .left: result.x = host.minX - bounds.minX
        case .right: result.x = host.maxX - bounds.maxX
        case nil: break
        }
        switch anchor.vertical {
        case .bottom: result.y = host.minY - bounds.minY
        case .top: result.y = host.maxY - bounds.maxY
        case nil: break
        }
        return clamped(result, size: size, to: visibleFrame, attachment: attachment)
    }

    static func snapped(_ origin: NSPoint, host: NSRect, size: NSSize,
                        visibleFrame: NSRect, threshold: CGFloat = 28,
                        attachment: NSRect? = nil) -> SnapResult {
        let bounds = attachment ?? NSRect(origin: .zero, size: size)
        let leftDistance = abs(origin.x + bounds.minX - host.minX)
        let rightDistance = abs(origin.x + bounds.maxX - host.maxX)
        let bottomDistance = abs(origin.y + bounds.minY - host.minY)
        let topDistance = abs(origin.y + bounds.maxY - host.maxY)
        let horizontal: SnapAnchor.Horizontal? = min(leftDistance, rightDistance) <= threshold
            ? (leftDistance <= rightDistance ? .left : .right) : nil
        let vertical: SnapAnchor.Vertical? = min(bottomDistance, topDistance) <= threshold
            ? (bottomDistance <= topDistance ? .bottom : .top) : nil
        let anchor = SnapAnchor(horizontal: horizontal, vertical: vertical)
        return SnapResult(origin: anchored(origin, anchor: anchor, host: host,
                                          size: size, visibleFrame: visibleFrame, attachment: attachment), anchor: anchor)
    }
}
