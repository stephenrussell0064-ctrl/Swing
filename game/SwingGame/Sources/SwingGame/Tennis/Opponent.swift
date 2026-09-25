import Foundation

/// The player across the net. Skill 0...1: how good a ball it can get back.
public struct Opponent: Hashable, Sendable {
    public var skill: Double

    public init(skill: Double) { self.skill = skill.clamped(to: 0...1) }

    public static let clubPlayer = Opponent(skill: 0.5)
    public static let coach = Opponent(skill: 0.75)

    /// What comes back after your ball landed at `placement`, or `nil` if the
    /// opponent could not get to it and you have won the point.
    ///
    /// `pointIndex` and `stroke` seed the luck so a rally replays identically.
    public func reply(
        to placement: Placement,
        pointIndex: Int,
        stroke: Int,
        seed: UInt64
    ) -> IncomingBall? {
        let luck = Luck(seed: seed ^ UInt64(pointIndex) &* 0x100_0000_01B3)
        let reach = luck.draw(stroke, stream: 1)
        // A better shot from you is harder to reach; a bit of luck either way.
        let difficulty = placement.quality * (0.75 + 0.5 * reach)
        if difficulty > skill + 0.25 {
            return nil
        }
        let sideDraw = luck.draw(stroke, stream: 2)
        let side: IncomingBall.Side = sideDraw < 0.55 ? .forehand : .backhand
        // A weak ball from you gets punished: they hit harder and deeper.
        let punish = 1 - placement.quality
        let pace = 17 + skill * 10 + punish * 8 + luck.draw(stroke, stream: 3) * 4
        let depth = 0.35 + punish * 0.35 + luck.draw(stroke, stream: 4) * 0.3
        return IncomingBall(side: side, pace: pace, depth: depth)
    }

    /// Their serve. Always to the same place in the mind of the hand — a
    /// serve is a serve — but the pace varies.
    public func serve(pointIndex: Int, seed: UInt64) -> IncomingBall {
        let luck = Luck(seed: seed ^ UInt64(pointIndex) &* 0x100_0000_01B3)
        let pace = 22 + skill * 12 + luck.draw(0, stream: 5) * 6
        let side: IncomingBall.Side = luck.draw(0, stream: 6) < 0.6 ? .forehand : .backhand
        return IncomingBall(side: side, pace: pace, depth: 0.75, isServe: true)
    }
}
