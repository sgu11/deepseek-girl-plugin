import Foundation

@main
struct PetSettingsTests {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("deepseek-girl-settings-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = PetSettingsStore(dataURL: directory)
        precondition(store.load().bubblesEnabled)

        var settings = PetSettings()
        settings.bubblesEnabled = false
        settings.clickMessages = ["测试一", "测试二"]
        settings.snapEnabled = false
        store.save(settings)

        let loaded = store.load()
        precondition(!loaded.bubblesEnabled)
        precondition(loaded.clickMessages == ["测试一", "测试二"])
        precondition(!loaded.snapEnabled)

        let file = directory.appendingPathComponent("settings.json")
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        precondition((attributes[.posixPermissions] as? Int) == 0o600)

        settings.clickMessages = [" ", "保留"]
        store.save(settings)
        precondition(store.load().clickMessages == ["保留"])

        try Data("{\"bubblesEnabled\":false,\"clickMessages\":[\"旧配置\"],\"character\":\"DSniang02.png\",\"pressSoundsEnabled\":true,\"completionSoundEnabled\":true,\"soundTheme\":\"duck\",\"volume\":0.8}".utf8)
            .write(to: file)
        let migrated = store.load()
        precondition(!migrated.bubblesEnabled)
        precondition(migrated.clickMessages == ["旧配置"])
        precondition(migrated.snapEnabled)
        store.save(migrated)
        let normalized = try String(contentsOf: file, encoding: .utf8)
        precondition(!normalized.contains("pressSoundsEnabled"))
        precondition(!normalized.contains("completionSoundEnabled"))
        precondition(!normalized.contains("soundTheme"))
        precondition(!normalized.contains("volume"))
        print("Pet settings tests passed")
    }
}
