import AppKit

struct PetGesture {
    enum Target {
        case whale
        case bubble
    }

    let target: Target
    let mouseDown: NSPoint
    let panelOrigin: NSPoint
    private(set) var moved = false

    mutating func origin(at mouse: NSPoint) -> NSPoint? {
        let dx = mouse.x - mouseDown.x
        let dy = mouse.y - mouseDown.y
        if dx * dx + dy * dy >= 16 { moved = true }
        guard moved else { return nil }
        return NSPoint(x: panelOrigin.x + dx, y: panelOrigin.y + dy)
    }
}
