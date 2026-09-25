import Foundation
import SwingCore
import SwingGame

/// Where `Shot`s come from. The sessions do not care.
///
/// In the finished app this is the `motion/` detector. On this branch it is
/// the stand-in in `StandIn/`, or a button for the simulator.
@MainActor
protocol ShotSource: AnyObject {
    /// Called with every detected motion and the trace it was cut from, so
    /// the session can save the pair as a fixture with a note about what the
    /// game made of it.
    var handler: ((Shot, [MotionSample]) -> Void)? { get set }
    var isCalibrated: Bool { get }
    /// One line for the screen: "hold still…", "ready", "swinging".
    var status: String { get }
    func start()
    func stop()
    /// Fix the play frame from where the phone is pointing now. Takes about a
    /// second of holding still. Returns false if the hand would not keep still.
    func calibrate() async -> Bool
}

/// Collects shots as they arrive and hands the session the one that answers
/// a cue. Sessions `await` on it; sources push into it.
@MainActor
final class ShotInbox {
    private var pending: [(shot: Shot, trace: [MotionSample])] = []

    func push(_ shot: Shot, trace: [MotionSample]) {
        pending.append((shot, trace))
    }

    func clear() { pending.removeAll() }

    /// Detection is retrospective: a `Shot` whose release was at `t` arrives
    /// some hundreds of milliseconds after `t`. Wait this much past a
    /// deadline before deciding nothing came.
    static let detectionLatency: TimeInterval = 0.45

    /// The shot that best answers `cue`: released no earlier than
    /// `notBefore`, no later than the cue's deadline, closest to contact.
    /// Returns as soon as an on-time-or-late swing arrives (no better one can
    /// follow), or when the deadline plus latency passes.
    func shot(for cue: Cue, notBefore: TimeInterval) async -> (shot: Shot, trace: [MotionSample])? {
        let giveUp = cue.deadline + ShotInbox.detectionLatency
        var best: (shot: Shot, trace: [MotionSample])?
        while !Task.isCancelled {
            for candidate in pending where candidate.shot.timestamp >= notBefore && candidate.shot.timestamp <= cue.deadline {
                if best == nil || abs(candidate.shot.timestamp - cue.contactTime) < abs(best!.shot.timestamp - cue.contactTime) {
                    best = candidate
                }
            }
            pending.removeAll { $0.shot.timestamp <= cue.deadline }
            if let best, best.shot.timestamp >= cue.contactTime - cue.tolerance {
                return best
            }
            if Date.timeIntervalSinceReferenceDate > giveUp {
                return best
            }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return nil
    }

    /// The first shot released after `notBefore`, however long it takes.
    /// For bowling, where the player goes when they are ready.
    func nextShot(notBefore: TimeInterval) async -> (shot: Shot, trace: [MotionSample])? {
        while !Task.isCancelled {
            if let i = pending.firstIndex(where: { $0.shot.timestamp >= notBefore }) {
                let found = pending[i]
                pending.removeAll { $0.shot.timestamp <= found.shot.timestamp }
                return found
            }
            pending.removeAll()
            try? await Task.sleep(for: .milliseconds(25))
        }
        return nil
    }
}

/// A button instead of a swing. For the simulator, and for checking the game
/// loop, speech and scoring with the phone on the desk.
@MainActor
@Observable
final class TapShotSource: ShotSource {
    var handler: ((Shot, [MotionSample]) -> Void)?
    var isCalibrated = false
    var status = "Tap to swing"
    /// What the pretend swing looks like. Sliders on the play screen.
    var speed: Double = 11
    var elevation: Double = 8
    var yaw: Double = 0

    func start() {}
    func stop() {}

    func calibrate() async -> Bool {
        isCalibrated = true
        return true
    }

    func swingNow(kind: Shot.Kind = .swing) {
        let e = elevation * .pi / 180, y = yaw * .pi / 180
        let shot = Shot(
            timestamp: Date.timeIntervalSinceReferenceDate,
            kind: kind,
            releaseSpeed: speed,
            peakSpeed: speed,
            direction: Vector3(cos(e) * cos(y), sin(e), cos(e) * sin(y)),
            attitude: .identity,
            spinAxis: Vector3(0, 0, -1),
            spinRate: 3,
            tempo: .init(back: 0.6, through: 0.2),
            confidence: 1
        )
        handler?(shot, [])
    }
}
