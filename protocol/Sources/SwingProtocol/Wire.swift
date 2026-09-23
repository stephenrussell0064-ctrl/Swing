import Foundation

/// What the phone and the host agree on before either says anything else.
public enum Wire {

    /// Bump when a change would make an older peer misread a message. Adding an
    /// optional field with a sane default is not that; changing what a field
    /// means is, even if the type is unchanged.
    public static let version = 1

    /// The oldest version this build can still talk to.
    public static let minimumSupportedVersion = 1

    /// Bonjour service type. The host advertises, the phone browses.
    public static let serviceType = "_swing._tcp"

    public static func supports(_ peerVersion: Int) -> Bool {
        (minimumSupportedVersion...version).contains(peerVersion)
    }

    /// Messages that only ever travel phone → host.
    public enum ControllerMessage: Codable, Sendable {
        case hello(Hello)
        case shot(Shot)
        /// Live motion while the player is mid-backswing, so the host can draw
        /// it. Batched: a sample every 10 ms is a lot of very small packets.
        case motion([MotionSample])
        /// The player put the phone down, took a call, walked off.
        case goodbye
    }

    /// Messages that only ever travel host → phone.
    public enum HostMessage: Codable, Sendable {
        case welcome(Welcome)
        case rejected(Rejection)
        /// Whose turn it is and what they are about to do — the phone uses this
        /// to arm the right detector and say something useful on screen.
        case awaiting(Prompt)
        /// The shot was scored. Carries only what the hand should feel and the
        /// player should read; the host still owns the picture.
        case outcome(Outcome)
    }

    public struct Hello: Hashable, Codable, Sendable {
        public var version: Int
        /// "Stephen's iPhone" — shown on the host so you know who joined.
        public var deviceName: String
        public var controllerBuild: String

        public init(version: Int = Wire.version, deviceName: String, controllerBuild: String) {
            self.version = version
            self.deviceName = deviceName
            self.controllerBuild = controllerBuild
        }
    }

    public struct Welcome: Hashable, Codable, Sendable {
        /// The version the host chose to speak. At or below the phone's.
        public var version: Int
        public var hostName: String
        /// Sport identifiers this host build knows. The phone shows the names
        /// and nothing else — it does not know what they mean.
        public var sports: [String]

        public init(version: Int, hostName: String, sports: [String]) {
            self.version = version
            self.hostName = hostName
            self.sports = sports
        }
    }

    public struct Rejection: Hashable, Codable, Sendable {
        public enum Reason: String, Codable, Sendable {
            /// One side is too old. Say which, so the message on screen can be
            /// "update your phone" rather than "something went wrong".
            case versionTooOld
            case versionTooNew
            case hostBusy
        }

        public var reason: Reason
        public var hostVersion: Int
        public var detail: String?

        public init(reason: Reason, hostVersion: Int = Wire.version, detail: String? = nil) {
            self.reason = reason
            self.hostVersion = hostVersion
            self.detail = detail
        }
    }

    public struct Prompt: Hashable, Codable, Sendable {
        public var kind: Shot.Kind
        /// "Tee shot, 412 yards, wind off the left." Free text, host's words.
        public var message: String
        public var playerName: String?

        public init(kind: Shot.Kind, message: String, playerName: String? = nil) {
            self.kind = kind
            self.message = message
            self.playerName = playerName
        }
    }

    public struct Outcome: Hashable, Codable, Sendable {
        public var shotID: UUID
        /// "Fairway, 268 yards." Host's words again.
        public var message: String
        /// How hard the phone should buzz, 0...1. The host knows whether it was
        /// a flush strike or a top; the phone does not.
        public var haptic: Double

        public init(shotID: UUID, message: String, haptic: Double) {
            self.shotID = shotID
            self.message = message
            self.haptic = haptic
        }
    }
}
