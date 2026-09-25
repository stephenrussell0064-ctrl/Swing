import Foundation
import SwingCore

/// Where your ball landed on the far side, if it did.
public struct Placement: Hashable, Sendable {
    /// Metres from the centre line, positive to your right.
    public var lateral: Double
    /// 0 at the net, 1 on their baseline.
    public var depth: Double
    /// m/s off your racket.
    public var speed: Double
    /// How good a shot it was for the opponent to deal with, 0...1.
    public var quality: Double
}

public enum StrokeOutcome: Hashable, Sendable {
    /// Swung and missed, or did not swing.
    case miss
    case net
    case outLong
    case outWide
    case inPlay(Placement)

    public var isIn: Bool {
        if case .inPlay = self { return true }
        return false
    }
}

public struct StrokeResult: Hashable, Sendable {
    public var outcome: StrokeOutcome
    public var timing: Timing?
    public var announcement: String
    public var haptic: HapticScript
}

/// Racket meets ball. Pure.
public enum Stroke {

    /// Racket-hand speed with a phone in it to ball speed. Strings are a
    /// trampoline and the ball is already coming.
    static let racketToBall = 1.4
    static let paceReturned = 0.25
    /// Metres of lateral steer per unit of timing error. Early on a forehand
    /// goes cross-court, late goes down the line.
    static let steerPerTolerance = 2.8
    static let contactHeight = 1.0
    /// Below this launch angle the ball goes into the net, whatever its speed.
    static let netClearance = -3.0
    /// The ball leaves along the racket *face*, not the hand's path. A
    /// groundstroke swings low-to-high at 20° or more and the ball comes off
    /// at 5–10°, so the hand's elevation is compressed, and a face is
    /// naturally a little open.
    static let launchPerElevation = 0.5
    static let launchOffset = 3.0

    public static func returnBall(
        shot: Shot?,
        ball: IncomingBall,
        cue: Cue,
        handedness: Handedness = .right
    ) -> StrokeResult {
        guard let shot else {
            return StrokeResult(outcome: .miss, timing: nil, announcement: "Let it go.", haptic: HapticVocabulary.miss)
        }
        let timing = cue.timing(of: shot)
        if timing.missed {
            let words = timing.grade == .tooEarly ? "Too early. Missed it." : "Too late. Missed it."
            return StrokeResult(outcome: .miss, timing: timing, announcement: words, haptic: HapticVocabulary.miss)
        }

        // Make "dominant side" positive so a left-hander plays the same game.
        let s = handedness.asRightHanded(shot)

        // Note what is *not* checked: whether the swing was a forehand or a
        // backhand. The direction of travel cannot tell them apart from an
        // angled shot — on a court four metres wide, any swing across the
        // body far enough to count as "the wrong stroke" is already wide.
        // `Shot.attitude` (which way the face pointed) probably can, but not
        // until there are recorded forehands and backhands to look at.
        var quality = timing.quality

        // Forehand early → toward the non-dominant side (cross-court), late →
        // dominant side (down the line). Backhand is mirrored.
        let sideSign = ball.side == .forehand ? 1.0 : -1.0
        let steer = (timing.error / timing.tolerance) * steerPerTolerance * sideSign

        let exitSpeed = (shot.releaseSpeed * racketToBall * (0.55 + 0.45 * quality)) + ball.pace * paceReturned
        return land(
            shot: s, exitSpeed: exitSpeed, steer: steer, quality: &quality, timing: timing,
            contactHeight: contactHeight, mustClear: IncomingBall.netDistance, mustNotPass: IncomingBall.courtLength
        )
    }

    /// Your serve. Must land in the far service box.
    public static func serve(shot: Shot?, cue: Cue, handedness: Handedness = .right) -> StrokeResult {
        guard let shot else {
            return StrokeResult(outcome: .miss, timing: nil, announcement: "Missed the toss. Fault.", haptic: HapticVocabulary.miss)
        }
        let timing = cue.timing(of: shot)
        if timing.missed {
            return StrokeResult(outcome: .miss, timing: timing, announcement: "Missed the toss. Fault.", haptic: HapticVocabulary.miss)
        }
        let s = handedness.asRightHanded(shot)
        var quality = timing.quality
        let exitSpeed = shot.releaseSpeed * racketToBall * 1.15 * (0.6 + 0.4 * quality)
        var result = land(
            shot: s, exitSpeed: exitSpeed, steer: 0, quality: &quality, timing: timing,
            contactHeight: Serve.contactHeight, mustClear: IncomingBall.netDistance, mustNotPass: IncomingBall.serviceLine
        )
        switch result.outcome {
        case .outLong: result.announcement = "Long. Fault."
        case .outWide: result.announcement = "Wide. Fault."
        case .net: result.announcement = "Net. Fault."
        case .inPlay(let p) where p.quality > 0.85: result.announcement = "Big serve."
        case .inPlay: result.announcement = "Good serve."
        case .miss: break
        }
        return result
    }

    // MARK: -

    private static func land(
        shot: Shot, exitSpeed: Double, steer: Double, quality: inout Double, timing: Timing,
        contactHeight: Double, mustClear: Double, mustNotPass: Double
    ) -> StrokeResult {
        let launch = shot.direction.elevation.degrees * launchPerElevation + launchOffset
        if launch < netClearance {
            return StrokeResult(outcome: .net, timing: timing, announcement: "Into the net.", haptic: HapticVocabulary.mishit)
        }
        let spin = Ballistics.topspin(of: shot)
        // Topspin dips, so it can be hit harder and still land; slice floats.
        let spinFactor = 1 - 0.30 * spin
        let carry = Ballistics.carry(speed: exitSpeed, elevation: launch.radians, height: contactHeight) * spinFactor

        if carry <= mustClear {
            return StrokeResult(outcome: .net, timing: timing, announcement: "Into the net.", haptic: HapticVocabulary.mishit)
        }
        if carry > mustNotPass {
            return StrokeResult(outcome: .outLong, timing: timing, announcement: "Long.", haptic: HapticVocabulary.mishit)
        }
        let angle = shot.direction.horizontalAngle ?? 0
        let lateral = carry * tan(angle.clamped(to: -0.6...0.6)) + steer
        if abs(lateral) > IncomingBall.halfWidth {
            return StrokeResult(outcome: .outWide, timing: timing, announcement: "Wide.", haptic: HapticVocabulary.mishit)
        }

        let depth = ((carry - mustClear) / (mustNotPass - mustClear)).clamped(to: 0...1)
        // Deep and fast is hard to return; short and slow is a gift. Angle
        // helps too, up to the point where it would have gone wide.
        let angleBonus = (abs(lateral) / IncomingBall.halfWidth) * 0.15
        quality = (quality * (0.55 + 0.45 * depth) * min(exitSpeed / 30, 1) + angleBonus).clamped(to: 0...1)

        let placement = Placement(lateral: lateral, depth: depth, speed: exitSpeed, quality: quality)
        let words: String
        switch quality {
        case 0.8...: words = "Great shot."
        case 0.5...: words = "In."
        default: words = "In, but short."
        }
        return StrokeResult(
            outcome: .inPlay(placement),
            timing: timing,
            announcement: words,
            haptic: quality < 0.35 ? HapticVocabulary.mishit : HapticVocabulary.cleanStrike
        )
    }
}
