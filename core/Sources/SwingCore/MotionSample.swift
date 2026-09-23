import Foundation

/// One tick of Core Motion, 100 per second.
///
/// Mirrors `CMDeviceMotion` so that a recorded trace and a live reading are the
/// same thing. `motion/` keeps a few seconds of these in a ring buffer,
/// because a swing is only recognisable after it has finished.
public struct MotionSample: Hashable, Codable, Sendable {
    /// Seconds since the start of the recording, not a wall clock. Traces have
    /// to stay comparable across devices and across days.
    public var t: TimeInterval
    /// Attitude, device frame rotated into the play frame.
    public var attitude: Quaternion
    /// rad/s.
    public var rotationRate: Vector3
    /// Acceleration from the hand alone, gravity already removed, in g.
    public var userAcceleration: Vector3
    /// Which way is down, in the play frame. Kept because it is the check that
    /// calibration has not drifted mid-round.
    public var gravity: Vector3

    public init(
        t: TimeInterval,
        attitude: Quaternion,
        rotationRate: Vector3,
        userAcceleration: Vector3,
        gravity: Vector3
    ) {
        self.t = t
        self.attitude = attitude
        self.rotationRate = rotationRate
        self.userAcceleration = userAcceleration
        self.gravity = gravity
    }
}

/// A recorded motion and the ``Shot`` `motion/` made of it.
///
/// These are committed to `fixtures/`. They are how `game/` is built with no
/// phone in the room, and how a change to swing detection is shown to do
/// something: re-run the fixtures, and the numbers that moved are the diff.
public struct Fixture: Hashable, Codable, Sendable {
    public var id: String
    public var recordedAt: Date
    /// What actually happened in the room. "Full driver, caught it thin."
    /// Written by a human, and the only reason these files are worth keeping.
    public var note: String
    public var deviceModel: String
    public var samples: [MotionSample]
    /// What detection produced last time this was re-run. `nil` for a trace
    /// recorded before a detector existed, or one kept precisely because
    /// detection misses it.
    public var expected: Shot?

    public init(
        id: String,
        recordedAt: Date,
        note: String,
        deviceModel: String,
        samples: [MotionSample],
        expected: Shot? = nil
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.note = note
        self.deviceModel = deviceModel
        self.samples = samples
        self.expected = expected
    }
}
