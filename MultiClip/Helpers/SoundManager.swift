import AppKit

@MainActor
enum SoundManager {
    static func playPasteSound() {
        guard Settings.shared.pasteSoundEnabled else { return }
        NSSound(named: "Tink")?.play()
    }
}
