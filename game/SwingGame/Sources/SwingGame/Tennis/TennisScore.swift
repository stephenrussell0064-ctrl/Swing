import Foundation

public enum Player: String, Hashable, Sendable, CaseIterable {
    case you, opponent

    public var other: Player { self == .you ? .opponent : .you }
}

/// Points, games, one set. Announced your score first, always — you are the
/// one who cannot see it.
public struct TennisScore: Hashable, Sendable {
    public var points: [Player: Int] = [.you: 0, .opponent: 0]
    public var games: [Player: Int] = [.you: 0, .opponent: 0]
    public var server: Player
    public var gamesToWin: Int

    public init(server: Player = .you, gamesToWin: Int = 6) {
        self.server = server
        self.gamesToWin = gamesToWin
    }

    public enum Event: Hashable, Sendable {
        case point
        case game(Player)
        case set(Player)
    }

    public var isOver: Bool { winner != nil }

    public var winner: Player? {
        for p in Player.allCases {
            let mine = games[p]!, theirs = games[p.other]!
            // Win by two, or first to gamesToWin + 1 (a 7–6 without a
            // tiebreak, for now).
            if mine >= gamesToWin && (mine - theirs >= 2 || mine == gamesToWin + 1) { return p }
        }
        return nil
    }

    @discardableResult
    public mutating func point(to p: Player) -> Event {
        precondition(!isOver, "set is over")
        points[p]! += 1
        let mine = points[p]!, theirs = points[p.other]!
        if mine >= 4 && mine - theirs >= 2 {
            games[p]! += 1
            points = [.you: 0, .opponent: 0]
            server = server.other
            return isOver ? .set(p) : .game(p)
        }
        return .point
    }

    /// "Fifteen, love." "Deuce." "Advantage you."
    public var pointAnnouncement: String {
        let y = points[.you]!, o = points[.opponent]!
        if y >= 3 && o >= 3 {
            if y == o { return "Deuce." }
            return y > o ? "Advantage you." : "Advantage them."
        }
        func word(_ n: Int) -> String {
            switch n {
            case 0: "love"
            case 1: "fifteen"
            case 2: "thirty"
            default: "forty"
            }
        }
        if y == o { return y == 0 ? "Love all." : "\(word(y).capitalized) all." }
        return "\(word(y).capitalized), \(word(o))."
    }

    public var gameAnnouncement: String {
        let y = games[.you]!, o = games[.opponent]!
        if let w = winner {
            return w == .you ? "Game, set. You win, \(y) games to \(o)." : "Game, set. They win, \(o) games to \(y)."
        }
        let lead = y == o ? "Games level" : (y > o ? "You lead" : "They lead")
        let serving = server == .you ? "You serve." : "They serve."
        return "\(lead), \(max(y, o)) to \(min(y, o)). \(serving)"
    }
}
