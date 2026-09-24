import Foundation

private struct CompletionEvent: Decodable {
    let kind: String
    let session_id: String
    let turn_id: String
    let at: Double

    var key: String { "\(session_id):\(turn_id)" }
}

final class CompletionEventStore {
    private let fileURL: URL
    private var lastEventKey = ""

    init(dataURL: URL) {
        fileURL = dataURL.appendingPathComponent("latest-event.json")
    }

    func takeRecentCompletion() -> Bool {
        guard let data = try? Data(contentsOf: fileURL),
              let event = try? JSONDecoder().decode(CompletionEvent.self, from: data),
              event.kind == "turn_complete", event.key != lastEventKey else { return false }
        lastEventKey = event.key
        return abs(Date().timeIntervalSince1970 - event.at) < 12
    }
}
