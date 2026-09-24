import AppKit

@main
struct QuotaBubblePlacementTests {
    static func main() {
        let screen = NSRect(x: 0, y: 0, width: 1_200, height: 800)
        let expanded = NSSize(width: 221, height: 188)
        let panelOrigin = NSPoint(x: 930, y: 300)
        let whale = NSRect(x: panelOrigin.x + 70, y: panelOrigin.y,
                           width: 180, height: 180)
        let origin = QuotaBubblePlacement.origin(
            bubbleSize: expanded, above: whale, in: screen
        )
        // The expanded bubble starts exactly where the 50pt speech bubble starts.
        precondition(origin == NSPoint(x: panelOrigin.x + 29, y: panelOrigin.y + 171))

        let topWhale = NSRect(x: 400, y: 650, width: 180, height: 180)
        let below = QuotaBubblePlacement.origin(
            bubbleSize: expanded, above: topWhale, in: screen
        )
        precondition(below.y + expanded.height == topWhale.minY + 9)
        precondition(below.y >= screen.minY)

        let bottomWhale = NSRect(x: 400, y: 0, width: 180, height: 180)
        let above = QuotaBubblePlacement.origin(
            bubbleSize: expanded, above: bottomWhale, in: screen
        )
        precondition(above.y == 171)
        precondition(above.y + expanded.height <= screen.maxY)
        print("Quota bubble placement tests passed")
    }
}
