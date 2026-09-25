import AVFoundation
import Foundation
import SwingGame

/// The count-in through the speaker, in step with the haptics.
///
/// The ear resolves rhythm far better than the hand does. A phone in a fist
/// is loud enough in a garden, and a click has an edge to time against where
/// a vibration smears. Each beat of a `HapticScript` becomes a short tone:
/// low for a beat, high for the accent, quiet for a tick.
@MainActor
final class ClickPlayer {
    private let beat: Data
    private let accent: Data
    private let tick: Data
    private var live: [AVAudioPlayer] = []
    var isMuted = false

    init() {
        beat = ClickPlayer.tone(frequency: 740, duration: 0.035, volume: 0.7)
        accent = ClickPlayer.tone(frequency: 1480, duration: 0.06, volume: 1.0)
        tick = ClickPlayer.tone(frequency: 520, duration: 0.025, volume: 0.35)
    }

    /// Schedule every tap in `script` so the script's zero lands at `start`,
    /// in `Date.timeIntervalSinceReferenceDate` seconds.
    func schedule(_ script: HapticScript, at start: TimeInterval) {
        guard !isMuted else { return }
        live.removeAll { !$0.isPlaying && $0.currentTime == 0 && $0.deviceCurrentTime > 0 && $0.isPlaying == false && $0.duration > 0 && $0.currentTime >= $0.duration }
        let now = Date.timeIntervalSinceReferenceDate
        for entry in script.entries {
            guard case .tap = entry.event else { continue }
            let data: Data
            switch entry.event {
            case HapticVocabulary.accent: data = accent
            case HapticVocabulary.tick: data = tick
            default: data = beat
            }
            guard let player = try? AVAudioPlayer(data: data) else { continue }
            player.prepareToPlay()
            let delay = max(0, start + entry.at - now)
            player.play(atTime: player.deviceCurrentTime + delay)
            live.append(player)
        }
        // Keep the list from growing across a long match.
        if live.count > 64 { live.removeFirst(live.count - 64) }
    }

    /// A mono 16-bit WAV of a sine burst with a short attack and a decay, so
    /// it clicks rather than beeps.
    private static func tone(frequency: Double, duration: TimeInterval, volume: Double) -> Data {
        let rate = 44_100.0
        let frames = Int(rate * duration)
        var samples = [Int16](repeating: 0, count: frames)
        for i in 0..<frames {
            let t = Double(i) / rate
            let attack = min(1, t / 0.002)
            let decay = exp(-t / (duration * 0.35))
            let v = sin(2 * .pi * frequency * t) * attack * decay * volume
            samples[i] = Int16(max(-1, min(1, v)) * 32_767)
        }
        var data = Data()
        func put32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        func put16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
        let byteCount = UInt32(frames * 2)
        data.append(contentsOf: Array("RIFF".utf8)); put32(36 + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); put32(16)
        put16(1); put16(1); put32(UInt32(rate)); put32(UInt32(rate) * 2); put16(2); put16(16)
        data.append(contentsOf: Array("data".utf8)); put32(byteCount)
        samples.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}
