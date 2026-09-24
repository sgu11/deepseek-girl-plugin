import AppKit

@main
struct WindowPlacementTests {
    static func main() {
        let visible = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let host = NSRect(x: visible.minX, y: visible.minY,
                          width: visible.width, height: visible.height)
        let size = NSSize(width: 255, height: 228)
        let base = WindowPlacement.origin(for: host, visibleFrame: visible, panelSize: size)
        let moved = WindowPlacement.origin(
            for: host, visibleFrame: visible, panelSize: size,
            offset: NSPoint(x: -100, y: 100)
        )

        precondition(abs(moved.x - (base.x - 100)) < 0.01)
        precondition(abs(moved.y - (base.y + 100)) < 0.01)
        let offset = WindowPlacement.offset(
            for: moved, host: host, visibleFrame: visible, panelSize: size
        )
        precondition(abs(offset.x + 100) < 0.01)
        precondition(abs(offset.y - 100) < 0.01)

        let leftTop = WindowPlacement.snapped(
            NSPoint(x: 12, y: 855), host: host, size: size, visibleFrame: visible
        )
        precondition(leftTop.anchor.horizontal == .left)
        precondition(leftTop.anchor.vertical == .top)
        precondition(leftTop.origin == NSPoint(x: 0, y: 852))

        let free = WindowPlacement.snapped(
            NSPoint(x: 450, y: 400), host: host, size: size, visibleFrame: visible
        )
        precondition(free.anchor.isEmpty)
        precondition(free.origin == NSPoint(x: 450, y: 400))

        let narrowerHost = NSRect(x: 0, y: 0, width: 1200, height: 800)
        let restored = WindowPlacement.anchored(
            NSPoint(x: 450, y: 400),
            anchor: SnapAnchor(horizontal: .right, vertical: .bottom),
            host: narrowerHost, size: size, visibleFrame: visible
        )
        precondition(restored == NSPoint(x: 945, y: 0))
        print("Window placement tests passed")
    }
}
