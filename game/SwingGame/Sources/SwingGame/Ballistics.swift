import Foundation
import SwingCore

/// The little physics every bat-and-ball sport shares. Deliberately crude:
/// a projectile from a height, a roll on grass, a Magnus nudge for spin. The
/// point is not realism, it is that the same swing always goes the same
/// distance and a faster one goes further — the rest is tuning against
/// fixtures, and tuning wants knobs, not a simulator.
public enum Ballistics {
    static let g = 9.81

    /// Horizontal distance a ball travels before first touching the ground,
    /// launched at `speed` m/s, `elevation` radians above horizontal, from
    /// `height` metres up.
    static func carry(speed v: Double, elevation θ: Double, height h: Double) -> Double {
        guard v > 0 else { return 0 }
        let vy = v * sin(θ)
        let vx = v * cos(θ)
        let disc = vy * vy + 2 * g * max(h, 0)
        guard disc >= 0 else { return 0 }
        let t = (vy + disc.squareRoot()) / g
        return max(0, vx * t)
    }

    /// How far a ball rolls on grass from `speed` m/s along the ground before
    /// stopping. v² / 2μg with an effective μ of 0.5 — higher than sliding
    /// friction because a struck ball skips and bounces before it rolls, and
    /// each bounce eats speed.
    static func roll(speed v: Double) -> Double {
        (v * v) / (2 * 0.5 * g)
    }

    /// Signed spin effect: +1 is full topspin (dips hard), -1 full backspin
    /// (floats), 0 none. Magnus force goes along `ω × v`; topspin is the case
    /// where that points down.
    static func topspin(of shot: Shot, saturatingAt rate: Double = 25) -> Double {
        guard shot.spinRate > 1e-3,
              let axis = shot.spinAxis.normalized,
              let dir = shot.direction.normalized
        else { return 0 }
        let magnus = axis.cross(dir)
        // Only the fraction of the spin that is actually about a horizontal
        // axis perpendicular to travel produces lift or dip; the rest is
        // sidespin or rifle spin and is ignored here.
        let lever = -magnus.y
        let strength = min(shot.spinRate / rate, 1)
        return (lever * strength).clamped(to: -1...1)
    }

    /// Where a ball lands, given the swing and how well it was struck.
    public struct Flight: Hashable, Sendable {
        /// Horizontal angle, degrees, from straight down the target line.
        /// Positive is to the player's right in the play frame.
        public var angle: Double
        public var speed: Double
        public var elevation: Double
        public var carry: Double
        public var total: Double
        public var lofted: Bool

        public func landing() -> (x: Double, z: Double) {
            let a = angle.radians
            return (carry * cos(a), carry * sin(a))
        }
    }

    /// The flight of a ball struck by `shot`. `exitSpeed` is the ball's speed
    /// off the bat or racket, already scaled by the sport; `angleShift` is the
    /// sport's opinion of how early or late timing steers the ball.
    static func flight(
        of shot: Shot,
        exitSpeed: Double,
        angleShift: Double,
        contactHeight: Double,
        loftThreshold: Double = 18
    ) -> Flight {
        let baseAngle = (shot.direction.horizontalAngle ?? 0).degrees
        let elevation = shot.direction.elevation.degrees
        let spin = topspin(of: shot)
        // Topspin pulls a ball down (shorter), backspin holds it up (longer).
        let spinFactor = 1 - 0.25 * spin
        let launch = max(elevation, 0)
        let carry = Ballistics.carry(speed: exitSpeed, elevation: launch.radians, height: contactHeight) * spinFactor
        let lofted = elevation > loftThreshold
        // A ball along the ground carries very little but keeps most of its
        // speed for the roll; a lofted one has spent its energy climbing.
        let rollSpeed = exitSpeed * (lofted ? 0.35 : 0.85) * cos(launch.radians)
        let total = carry + roll(speed: rollSpeed)
        return Flight(
            angle: baseAngle + angleShift,
            speed: exitSpeed,
            elevation: elevation,
            carry: carry,
            total: total,
            lofted: lofted
        )
    }
}
