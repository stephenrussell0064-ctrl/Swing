import Foundation
import SwingCore

/// One ball, bowled at the player.
///
/// The player cannot see it. What they get is a haptic script: the bowler's
/// run-up as a quickening count, a soft tap at release, a hard tap at the
/// bounce, and then silence — the swing goes into the silence, exactly as a
/// real one is timed off the bounce.
public struct Delivery: Hashable, Sendable {

    public enum Bowler: String, Hashable, Sendable, CaseIterable {
        case fast, medium, spin

        /// Run-up length in seconds. A spinner ambles; a quick bowler charges.
        var runUp: TimeInterval {
            switch self {
            case .fast: 1.8
            case .medium: 1.4
            case .spin: 0.9
            }
        }

        var steps: Int {
            switch self {
            case .fast: 5
            case .medium: 4
            case .spin: 2
            }
        }
    }

    public enum Length: String, Hashable, Sendable, CaseIterable {
        case short, good, full, yorker, fullToss

        /// For the screen and the voice.
        public var spoken: String {
            switch self {
            case .short: "short"
            case .good: "good length"
            case .full: "full"
            case .yorker: "yorker"
            case .fullToss: "full toss"
            }
        }

        /// Where along the flight the ball pitches, 0 = at release, 1 = at
        /// the bat. A yorker bounces at your feet; a short ball bounces early
        /// and comes up at you.
        var bounceFraction: Double {
            switch self {
            case .short: 0.45
            case .good: 0.62
            case .full: 0.78
            case .yorker: 0.94
            case .fullToss: 1.0
            }
        }
    }

    public var bowler: Bowler
    /// Metres from middle stump at the batter, positive toward the batter's
    /// off side. Stumps are 0.23 m wide; anything within ±0.15 hits them.
    public var line: Double
    public var length: Length
    /// m/s at release. Fast 35–40, medium 28–33, spin 18–24.
    public var pace: Double

    public init(bowler: Bowler, line: Double, length: Length, pace: Double) {
        self.bowler = bowler
        self.line = line
        self.length = length
        self.pace = pace
    }

    /// Distance from the bowler's hand to the bat, metres. A 20.12 m pitch,
    /// less the bowler's stride and the batter's stance.
    static let flightDistance = 17.5

    /// Release to bat. The ball loses speed off the pitch, so it is a little
    /// slower than distance over pace.
    public var flightTime: TimeInterval {
        Delivery.flightDistance / max(pace, 5) * 1.12
    }

    /// A slower ball is easier to time — the window scales with flight time,
    /// clamped so a spinner is not trivially easy and a quick is possible.
    public var tolerance: TimeInterval {
        (flightTime * 0.17).clamped(to: 0.09...0.17)
    }

    public var isStraight: Bool { abs(line) <= 0.15 }

    /// Wide enough that the umpire calls it: no shot needed, one run to you.
    public var isWide: Bool { abs(line) > 0.95 }

    /// What the hand feels between "here it comes" and the moment to swing.
    public func script() -> HapticScript {
        var entries: [HapticScript.Entry] = []
        // Run-up: taps that get closer together, like footsteps speeding up.
        let steps = bowler.steps
        for i in 0..<steps {
            let f = Double(i) / Double(steps)
            // Ease-in: the gaps shrink as the bowler nears the crease.
            let at = bowler.runUp * (1 - (1 - f) * (1 - f))
            entries.append(.init(at: at, event: HapticVocabulary.tick))
        }
        let release = bowler.runUp
        entries.append(.init(at: release, event: HapticVocabulary.released))
        if length != .fullToss {
            entries.append(.init(at: release + flightTime * length.bounceFraction, event: HapticVocabulary.bounce))
        }
        return HapticScript(entries: entries, contactAt: release + flightTime)
    }
}

extension Delivery {
    /// The over the phone bowls at you. Deterministic from the seed, so the
    /// same match can be replayed and the same ball can be argued about.
    public static func generated(ballIndex: Int, seed: UInt64) -> Delivery {
        let luck = Luck(seed: seed)
        let a = luck.draw(ballIndex, stream: 1)
        let b = luck.draw(ballIndex, stream: 2)
        let c = luck.draw(ballIndex, stream: 3)

        let bowler: Bowler = a < 0.45 ? .fast : (a < 0.75 ? .medium : .spin)
        let pace: Double
        switch bowler {
        case .fast: pace = 34 + b * 6
        case .medium: pace = 28 + b * 5
        case .spin: pace = 18 + b * 6
        }
        let length: Length
        switch c {
        case ..<0.20: length = .short
        case ..<0.65: length = .good
        case ..<0.88: length = .full
        case ..<0.97: length = .yorker
        default: length = .fullToss
        }
        // Mostly at or around the stumps, occasionally straying.
        let lineDraw = luck.draw(ballIndex, stream: 4)
        let line = (lineDraw - 0.5) * 1.4
        return Delivery(bowler: bowler, line: line, length: length, pace: pace)
    }
}
