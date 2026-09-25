import Foundation
import SwingCore

/// Which hand holds the phone. It flips the meaning of the play frame's `z`:
/// a right-hander's off side is their right; a left-hander's is their left.
public enum Handedness: String, Codable, Hashable, Sendable, CaseIterable {
    case right, left

    /// +1 for right, -1 for left. Multiply a `z` by this to get "toward the
    /// dominant side" regardless of which hand is swinging.
    var sign: Double { self == .right ? 1 : -1 }

    /// The shot as a right-hander would have made it, so every sport can be
    /// written once for the right hand.
    func asRightHanded(_ shot: Shot) -> Shot {
        self == .right ? shot : shot.mirroredAcrossTargetLine()
    }
}

extension Shot {
    /// The same motion made by the other hand: reflected in the vertical
    /// plane through the target line.
    ///
    /// Directions flip their sideways component. The spin axis does the
    /// opposite — it is an axial vector, so a reflection flips the *other*
    /// two components. Topspin on a right-hander's forehand is still topspin
    /// on a left-hander's; get this wrong and a mirrored player's topspin
    /// becomes slice.
    func mirroredAcrossTargetLine() -> Shot {
        var s = self
        s.direction.z = -s.direction.z
        s.spinAxis.x = -s.spinAxis.x
        s.spinAxis.y = -s.spinAxis.y
        // Attitude is left alone: nothing here reads it yet, and mirroring a
        // quaternion properly is a decision for when something does.
        return s
    }
}

extension Vector3 {
    /// Angle in the horizontal plane, radians, from straight down the target
    /// line. Positive is to the player's right. `nil` if the vector has no
    /// horizontal component worth speaking of.
    var horizontalAngle: Double? {
        let h = (x * x + z * z).squareRoot()
        guard h > 1e-6 else { return nil }
        return atan2(z, x)
    }

    /// Angle above the horizontal, radians. Positive is up.
    var elevation: Double {
        let h = (x * x + z * z).squareRoot()
        return atan2(y, h)
    }
}

extension Double {
    var degrees: Double { self * 180 / .pi }
    var radians: Double { self * .pi / 180 }

    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
