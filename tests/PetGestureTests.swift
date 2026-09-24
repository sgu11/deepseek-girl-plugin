import AppKit

@main
struct PetGestureTests {
    static func main() {
        var gesture = PetGesture(
            target: .whale,
            mouseDown: NSPoint(x: 200, y: 300),
            panelOrigin: NSPoint(x: 800, y: 100)
        )
        precondition(gesture.origin(at: NSPoint(x: 202, y: 302)) == nil)
        precondition(!gesture.moved)
        precondition(gesture.origin(at: NSPoint(x: 210, y: 280)) == NSPoint(x: 810, y: 80))
        precondition(gesture.moved)
        precondition(gesture.origin(at: NSPoint(x: 201, y: 300)) == NSPoint(x: 801, y: 100))
        print("Pet gesture tests passed")
    }
}
