import AppKit
import Foundation

@main
struct WhaleHitTests {
    static func main() {
        guard CommandLine.arguments.count == 2,
              let image = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
            fatalError("Whale image is missing")
        }
        let destination = NSRect(x: 70, y: 0, width: 180, height: 180)
        let center = image.hitTest(NSRect(x: 160, y: 90, width: 1, height: 1),
                                   withDestinationRect: destination, context: nil,
                                   hints: nil, flipped: false)
        let transparentCorner = image.hitTest(NSRect(x: 71, y: 178, width: 1, height: 1),
                                              withDestinationRect: destination, context: nil,
                                              hints: nil, flipped: false)
        precondition(center)
        precondition(!transparentCorner)
        print("Whale image alpha hit tests passed")
    }
}
