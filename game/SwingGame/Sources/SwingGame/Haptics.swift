import Foundation

/// One thing the hand feels. Data, not a call into Core Haptics — the app
/// target turns these into `CHHapticEvent`s. Keeping the vocabulary here means
/// a whole delivery or rally can be tested as a list of numbers.
public enum HapticEvent: Hashable, Sendable {
    /// A single transient click. `intensity` and `sharpness` are 0...1, as
    /// Core Haptics defines them: a sharp, strong tap is the ball hitting the
    /// ground; a soft dull one is a footstep.
    case tap(intensity: Double, sharpness: Double)
    /// A continuous buzz for `duration` seconds, ramping from `from` to `to`
    /// intensity. A rising rumble is the one shape a hand reads as "coming".
    case rumble(duration: TimeInterval, from: Double, to: Double)
}

/// A timed sequence of haptic events, relative to the script's own start.
///
/// The player cannot look at the phone while holding it, so this is the game's
/// entire way of saying *when*. Every incoming ball is a script that ends at
/// the moment the player is meant to make contact.
public struct HapticScript: Hashable, Sendable {
    public struct Entry: Hashable, Sendable {
        public var at: TimeInterval
        public var event: HapticEvent

        public init(at: TimeInterval, event: HapticEvent) {
            self.at = at
            self.event = event
        }
    }

    public var entries: [Entry]
    /// When, relative to the script's start, contact is meant to happen. Not
    /// itself a haptic — the whole design is that the hand feels the rhythm
    /// *leading up* to this moment and swings into silence, the way you hit a
    /// real ball: the last cue you get is the bounce, not the contact.
    public var contactAt: TimeInterval

    public init(entries: [Entry], contactAt: TimeInterval) {
        self.entries = entries.sorted { $0.at < $1.at }
        self.contactAt = contactAt
    }

    public var duration: TimeInterval {
        entries.map { entry in
            switch entry.event {
            case .tap: entry.at
            case .rumble(let d, _, _): entry.at + d
            }
        }.max() ?? 0
    }
}

// MARK: - The shared vocabulary

/// Cues every sport reuses. A player who has learned that a sharp tap is the
/// ball hitting the ground in cricket should find it means the same in tennis.
public enum HapticVocabulary {
    /// The ball meeting the ground. The most important single cue: in every
    /// bat-and-ball sport the swing is timed off the bounce.
    public static let bounce = HapticEvent.tap(intensity: 1.0, sharpness: 1.0)
    /// The ball leaving the opponent — bowler's hand, racket. Softer than the
    /// bounce so the two are not confused.
    public static let released = HapticEvent.tap(intensity: 0.6, sharpness: 0.4)
    /// A count-in tap: one per side cue, one per step of a run-up.
    public static let tick = HapticEvent.tap(intensity: 0.35, sharpness: 0.3)

    /// Outcome: you hit it cleanly. Crisp and short.
    public static let cleanStrike = HapticScript(
        entries: [.init(at: 0, event: .tap(intensity: 1.0, sharpness: 0.9))],
        contactAt: 0
    )
    /// Outcome: you got something on it, but not the middle.
    public static let mishit = HapticScript(
        entries: [
            .init(at: 0, event: .tap(intensity: 0.7, sharpness: 0.2)),
            .init(at: 0.06, event: .rumble(duration: 0.18, from: 0.5, to: 0.1)),
        ],
        contactAt: 0
    )
    /// Outcome: you missed. A low, long buzz the hand cannot mistake for a hit.
    public static let miss = HapticScript(
        entries: [.init(at: 0, event: .rumble(duration: 0.45, from: 0.4, to: 0.4))],
        contactAt: 0
    )
    /// Outcome: something good happened that is bigger than one hit — a
    /// boundary, a winner, a wicket when bowling.
    public static let celebration = HapticScript(
        entries: [
            .init(at: 0.00, event: .tap(intensity: 0.8, sharpness: 0.8)),
            .init(at: 0.12, event: .tap(intensity: 0.9, sharpness: 0.8)),
            .init(at: 0.24, event: .tap(intensity: 1.0, sharpness: 0.9)),
        ],
        contactAt: 0
    )
}
