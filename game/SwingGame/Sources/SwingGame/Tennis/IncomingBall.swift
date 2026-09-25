import Foundation
import SwingCore

/// A ball coming at the player from across the net.
///
/// The screen is in the player's hand, so the ball is described to the hand:
/// which side it is coming to (one tick forehand, two ticks backhand), then a
/// count-in of three beats, the last accented, and contact one beat later.
/// A harder-hit ball is a shorter beat.
public struct IncomingBall: Hashable, Sendable {

    public enum Side: String, Hashable, Sendable, CaseIterable {
        case forehand, backhand
    }

    public var side: Side
    /// m/s off the opponent's racket. A rally ball is 18–28; a hard hit is 32+.
    public var pace: Double
    /// Where it lands, 0 at the service line, 1 on the baseline. Affects how
    /// it plays off the racket, not the count.
    public var depth: Double
    /// True for the opponent's serve: no side warning, because you know where
    /// a serve comes from, but a longer count.
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

    /// The grid. A 20 m/s rally ball is a comfortable 0.75 s beat; a 32 m/s
    /// drive is 0.5. Slow on purpose until the grid is learned.
    public var beat: TimeInterval {
        (15.0 / max(pace, 10)).clamped(to: 0.5...0.75)
    }

    public var beats: Int { 4 }

    public var tolerance: TimeInterval {
        HapticVocabulary.tolerance(forBeat: beat)
    }

    /// Time between the side cue and the first beat. Long enough to move the
    /// hand to the other side.
    static let sideLead: TimeInterval = 0.7

    public func script() -> HapticScript {
        if isServe {
            return HapticScript.countIn(beats: beats, interval: beat)
        }
        var lead: [HapticScript.Entry] = [.init(at: 0, event: HapticVocabulary.tick)]
        if side == .backhand {
            lead.append(.init(at: 0.16, event: HapticVocabulary.tick))
        }
        return HapticScript.countIn(beats: beats, interval: beat, startingAt: IncomingBall.sideLead, leadIn: lead)
    }

    /// Spoken with the side cue, because a word is faster to learn than a
    /// tap count and the two together are faster than either.
    public var announcement: String? {
        isServe ? nil : (side == .forehand ? "Forehand." : "Backhand.")
    }
}

/// Your own serve. Nothing is coming; the count is your toss.
public enum Serve {
    public static let beat: TimeInterval = 0.7
    /// Four beats and hit on the fifth, like everything else.
    public static let script = HapticScript.countIn(beats: 4, interval: beat)
    /// Self-paced, so generous.
    public static let tolerance: TimeInterval = HapticVocabulary.tolerance(forBeat: beat) + 0.04
    /// Racket height at contact on a serve, metres.
    static let contactHeight = 2.5
}
