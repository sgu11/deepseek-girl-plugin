import Foundation

struct PetSettings: Codable {
    var bubblesEnabled = true
    var clickMessages = ["오늘도 고생 많았어!", "잠깐 쉬고, 다시 힘내자!"]
    var snapEnabled = true
    var cornerRadius: Double = 16

    init() {}

    private enum CodingKeys: String, CodingKey {
        case bubblesEnabled, clickMessages, snapEnabled, cornerRadius
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        bubblesEnabled = try values.decodeIfPresent(Bool.self, forKey: .bubblesEnabled) ?? bubblesEnabled
        clickMessages = try values.decodeIfPresent([String].self, forKey: .clickMessages) ?? clickMessages
        snapEnabled = try values.decodeIfPresent(Bool.self, forKey: .snapEnabled) ?? snapEnabled
        cornerRadius = try values.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? cornerRadius
    }
}

final class PetSettingsStore {
    private static let legacyDefaultClickMessages = ["今天也辛苦啦。", "摸摸鱼，继续加油。"]
    private let url: URL

    init(dataURL: URL) {
        url = dataURL.appendingPathComponent("settings.json")
    }

    func load() -> PetSettings {
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(PetSettings.self, from: data) else {
            return PetSettings()
        }
        var valid = settings
        valid.cornerRadius = valid.cornerRadius.isFinite
            ? min(max(valid.cornerRadius, 0), 40)
            : PetSettings().cornerRadius
        valid.clickMessages = Array(valid.clickMessages.prefix(20))
            .map { String($0.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if valid.clickMessages.isEmpty { valid.clickMessages = PetSettings().clickMessages }
        if valid.clickMessages == Self.legacyDefaultClickMessages {
            valid.clickMessages = PetSettings().clickMessages
            save(valid)
        }
        return valid
    }

    func save(_ settings: PetSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
