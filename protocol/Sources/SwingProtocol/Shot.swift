import Foundation

/// One motion of the hand, described in physics.
///
/// Deliberately says nothing about sport. There is no club here, no ball, no
/// board — the host decides whether these numbers are a drive, a strike or
/// double top. Adding a sport must never require adding a field here.
///
/// Every quantity is in the play frame described on ``Vector3``, in SI units,
/// measured at **release**: the moment of maximum speed, just before the sharp
/// deceleration that ends the motion.
public struct Shot: Hashable, Sendable, Identifiable {

    /// What the hand did. The host maps this to a sport; the controller uses it
    /// only to pick which detector ran.
    public enum Kind: String, Codable, Sendable, CaseIterable {
        /// Fast rotation about the body. Golf, tennis, a baseball bat.
        case swing
        /// Low, forward, released near the floor. Bowling, bowls, curling.
        case roll
        /// Short, sharp, forward, with a wrist snap. Darts, a beanbag.
        case `throw`
    }

    /// Backswing and downswing, in seconds. Their ratio is most of what makes a
    /// swing feel good or bad, and it is worth more than peak speed alone.
    public struct Tempo: Hashable, Codable, Sendable {
        public var back: TimeInterval
        public var through: TimeInterval

        public init(back: TimeInterval, through: TimeInterval) {
            self.back = back
            self.through = through
        }

        /// Conventionally about 3:1 for a good golf swing.
        public var ratio: Double? {
            through > 0 ? back / through : nil
        }
    }

    public var version: Int
    public var id: UUID
    /// Release, on the controller's clock, seconds since the reference date.
    public var timestamp: TimeInterval
    public var kind: Kind
    /// Speed at release, m/s.
    public var releaseSpeed: Double
    /// Highest speed anywhere in the window, m/s. Above `releaseSpeed` when the
    /// player decelerated into the shot.
    public var peakSpeed: Double
    /// Unit vector of travel at release.
    public var direction: Vector3
    /// Device attitude at release. How the face was pointing, as against
    /// ``direction``, which is where the hand was going. The gap between the two
    /// is the slice.
    public var attitude: Quaternion
    /// Unit vector: the axis the device was rotating about at release.
    public var spinAxis: Vector3
    /// Rate about ``spinAxis``, rad/s.
    public var spinRate: Double
    public var tempo: Tempo
    /// How sure the detector is that this was a real, complete motion, 0...1.
    /// The host may want to ask rather than score a shot it does not believe in.
    public var confidence: Double

    public init(
        version: Int = Wire.version,
        id: UUID = UUID(),
        timestamp: TimeInterval,
        kind: Kind,
        releaseSpeed: Double,
        peakSpeed: Double,
        direction: Vector3,
        attitude: Quaternion,
        spinAxis: Vector3,
        spinRate: Double,
        tempo: Tempo,
        confidence: Double
    ) {
        self.version = version
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.releaseSpeed = releaseSpeed
        self.peakSpeed = peakSpeed
        self.direction = direction
        self.attitude = attitude
        self.spinAxis = spinAxis
        self.spinRate = spinRate
        self.tempo = tempo
        self.confidence = confidence
    }
}

extension Shot: Codable {
    private enum CodingKeys: String, CodingKey {
        case version = "v"
        case id
        case timestamp = "t"
        case kind
        case releaseSpeed
        case peakSpeed
        case direction
        case attitude
        case spinAxis
        case spinRate
        case tempo
        case confidence
    }
}
