import Foundation

struct PetSettings: Codable {
    var bubblesEnabled = true
    var clickMessages = ["今天也辛苦啦。", "摸摸鱼，继续加油。"]
    var snapEnabled = true

    init() {}

    private enum CodingKeys: String, CodingKey {
        case bubblesEnabled, clickMessages, snapEnabled
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        bubblesEnabled = try values.decodeIfPresent(Bool.self, forKey: .bubblesEnabled) ?? bubblesEnabled
        clickMessages = try values.decodeIfPresent([String].self, forKey: .clickMessages) ?? clickMessages
        snapEnabled = try values.decodeIfPresent(Bool.self, forKey: .snapEnabled) ?? snapEnabled
    }
}

final class PetSettingsStore {
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
        valid.clickMessages = Array(valid.clickMessages.prefix(20))
            .map { String($0.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if valid.clickMessages.isEmpty { valid.clickMessages = PetSettings().clickMessages }
        return valid
    }

    func save(_ settings: PetSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
