import Foundation

/// A direction or a rate in the **play frame**.
///
/// The play frame is fixed at calibration, when the player holds the phone and
/// points it down the target line — where they intend the ball to go. Until
/// that happens there is no play frame and no vector here means anything.
///
/// - `x` — forward: down the target line, away from the player.
/// - `y` — up: opposed to gravity.
/// - `z` — the player's right, facing down the line.
///
/// Right-handed, so `x × y = z`. A right-hander's slice leaves with positive `z`.
///
/// Calibration matters more here than it would with a screen in the room: there
/// is no fixed thing to aim at, so the player's own declared line is the only
/// reference the game has.
///
/// Encodes as `[x, y, z]`.
public struct Vector3: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(_ x: Double, _ y: Double, _ z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vector3(0, 0, 0)

    public var magnitude: Double {
        (x * x + y * y + z * z).squareRoot()
    }

    /// `nil` for the zero vector, which has no direction. Callers have to say
    /// what they want to happen in that case rather than silently getting one.
    public var normalized: Vector3? {
        let m = magnitude
        guard m > 0, m.isFinite else { return nil }
        return Vector3(x / m, y / m, z / m)
    }

    public func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    public func cross(_ other: Vector3) -> Vector3 {
        Vector3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }
}

extension Vector3: Codable {
    public init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        x = try c.decode(Double.self)
        y = try c.decode(Double.self)
        z = try c.decode(Double.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(x)
        try c.encode(y)
        try c.encode(z)
    }
}

/// Device attitude, as Core Motion reports it, rotated into the play frame.
///
/// Encodes as `[w, x, y, z]`.
public struct Quaternion: Hashable, Sendable {
    public var w: Double
    public var x: Double
    public var y: Double
    public var z: Double

    public init(w: Double, x: Double, y: Double, z: Double) {
        self.w = w
        self.x = x
        self.y = y
        self.z = z
    }

    public static let identity = Quaternion(w: 1, x: 0, y: 0, z: 0)
}

extension Quaternion: Codable {
    public init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        w = try c.decode(Double.self)
        x = try c.decode(Double.self)
        y = try c.decode(Double.self)
        z = try c.decode(Double.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(w)
        try c.encode(x)
        try c.encode(y)
        try c.encode(z)
    }
}
