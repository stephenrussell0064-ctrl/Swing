import SwiftUI
import SwingGame

/// The count-in, drawn: one lamp per beat that lights as the beat lands, the
/// accent bigger and orange, and a ghost lamp for the swing that fills at
/// contact. Mostly for whoever is watching; the player's eyes are elsewhere.
struct BeatPulseView: View {
    let active: ActiveScript?
    let stage: Stage

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: active == nil)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 14) {
                if let active {
                    let beats = active.script.entries.filter { $0.event == HapticVocabulary.beat || $0.event == HapticVocabulary.accent }
                    ForEach(Array(beats.enumerated()), id: \.offset) { _, entry in
                        let elapsed = now - (active.start + entry.at)
                        lamp(lit: elapsed >= 0, accent: entry.event == HapticVocabulary.accent, age: elapsed)
                    }
                    let toContact = now - active.contactTime
                    swingLamp(progress: toContact >= 0 ? 1 : max(0, 1 + toContact / max(active.script.contactAt - (beats.last?.at ?? 0), 0.1)))
                } else {
                    ForEach(0..<4, id: \.self) { i in
                        lamp(lit: false, accent: i == 3, age: 0)
                    }
                    swingLamp(progress: stage == .result ? 1 : 0)
                }
            }
            .frame(height: 44)
        }
    }

    private func lamp(lit: Bool, accent: Bool, age: TimeInterval) -> some View {
        let size: CGFloat = accent ? 30 : 22
        let flash = lit ? max(0, 1 - age / 0.25) : 0
        return Circle()
            .fill(lit ? (accent ? Color.orange : Color.white) : Color.white.opacity(0.18))
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
            .shadow(color: (accent ? Color.orange : Color.white).opacity(0.8 * flash), radius: 12 * (1 + flash))
            .scaleEffect(1 + 0.35 * flash)
    }

    private func swingLamp(progress: Double) -> some View {
        ZStack {
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                .foregroundStyle(.white.opacity(0.5))
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(3)
            Image(systemName: "figure.cricket")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(progress >= 1 ? Color.green : Color.white.opacity(0.6))
        }
        .frame(width: 36, height: 36)
    }
}
