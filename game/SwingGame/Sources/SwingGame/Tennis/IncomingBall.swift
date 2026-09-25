import Foundation
import SwingCore

/// A ball coming at the player from across the net.
///
/// The screen is in the player's hand, so the ball is described to the hand:
/// which side it is coming to (one tick forehand, two ticks backhand), a soft
/// tap as it leaves the opponent's racket, a hard tap at the bounce, and then
/// silence to swing into.
public struct IncomingBall: Hashable, Sendable {

    public enum Side: String, Hashable, Sendable, CaseIterable {
        case forehand, backhand
    }

    public var side: Side
    /// m/s off the opponent's racket. A rally ball is 18–28; a hard hit is 32+.
    public var pace: Double
    /// Where it lands, 0 at the service line, 1 on the baseline.
    public var depth: Double
    /// True for the opponent's serve: no side warning, because you know where
    /// a serve comes from, but a longer toss-to-hit lead-in.
    public var isServe: Bool

    public init(side: Side, pace: Double, depth: Double, isServe: Bool = false) {
        self.side = side
        self.pace = pace
        self.depth = depth.clamped(to: 0...1)
        self.isServe = isServe
    }

    /// Baseline to baseline. The player is assumed to be on theirs.
    static let courtLength = 23.77
    /// Singles half-width.
    static let halfWidth = 4.115
    static let netDistance = courtLength / 2
    static let serviceLine = netDistance + 6.4

    /// Racket to racket, allowing for the arc and the bounce.
    public var flightTime: TimeInterval {
        IncomingBall.courtLength / max(pace, 5) * 1.15
    }

    /// Fraction of the flight at which it bounces. A deep ball bounces late,
    /// close to you.
    var bounceFraction: Double { 0.55 + 0.25 * depth }

    /// Faster ball, tighter window, within reason.
    public var tolerance: TimeInterval {
        (flightTime * 0.14).clamped(to: 0.08...0.16)
    }

    /// Time between the side cue and the opponent striking the ball. Long
    /// enough to move the hand to the other side.
    static let sideLead: TimeInterval = 0.7

    public func script() -> HapticScript {
        var entries: [HapticScript.Entry] = []
        var t: TimeInterval = 0
        if !isServe {
            entries.append(.init(at: 0, event: HapticVocabulary.tick))
            if side == .backhand {
                entries.append(.init(at: 0.16, event: HapticVocabulary.tick))
            }
            t = IncomingBall.sideLead
        } else {
            // The opponent's toss: a short rising rumble, then the hit.
            entries.append(.init(at: 0, event: .rumble(duration: 0.6, from: 0.2, to: 0.7)))
            t = 0.85
        }
        entries.append(.init(at: t, event: HapticVocabulary.released))
        entries.append(.init(at: t + flightTime * bounceFraction, event: HapticVocabulary.bounce))
        return HapticScript(entries: entries, contactAt: t + flightTime)
    }

    /// Spoken with the side cue, because a word is faster to learn than a
    /// tap count and the two together are faster than either.
    public var announcement: String? {
        isServe ? nil : (side == .forehand ? "Forehand." : "Backhand.")
    }
}

/// Your own serve. Nothing is coming; the cue is your toss.
public enum Serve {
    /// Two ready ticks, a rising toss, and the hit at the top of it.
    public static let script = HapticScript(
        entries: [
            .init(at: 0.0, event: HapticVocabulary.tick),
            .init(at: 0.3, event: HapticVocabulary.tick),
            .init(at: 0.7, event: .rumble(duration: 0.7, from: 0.15, to: 0.8)),
        ],
        contactAt: 1.55
    )
    /// Self-paced, so generous.
    public static let tolerance: TimeInterval = 0.16
    /// Racket height at contact on a serve, metres.
    static let contactHeight = 2.5
}
