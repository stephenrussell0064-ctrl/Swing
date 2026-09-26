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
    /// True while the phone is hanging still, top edge down: the stance.
    var inStance: Bool { get }
    /// One line for the screen: "hold still…", "ready", "swinging".
    var status: String { get }
    /// This player's swing. The detector sets its thresholds from it.
    var profile: SwingProfile { get set }
    func start()
    func stop()
    /// Wait until the player is holding the phone hanging down and still,
    /// the way a golfer addresses the ball, then fix the play frame from the
    /// way the screen faces. Returns false if they never did, or on cancel.
    func awaitStance(timeout: TimeInterval) async -> Bool
}

/// The count-in that is playing right now, for the screen.
struct ActiveScript: Hashable {
    var script: HapticScript
    var start: TimeInterval

    var contactTime: TimeInterval { start + script.contactAt }
}

/// Where a session is, for the screen and for the scene.
enum Stage: Hashable {
    case idle
    /// Waiting for the player to hang the phone down and hold still.
    case stance
    /// Measuring the player's own swing, `n` of the practice swings.
    case profiling(Int)
    /// A count-in is playing.
    case countIn
    /// Cricket: bowl when ready.
    case bowling
    /// The moment after: showing what happened.
    case result
    case finished
}

/// The buzz that says "set". Distinct from every beat: a rumble, not a tap.
enum ReadyCue {
    static let haptic = HapticScript(
        entries: [.init(at: 0, event: .rumble(duration: 0.3, from: 1.0, to: 0.3))],
        contactAt: 0
    )
}

/// Collects shots as they arrive and hands the session the one that answers
/// a cue. Sessions `await` on it; sources push into it.
@MainActor
final class ShotInbox {
    typealias Entry = (shot: Shot, trace: [MotionSample])
    private var pending: [Entry] = []

    func push(_ shot: Shot, trace: [MotionSample]) {
        pending.append((shot, trace))
    }

    func clear() { pending.removeAll() }

    /// Detection is retrospective: a `Shot` whose release was at `t` arrives
    /// a little after `t`. Wait this much past a deadline before deciding
    /// nothing came.
    static let detectionLatency: TimeInterval = 0.45

    /// The shot that best answers `cue`: released no earlier than
    /// `notBefore`, no later than the cue's deadline, closest to contact.
    /// Returns as soon as an on-time-or-late swing arrives (no better one can
    /// follow), or when the deadline plus latency passes.
    func shot(for cue: Cue, notBefore: TimeInterval) async -> Entry? {
        let giveUp = cue.deadline + ShotInbox.detectionLatency
        var best: Entry?
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
    func nextShot(notBefore: TimeInterval) async -> Entry? {
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

    /// Everything the hand did in one go: waits up to `firstWithin` for a
    /// first shot, then `window` more for the rest of the same motion. A
    /// practice swing produces a backswing and a downswing; the caller wants
    /// the bigger of them.
    func swings(notBefore: TimeInterval, firstWithin: TimeInterval, window: TimeInterval) async -> [Entry] {
        let giveUp = Date.timeIntervalSinceReferenceDate + firstWithin
        while !Task.isCancelled {
            if pending.contains(where: { $0.shot.timestamp >= notBefore }) { break }
            if Date.timeIntervalSinceReferenceDate > giveUp { return [] }
            try? await Task.sleep(for: .milliseconds(25))
        }
        try? await Task.sleep(for: .seconds(window))
        let found = pending.filter { $0.shot.timestamp >= notBefore }
        pending.removeAll()
        return found
    }
}

/// A button instead of a swing. For the simulator, and for checking the game
/// loop, speech and scoring with the phone on the desk.
@MainActor
@Observable
final class TapShotSource: ShotSource {
    var handler: ((Shot, [MotionSample]) -> Void)?
    var isCalibrated = false
    var inStance = false
    var status = "Tap to swing"
    var profile: SwingProfile = .default
    /// What the pretend swing looks like. Sliders on the play screen.
    var speed: Double = 11
    var elevation: Double = 8
    var yaw: Double = 0

    func start() {}
    func stop() {}

    func awaitStance(timeout: TimeInterval) async -> Bool {
        status = "Pretending to hold still"
        try? await Task.sleep(for: .milliseconds(600))
        isCalibrated = true
        inStance = true
        status = "Tap to swing"
        return !Task.isCancelled
    }

    func swingNow(kind: Shot.Kind = .swing) {
        inStance = false
        let e = elevation * .pi / 180, y = yaw * .pi / 180
        let shot = Shot(
            timestamp: Date.timeIntervalSinceReferenceDate,
            kind: kind,
            releaseSpeed: speed,
            peakSpeed: speed,
            direction: Vector3(cos(e) * cos(y), sin(e), cos(e) * sin(y)),
            attitude: .identity,
            spinAxis: Vector3(0, 0, -1),
            spinRate: 9,
            tempo: .init(back: 0.7, through: 0),
            confidence: 1
        )
        handler?(shot, [])
    }
}
