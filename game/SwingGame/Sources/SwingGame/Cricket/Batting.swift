import Foundation
import SwingCore

public enum BattingOutcome: Hashable, Sendable {
    case bowled
    case caught(by: String)
    /// No runs: left alone, beaten, defended, or fielded.
    case dot
    case runs(Int)
    case four
    case six
    /// The umpire's call, not yours. One run, no ball faced.
    case wide

    public var runs: Int {
        switch self {
        case .runs(let n): n
        case .four: 4
        case .six: 6
        case .wide: 1
        case .bowled, .caught, .dot: 0
        }
    }

    public var isWicket: Bool {
        switch self {
        case .bowled, .caught: true
        default: false
        }
    }

    /// A wide is not a ball faced.
    public var countsAsBall: Bool { self != .wide }
}

public struct BattingResult: Hashable, Sendable {
    public enum Contact: String, Hashable, Sendable {
        case middled, edged, missed, noShot
    }

    public var outcome: BattingOutcome
    public var contact: Contact
    /// `nil` when no swing was made.
    public var timing: Timing?
    public var flight: Ballistics.Flight?
    /// What the phone says out loud. The player's eyes are not on it.
    public var announcement: String
    /// What the hand feels the instant the result is known.
    public var haptic: HapticScript
}

/// Bat meets ball. A pure function: this `Shot`, this `Delivery`, this
/// `Cue`, this result, every time.
public enum Batting {

    /// Bat speed to ball speed, for a middled hit. The bat is heavy and the
    /// ball is coming the other way, so the ball leaves faster than the bat.
    static let batToBall = 1.25
    /// How much of the bowler's pace comes back off the bat.
    static let paceReturned = 0.30
    /// Degrees the ball is steered per unit of timing error (one tolerance
    /// width). Early pulls it to leg, late pushes it to off.
    static let steerPerTolerance = 40.0
    /// Bat height at contact, metres.
    static let contactHeight = 0.6

    public static func play(
        shot: Shot?,
        delivery: Delivery,
        cue: Cue,
        field: Field = .standard,
        handedness: Handedness = .right
    ) -> BattingResult {
        if delivery.isWide {
            return BattingResult(
                outcome: .wide, contact: .noShot, timing: nil, flight: nil,
                announcement: "Wide.",
                haptic: HapticVocabulary.tick.script
            )
        }

        guard let shot else {
            return noContact(delivery, timing: nil, contact: .noShot)
        }

        let timing = cue.timing(of: shot)
        if timing.missed {
            return noContact(delivery, timing: timing, contact: .missed)
        }

        // The swing, with "off side" made positive whichever hand is swinging.
        let swingShot = handedness.asRightHanded(shot)

        // Reaching for a ball well outside the stumps costs contact quality;
        // a straight bat is the safe shot, as it is in real cricket.
        let reach = (1 - max(0, abs(delivery.line) - 0.35) / 0.6).clamped(to: 0.3...1)
        let quality = timing.quality * reach

        // Early (negative error) means the bat has come round further by the
        // time the ball arrives: leg side, negative angle. Late is off side.
        let steer = (timing.error / timing.tolerance) * steerPerTolerance
        let exitSpeed = (shot.releaseSpeed * batToBall + delivery.pace * paceReturned) * quality

        if quality < 0.45 {
            return edged(shot: swingShot, delivery: delivery, timing: timing, quality: quality, exitSpeed: exitSpeed, field: field)
        }

        let flight = Ballistics.flight(
            of: swingShot,
            exitSpeed: exitSpeed,
            angleShift: steer,
            contactHeight: contactHeight
        )
        return score(flight: flight, timing: timing, contact: .middled, field: field)
    }

    // MARK: -

    private static func noContact(_ delivery: Delivery, timing: Timing?, contact: BattingResult.Contact) -> BattingResult {
        if delivery.isStraight {
            return BattingResult(
                outcome: .bowled, contact: contact, timing: timing, flight: nil,
                announcement: contact == .noShot ? "Bowled! You didn't play a shot." : "Bowled him!",
                haptic: HapticVocabulary.miss
            )
        }
        let words: String
        switch (contact, timing?.grade) {
        case (.noShot, _): words = "Left alone. Dot ball."
        case (_, .tooEarly?): words = "Swung too early. Dot ball."
        case (_, .tooLate?): words = "Beaten for pace. Dot ball."
        default: words = "Missed it. Dot ball."
        }
        return BattingResult(
            outcome: .dot, contact: contact, timing: timing, flight: nil,
            announcement: words,
            haptic: HapticVocabulary.miss
        )
    }

    private static func edged(
        shot: Shot, delivery: Delivery, timing: Timing, quality: Double, exitSpeed: Double, field: Field
    ) -> BattingResult {
        // An edge squirts behind square on the off side, off the outside of
        // the bat, and does not carry far. Thin ones carry to the keeper.
        let angle = 130.0
        let thin = quality < 0.2
        if thin {
            return BattingResult(
                outcome: .caught(by: "wicketkeeper"), contact: .edged, timing: timing, flight: nil,
                announcement: "Edged, and caught behind!",
                haptic: HapticVocabulary.mishit
            )
        }
        var edgedShot = shot
        edgedShot.direction = Vector3(cos(angle.radians), 0.15, sin(angle.radians))
        let flight = Ballistics.flight(
            of: edgedShot,
            exitSpeed: exitSpeed * 0.6,
            angleShift: 0,
            contactHeight: contactHeight,
            loftThreshold: 90 // an edge never counts as a lofted shot
        )
        var result = score(flight: flight, timing: timing, contact: .edged, field: field)
        result.haptic = HapticVocabulary.mishit
        result.announcement = "Edged. " + result.announcement
        return result
    }

    private static func score(
        flight: Ballistics.Flight, timing: Timing, contact: BattingResult.Contact, field: Field
    ) -> BattingResult {
        if flight.lofted {
            if flight.carry >= field.boundary {
                return BattingResult(
                    outcome: .six, contact: contact, timing: timing, flight: flight,
                    announcement: "Six! That's gone all the way.",
                    haptic: HapticVocabulary.celebration
                )
            }
            if let fielder = field.catcher(landingAt: flight.landing()) {
                return BattingResult(
                    outcome: .caught(by: fielder.name), contact: contact, timing: timing, flight: flight,
                    announcement: "Caught, at \(fielder.name)!",
                    haptic: HapticVocabulary.mishit
                )
            }
        }

        if flight.total >= field.boundary {
            return BattingResult(
                outcome: .four, contact: contact, timing: timing, flight: flight,
                announcement: "Four!",
                haptic: HapticVocabulary.celebration
            )
        }

        if let stopper = field.stopper(angle: flight.angle, total: flight.total) {
            // Fielded. If it was struck well past them you still get one.
            let runs = flight.total > stopper.distance + 15 ? 1 : 0
            return BattingResult(
                outcome: runs == 0 ? .dot : .runs(runs), contact: contact, timing: timing, flight: flight,
                announcement: runs == 0 ? "Straight to \(stopper.name). Dot ball." : "Past \(stopper.name), one run.",
                haptic: HapticVocabulary.cleanStrike
            )
        }

        let runs: Int
        switch flight.total {
        case ..<12: runs = 0
        case ..<34: runs = 1
        case ..<52: runs = 2
        default: runs = 3
        }
        let words: String
        switch runs {
        case 0: words = "Defended. Dot ball."
        case 1: words = "One run."
        case 2: words = "Two runs."
        default: words = "Three runs!"
        }
        return BattingResult(
            outcome: runs == 0 ? .dot : .runs(runs), contact: contact, timing: timing, flight: flight,
            announcement: words,
            haptic: HapticVocabulary.cleanStrike
        )
    }
}

extension HapticEvent {
    /// A one-event script, for outcomes that are a single feel.
    var script: HapticScript {
        HapticScript(entries: [.init(at: 0, event: self)], contactAt: 0)
    }
}
