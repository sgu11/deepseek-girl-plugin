import AppKit

/// Keeps the expanded bubble on the same anchor as WhalePanel's small bubble.
enum QuotaBubblePlacement {
    static func origin(bubbleSize: NSSize, above whale: NSRect, in visible: NSRect) -> NSPoint {
        let overlap: CGFloat = 9
        let preferredX = whale.maxX - bubbleSize.width
        let aboveY = whale.maxY - overlap
        let belowY = whale.minY - bubbleSize.height + overlap
        let preferredY: CGFloat
        if aboveY + bubbleSize.height <= visible.maxY {
            preferredY = aboveY
        } else if belowY >= visible.minY {
            preferredY = belowY
        } else {
            preferredY = aboveY
        }
        return NSPoint(
            x: min(max(preferredX, visible.minX),
                   max(visible.minX, visible.maxX - bubbleSize.width)),
            y: min(max(preferredY, visible.minY),
                   max(visible.minY, visible.maxY - bubbleSize.height))
        )
    }
}
