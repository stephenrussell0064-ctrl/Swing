import CoreHaptics
import Foundation
import SwingGame
import UIKit

/// Turns a `HapticScript` into something the hand feels, at a precise time.
///
/// Timing is the whole point: the script is scheduled against the same clock
/// the `Cue` uses, so the bounce the hand feels and the moment the game is
/// judging the swing against are the same moment.
@MainActor
final class HapticPlayer {
    private var engine: CHHapticEngine?
    private let fallback = UIImpactFeedbackGenerator(style: .rigid)
    private(set) var isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    init() {
        startEngine()
    }

    private func startEngine() {
        guard isSupported else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            // Both handlers are called on the engine's own queue; `@Sendable`
            // keeps them from inheriting main-actor isolation (see the same
            // note in StandInDetector).
            engine.resetHandler = { @Sendable [weak self] in
                Task { @MainActor in self?.startEngine() }
            }
            engine.stoppedHandler = { @Sendable [weak self] _ in
                Task { @MainActor in self?.engine = nil }
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    /// Play `script` so that its own zero lands at `start`, in
    /// `Date.timeIntervalSinceReferenceDate` seconds. A `start` in the past
    /// plays immediately, skipping nothing — late is better than silent.
    func play(_ script: HapticScript, at start: TimeInterval = Date.timeIntervalSinceReferenceDate) {
        if engine == nil { startEngine() }
        guard let engine else {
            playFallback(script, at: start)
            return
        }
        let events = script.entries.flatMap { entry -> [CHHapticEvent] in
            switch entry.event {
            case .tap(let intensity, let sharpness):
                let transient = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(sharpness)),
                    ],
                    relativeTime: entry.at
                )
                // A lone transient is a flick; in a gripping hand it barely
                // registers. Strong taps get a short continuous burst under
                // them so they land as a thump, and the accent gets a second
                // transient so it is unmistakably different from a beat.
                guard intensity >= 0.85 else { return [transient] }
                var events = [
                    transient,
                    CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(sharpness)),
                        ],
                        relativeTime: entry.at,
                        duration: 0.07
                    ),
                ]
                if entry.event == HapticVocabulary.accent {
                    events.append(CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0),
                        ],
                        relativeTime: entry.at + 0.09
                    ))
                }
                return events
            case .rumble(let duration, let from, _):
                return [CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(from)),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                    ],
                    relativeTime: entry.at,
                    duration: duration
                )]
            }
        }
        // Rumbles ramp with a parameter curve on intensity.
        let curves = script.entries.compactMap { entry -> CHHapticParameterCurve? in
            guard case .rumble(let duration, let from, let to) = entry.event else { return nil }
            return CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0, value: Float(from)),
                    .init(relativeTime: duration, value: Float(to)),
                ],
                relativeTime: entry.at
            )
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            let delay = max(0, start - Date.timeIntervalSinceReferenceDate)
            try player.start(atTime: engine.currentTime + delay)
        } catch {
            playFallback(script, at: start)
        }
    }

    /// The simulator and very old phones: taps only, roughly on time.
    private func playFallback(_ script: HapticScript, at start: TimeInterval) {
        fallback.prepare()
        for entry in script.entries {
            let when = start + entry.at - Date.timeIntervalSinceReferenceDate
            Task { @MainActor [fallback] in
                if when > 0 { try? await Task.sleep(for: .seconds(when)) }
                if case .tap(let intensity, _) = entry.event {
                    fallback.impactOccurred(intensity: intensity)
                } else {
                    fallback.impactOccurred(intensity: 0.5)
                }
            }
        }
    }
}
