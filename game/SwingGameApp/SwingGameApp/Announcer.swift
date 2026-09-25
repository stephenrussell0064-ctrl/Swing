import AVFoundation
import Foundation

/// The phone's voice. With no screen to look at, this is the scoreboard, the
/// umpire and the commentator.
@MainActor
final class Announcer {
    private let synthesizer = AVSpeechSynthesizer()
    private let voice: AVSpeechSynthesisVoice?
    var isMuted = false

    init() {
        voice = AVSpeechSynthesisVoice(language: "en-GB")
        // `.default` mode, not `.spokenAudio`: the same session carries the
        // count-in clicks, and spoken-audio processing adds latency to them.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// Queue a line. Lines already speaking finish first.
    func say(_ text: String) {
        guard !isMuted, !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.53
        utterance.postUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }

    /// Interrupt whatever is being said. For results — the hand wants to know
    /// now, not after the last sentence.
    func sayNow(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        say(text)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
