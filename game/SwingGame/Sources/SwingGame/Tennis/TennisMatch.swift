import Foundation
import SwingCore

/// One set against the phone. Pure state; the app owns the clock, the haptics
/// and the waiting. Every transition here is a function of a `Shot` (or its
/// absence) and returns what to say and what to play next.
public struct TennisMatch: Hashable, Sendable {

    public enum State: Hashable, Sendable {
        /// Waiting for you to serve. `second` after a fault.
        case yourServe(second: Bool)
        /// The ball is coming (their serve, or their return).
        case incoming(IncomingBall, stroke: Int)
        case over(Player)
    }

    public var score: TennisScore
    public var opponent: Opponent
    public var handedness: Handedness
    public var seed: UInt64
    public private(set) var state: State
    public private(set) var pointIndex = 0

    public init(
        opponent: Opponent = .clubPlayer,
        handedness: Handedness = .right,
        server: Player = .you,
        gamesToWin: Int = 4,
        seed: UInt64 = 0x7E77
    ) {
        self.opponent = opponent
        self.handedness = handedness
        self.seed = seed
        self.score = TennisScore(server: server, gamesToWin: gamesToWin)
        self.state = server == .you
            ? .yourServe(second: false)
            : .incoming(opponent.serve(pointIndex: 0, seed: seed), stroke: 0)
    }

    /// What to feel next, and the tolerance to judge the swing by, for a
    /// player with this swing.
    public func nextScript(for profile: SwingProfile) -> (script: HapticScript, tolerance: TimeInterval)? {
        switch state {
        case .yourServe: (Serve.script(for: profile), Serve.tolerance(for: profile))
        case .incoming(let ball, _): (ball.script(for: profile), ball.tolerance(for: profile))
        case .over: nil
        }
    }

    /// What to say before the script plays, if anything.
    public var prompt: String? {
        switch state {
        case .yourServe(let second): second ? "Second serve." : "Your serve."
        case .incoming(let ball, _): ball.announcement
        case .over: nil
        }
    }

    public struct Step: Hashable, Sendable {
        public var stroke: StrokeResult
        /// Spoken after the stroke's own announcement. Score, or "game".
        public var announcement: String?
        public var event: TennisScore.Event?
        /// True when the rally continues and the next ball should follow
        /// after its own flight time rather than after a pause.
        public var rallyContinues: Bool
    }

    /// Feed in what the hand did (or `nil` if it did nothing before the
    /// deadline). Advances the match.
    @discardableResult
    public mutating func play(_ shot: Shot?, cue: Cue) -> Step {
        switch state {
        case .over:
            preconditionFailure("match is over")

        case .yourServe(let second):
            let result = Stroke.serve(shot: shot, cue: cue, handedness: handedness)
            if case .inPlay(let placement) = result.outcome {
                return continueRally(after: result, placement: placement, stroke: 0)
            }
            if second {
                var r = result
                r.announcement += " Double fault."
                return endPoint(winner: .opponent, stroke: r)
            }
            state = .yourServe(second: true)
            return Step(stroke: result, announcement: nil, event: nil, rallyContinues: false)

        case .incoming(let ball, let stroke):
            let result = Stroke.returnBall(shot: shot, ball: ball, cue: cue, handedness: handedness)
            if case .inPlay(let placement) = result.outcome {
                return continueRally(after: result, placement: placement, stroke: stroke + 1)
            }
            return endPoint(winner: .opponent, stroke: result)
        }
    }

    private mutating func continueRally(after result: StrokeResult, placement: Placement, stroke: Int) -> Step {
        if let reply = opponent.reply(to: placement, pointIndex: pointIndex, stroke: stroke, seed: seed) {
            state = .incoming(reply, stroke: stroke)
            return Step(stroke: result, announcement: nil, event: nil, rallyContinues: true)
        }
        var r = result
        r.announcement = placement.quality > 0.8 ? "Winner!" : "They couldn't get it back."
        r.haptic = HapticVocabulary.celebration
        return endPoint(winner: .you, stroke: r)
    }

    private mutating func endPoint(winner: Player, stroke: StrokeResult) -> Step {
        let event = score.point(to: winner)
        pointIndex += 1
        let announcement: String
        switch event {
        case .point:
            announcement = score.pointAnnouncement
        case .game:
            announcement = "Game. " + score.gameAnnouncement
        case .set(let p):
            announcement = score.gameAnnouncement
            state = .over(p)
            return Step(stroke: stroke, announcement: announcement, event: event, rallyContinues: false)
        }
        state = score.server == .you
            ? .yourServe(second: false)
            : .incoming(opponent.serve(pointIndex: pointIndex, seed: seed), stroke: 0)
        return Step(stroke: stroke, announcement: announcement, event: event, rallyContinues: false)
    }
}
