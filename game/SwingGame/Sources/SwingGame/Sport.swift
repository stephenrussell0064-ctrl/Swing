import Foundation

/// The catalogue. What the player picks from before they stand up.
///
/// Sports not yet playable are listed anyway so the shape of the menu is
/// honest about where the app is going and nobody builds a two-item menu that
/// has to be redesigned at three.
public enum Sport: String, CaseIterable, Identifiable, Hashable, Sendable {
    case golf, cricket, tennis, bowling, darts

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .golf: "Golf"
        case .cricket: "Cricket"
        case .tennis: "Tennis"
        case .bowling: "Bowling"
        case .darts: "Darts"
        }
    }

    /// One line for the menu, written for someone who has never played and
    /// owns nothing but a phone.
    public var blurb: String {
        switch self {
        case .golf: "Point down the fairway, swing. The phone is the club."
        case .cricket: "Bat an over, then bowl one. Feel the ball come at you."
        case .tennis: "Rally against the phone. It tells your hand when to swing."
        case .bowling: "Roll it. The phone is the ball."
        case .darts: "Throw. Gently, and hold on."
        }
    }

    /// Golf lives with the motion half and is not on this branch yet. Bowling
    /// and darts are on the menu because they are coming, not because they run.
    public var isPlayable: Bool {
        switch self {
        case .cricket, .tennis: true
        case .golf, .bowling, .darts: false
        }
    }

    /// What the player points the phone at during calibration. With no screen
    /// in the room, this sentence is the whole of the aiming system.
    public var calibrationPrompt: String {
        switch self {
        case .golf: "Point the phone where you want the ball to go, hold still."
        case .cricket: "Point the phone at the bowler, hold still."
        case .tennis: "Point the phone at the net, hold still."
        case .bowling: "Point the phone at the pins, hold still."
        case .darts: "Point the phone at the board, hold still."
        }
    }
}
