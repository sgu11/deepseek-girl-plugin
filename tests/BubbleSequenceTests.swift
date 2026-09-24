import Foundation

@main
struct BubbleSequenceTests {
    static func main() {
        var sequence = BubbleSequence()
        let messages = ["第一条", "第二条"]
        precondition(sequence.tapBubble(messages: messages) == nil)
        precondition(sequence.tapWhale(messages: messages) == "第一条")
        precondition(sequence.tapBubble(messages: messages) == "第二条")
        precondition(sequence.tapBubble(messages: messages) == nil)
        precondition(sequence.index == nil)
        precondition(sequence.tapWhale(messages: messages) == "第一条")
        sequence.reset()
        precondition(sequence.tapBubble(messages: messages) == nil)
        precondition(sequence.tapWhale(messages: []) == nil)
        print("Bubble sequence tests passed")
    }
}
