import Foundation

struct BubbleSequence {
    private(set) var index: Int?

    mutating func tapWhale(messages: [String]) -> String? {
        guard let first = messages.first else { return nil }
        if index != 0 { index = 0 }
        return first
    }

    mutating func tapBubble(messages: [String]) -> String? {
        guard let current = index else { return nil }
        let next = current + 1
        guard messages.indices.contains(next) else {
            index = nil
            return nil
        }
        index = next
        return messages[next]
    }

    mutating func reset() { index = nil }
}
