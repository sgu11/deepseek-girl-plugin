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

    static func clamped(_ origin: NSPoint, size: NSSize, to visible: NSRect) -> NSPoint {
        return NSPoint(
            x: min(max(origin.x, visible.minX), visible.maxX - size.width),
            y: min(max(origin.y, visible.minY), visible.maxY - size.height)
        )
    }

    static func anchored(_ origin: NSPoint, anchor: SnapAnchor, host: NSRect,
                         size: NSSize, visibleFrame: NSRect) -> NSPoint {
        var result = origin
        switch anchor.horizontal {
        case .left: result.x = host.minX
        case .right: result.x = host.maxX - size.width
        case nil: break
        }
        switch anchor.vertical {
        case .bottom: result.y = host.minY
        case .top: result.y = host.maxY - size.height
        case nil: break
        }
        return clamped(result, size: size, to: visibleFrame)
    }

    static func snapped(_ origin: NSPoint, host: NSRect, size: NSSize,
                        visibleFrame: NSRect, threshold: CGFloat = 28) -> SnapResult {
        let leftDistance = abs(origin.x - host.minX)
        let rightDistance = abs(origin.x + size.width - host.maxX)
        let bottomDistance = abs(origin.y - host.minY)
        let topDistance = abs(origin.y + size.height - host.maxY)
        let horizontal: SnapAnchor.Horizontal? = min(leftDistance, rightDistance) <= threshold
            ? (leftDistance <= rightDistance ? .left : .right) : nil
        let vertical: SnapAnchor.Vertical? = min(bottomDistance, topDistance) <= threshold
            ? (bottomDistance <= topDistance ? .bottom : .top) : nil
        let anchor = SnapAnchor(horizontal: horizontal, vertical: vertical)
        return SnapResult(origin: anchored(origin, anchor: anchor, host: host,
                                          size: size, visibleFrame: visibleFrame), anchor: anchor)
    }
}
