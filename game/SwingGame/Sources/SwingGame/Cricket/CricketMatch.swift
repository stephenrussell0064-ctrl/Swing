import Foundation

/// A short match: you bat an over or two, then you bowl the same, and the
/// higher total wins. Pure state — the app drives it.
public struct CricketMatch: Hashable, Sendable {

    public struct Innings: Hashable, Sendable {
        public var runs = 0
        public var wickets = 0
        /// Legal balls faced or bowled.
        public var balls = 0
        public var extras = 0

        public init() {}

        public var overs: String {
            "\(balls / 6).\(balls % 6)"
        }
    }

    public enum Phase: Hashable, Sendable {
        case batting
        case bowling
        case finished
    }

    public var oversPerSide: Int
    public var wicketsPerSide: Int
    public var seed: UInt64
    public var batter: Batter

    public var phase: Phase = .batting
    public var yours = Innings()
    public var theirs = Innings()
    /// Counts every delivery including wides, so the generator never repeats.
    public private(set) var deliveriesBowled = 0
    public private(set) var ballsBowledByYou = 0

    public init(
        oversPerSide: Int = 1,
        wicketsPerSide: Int = 3,
        seed: UInt64 = 0x5EED,
        batter: Batter = .club
    ) {
        self.oversPerSide = oversPerSide
        self.wicketsPerSide = wicketsPerSide
        self.seed = seed
        self.batter = batter
    }

    public var ballsPerInnings: Int { oversPerSide * 6 }

    /// The next ball you face. Same match, same balls.
    public func nextDelivery() -> Delivery {
        Delivery.generated(ballIndex: deliveriesBowled, seed: seed)
    }

    /// The batter you bowl to: index for the luck stream.
    public var nextBowlingIndex: Int { ballsBowledByYou }

    public mutating func record(_ result: BattingResult) {
        precondition(phase == .batting, "not batting")
        deliveriesBowled += 1
        yours.runs += result.outcome.runs
        if result.outcome == .wide { yours.extras += 1 }
        if result.outcome.countsAsBall { yours.balls += 1 }
        if result.outcome.isWicket { yours.wickets += 1 }
        if yours.balls >= ballsPerInnings || yours.wickets >= wicketsPerSide {
            phase = .bowling
        }
    }

    public mutating func record(_ result: BowlingResult) {
        precondition(phase == .bowling, "not bowling")
        ballsBowledByYou += 1
        theirs.runs += result.outcome.runsConceded
        if !result.outcome.countsAsBall { theirs.extras += 1 }
        if result.outcome.countsAsBall { theirs.balls += 1 }
        if result.outcome.isWicket { theirs.wickets += 1 }
        if theirs.balls >= ballsPerInnings || theirs.wickets >= wicketsPerSide || theirs.runs > yours.runs {
            phase = .finished
        }
    }

    public enum Result: Hashable, Sendable {
        case youWon(by: Int)
        case theyWon(wicketsInHand: Int)
        case tie
    }

    public var result: Result? {
        guard phase == .finished else { return nil }
        if theirs.runs > yours.runs { return .theyWon(wicketsInHand: wicketsPerSide - theirs.wickets) }
        if yours.runs > theirs.runs { return .youWon(by: yours.runs - theirs.runs) }
        return .tie
    }

    /// Spoken between balls. Short, because the next ball is coming.
    public var scoreAnnouncement: String {
        switch phase {
        case .batting:
            return "\(yours.runs) for \(yours.wickets), \(yours.overs) overs."
        case .bowling:
            let need = yours.runs - theirs.runs + 1
            let left = ballsPerInnings - theirs.balls
            return "They're \(theirs.runs) for \(theirs.wickets). They need \(max(need, 0)) from \(left)."
        case .finished:
            switch result {
            case .youWon(let by)?: return "You won by \(by) run\(by == 1 ? "" : "s")."
            case .theyWon(let w)?: return "They won, with \(w) wicket\(w == 1 ? "" : "s") in hand."
            case .tie?: return "A tie!"
            case nil: return ""
            }
        }
    }

    /// Spoken once, when the innings turns over.
    public var phaseAnnouncement: String {
        switch phase {
        case .batting: return "You're batting. Point the phone at the bowler and wait for the run-up."
        case .bowling: return "Innings over. You made \(yours.runs). Now bowl. Point the phone at the stumps, then bowl when you're ready."
        case .finished: return scoreAnnouncement
        }
    }
}
