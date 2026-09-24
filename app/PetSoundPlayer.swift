import AVFoundation
import Foundation

final class PetSoundPlayer {
    static let filenames = ["rubble-duck1.mp3", "rubble-duck2.mp3", "cute-cat-meow-loud.mp3"]

    private let press: AVAudioPlayer?
    private let release: AVAudioPlayer?
    private let completion: AVAudioPlayer?

    init(assetURL: URL) {
        func load(_ url: URL, volume: Float) -> AVAudioPlayer? {
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.volume = volume
            player.prepareToPlay()
            return player
        }
        let assets = assetURL.deletingLastPathComponent()
        press = load(assets.appendingPathComponent(Self.filenames[0]), volume: 0.6)
        release = load(assets.appendingPathComponent(Self.filenames[1]), volume: 0.6)
        let notification = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Sounds/codex-notification.wav")
        completion = load(notification, volume: 0.6) ?? press
    }

    func playPress() { play(press) }
    func playRelease() { play(release) }
    func playCompletion() { play(completion) }

    private func play(_ player: AVAudioPlayer?) {
        guard let player else { return }
        if player.isPlaying { player.stop() }
        player.currentTime = 0
        player.play()
    }
}
