import Foundation
import SwingCore

/// What this player's swing is like, measured from a practice swing or two.
///
/// The count-in is built from it: one beat is the time this player's own
/// swing takes from leaving the stance to contact, so "start on the high beat"
/// means their natural swing arrives on the beat after. A bowler or an
/// opponent then only scales that — a quick bowler is a shorter beat *for
/// this player*, not a fixed number that suits nobody.
public struct SwingProfile: Hashable, Codable, Sendable {
    /// Seconds from the hand leaving the stance to release, for a full
    /// natural swing.
    public var swingDuration: TimeInterval
    /// Peak rotation rate of that swing, rad/s. Detection thresholds sit at
    /// a fraction of this, so a gentle swinger's shot still registers and a
    /// hard hitter's practice waggle does not.
    public var peakRotation: Double

    public init(swingDuration: TimeInterval, peakRotation: Double) {
        self.swingDuration = swingDuration
        self.peakRotation = peakRotation
    }

    /// Before anyone has swung: a comfortable middle.
    public static let `default` = SwingProfile(swingDuration: 0.7, peakRotation: 8)

    /// The base beat: the swing itself, kept within what a hand can count.
    public var beat: TimeInterval {
        swingDuration.clamped(to: 0.45...1.0)
    }

    /// The beat scaled for a particular ball. `factor` below 1 is quicker.
    public func beat(scaledBy factor: Double) -> TimeInterval {
        (beat * factor).clamped(to: 0.4...1.1)
    }

    /// Fold in another measured swing. A running average, weighted toward the
    /// new one so a player who is loosening up gets followed.
    public func merging(swingDuration d: TimeInterval, peakRotation ω: Double) -> SwingProfile {
        SwingProfile(
            swingDuration: swingDuration * 0.4 + d * 0.6,
            peakRotation: peakRotation * 0.4 + ω * 0.6
        )
    }

    /// From a `Shot` the detector produced for a practice swing. `tempo.back`
    /// is the time from leaving rest to release; `spinRate` at release is the
    /// peak rotation when release is defined as the fastest moment.
    public static func measured(from shot: Shot) -> SwingProfile? {
        guard shot.tempo.back > 0.2, shot.spinRate > 2 else { return nil }
        return SwingProfile(swingDuration: shot.tempo.back, peakRotation: shot.spinRate)
    }
}
