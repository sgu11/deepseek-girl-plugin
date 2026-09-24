import AVFoundation
import Foundation

@main
struct PetSoundTests {
    static func main() throws {
        precondition(CommandLine.arguments.count == 2)
        let assets = URL(fileURLWithPath: CommandLine.arguments[1]).deletingLastPathComponent()
        for filename in PetSoundPlayer.filenames {
            let player = try AVAudioPlayer(contentsOf: assets.appendingPathComponent(filename))
            precondition(player.duration > 0, "Invalid pet sound: \(filename)")
        }
        print("Pet sound decoding tests passed")
    }
}
