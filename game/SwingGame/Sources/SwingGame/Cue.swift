import Foundation
import SwingCore

/// The moment the game asked for a hit, in the same clock as `Shot.timestamp`
/// (seconds since the reference date).
///
/// This is how a timing sport works without the detector knowing a ball was
/// coming. `motion/` reports *when* the hand released; the game remembers when
/// it asked; the difference is the timing. Nothing in `Shot` had to change.
public struct Cue: Hashable, Sendable {
    public var contactTime: TimeInterval
    /// Half-width of the "on time" window, seconds. A shot this far off is at
    /// the edge of being a hit at all.
    public var tolerance: TimeInterval

    public init(contactTime: TimeInterval, tolerance: TimeInterval) {
        self.contactTime = contactTime
        self.tolerance = tolerance
    }

    /// The cue for a script that starts playing at `start`.
    public init(script: HapticScript, startingAt start: TimeInterval, tolerance: TimeInterval) {
        self.contactTime = start + script.contactAt
        self.tolerance = tolerance
    }

    /// The latest a `Shot` can arrive and still be considered an attempt at
    /// this ball rather than the next. Detection is retrospective, so the
    /// `Shot` itself lands a few hundred milliseconds after its own timestamp;
    /// this is about the timestamp, not the arrival.
    public var deadline: TimeInterval { contactTime + tolerance * 2.5 }

    public func timing(of shot: Shot) -> Timing {
        Timing(error: shot.timestamp - contactTime, tolerance: tolerance)
    }
}

/// How well a swing met its cue.
public struct Timing: Hashable, Sendable {
    /// Seconds. Negative is early, positive is late.
    public var error: TimeInterval
    public var tolerance: TimeInterval

    public init(error: TimeInterval, tolerance: TimeInterval) {
        self.error = error
        self.tolerance = tolerance
    }

    /// 1 exactly on time, 0 at the edge of the tolerance window, clamped.
    /// Quadratic so a small error costs almost nothing — a player who is
    /// nearly right should feel nearly perfect, not 80%.
    public var quality: Double {
        guard tolerance > 0 else { return error == 0 ? 1 : 0 }
        let n = min(abs(error) / tolerance, 1)
        return 1 - n * n
    }

    public enum Grade: String, Hashable, Sendable {
        case perfect, early, late, tooEarly, tooLate
    }

    public var grade: Grade {
        let n = error / tolerance
        switch n {
        case ..<(-1): return .tooEarly
        case (-1)..<(-0.25): return .early
        case (-0.25)...0.25: return .perfect
        case 0.25...1: return .late
        default: return .tooLate
        }
    }

    /// True when the swing was so far off the cue that no bat or racket met the
    /// ball. Callers decide what a miss means: bowled, a let-through, an air
    /// shot.
    public var missed: Bool { abs(error) > tolerance }

    /// A few words the phone says after the result, so the player can learn
    /// the grid. `nil` when there is nothing to correct.
    public var feedback: String? {
        let ms = Int((abs(error) * 1000).rounded())
        switch grade {
        case .perfect: return nil
        case .early: return "A touch early."
        case .late: return "A touch late."
        case .tooEarly: return ms > 400 ? "Way too early." : "Too early, by \(ms) milliseconds."
        case .tooLate: return ms > 400 ? "Way too late." : "Too late, by \(ms) milliseconds."
        }
    }
}
