import Foundation

/// Where the fielders stand, from the batter's point of view.
///
/// Angles are degrees from straight down the pitch toward the bowler, positive
/// toward the batter's off side, so the same field works for either hand once
/// the batter's swing has been flipped into "off side positive". Distances are
/// metres from the bat.
public struct Field: Hashable, Sendable {
    public struct Fielder: Hashable, Sendable {
        public var name: String
        public var angle: Double
        public var distance: Double

        public init(name: String, angle: Double, distance: Double) {
            self.name = name
            self.angle = angle
            self.distance = distance
        }

        var position: (x: Double, z: Double) {
            let a = angle.radians
            return (distance * cos(a), distance * sin(a))
        }
    }

    public var fielders: [Fielder]
    /// Metres from the bat to the rope.
    public var boundary: Double

    public init(fielders: [Fielder], boundary: Double = 65) {
        self.fielders = fielders
        self.boundary = boundary
    }

    /// A fielder within this many metres of where a lofted ball lands takes
    /// the catch.
    static let catchRadius = 9.0
    /// A fielder within this many metres of the path of a ground shot stops it.
    static let stopRadius = 5.0

    /// An ordinary limited-overs field for a right-hander: keeper, slip,
    /// point, cover, mid-off, mid-on, midwicket, square leg, fine leg, plus a
    /// long-off and deep midwicket on the rope.
    public static let standard = Field(fielders: [
        Fielder(name: "wicketkeeper", angle: 180, distance: 12),
        Fielder(name: "slip", angle: 150, distance: 14),
        Fielder(name: "point", angle: 95, distance: 28),
        Fielder(name: "cover", angle: 55, distance: 30),
        Fielder(name: "mid-off", angle: 20, distance: 28),
        Fielder(name: "long-off", angle: 15, distance: 62),
        Fielder(name: "mid-on", angle: -20, distance: 28),
        Fielder(name: "midwicket", angle: -55, distance: 26),
        Fielder(name: "deep midwicket", angle: -60, distance: 60),
        Fielder(name: "square leg", angle: -95, distance: 24),
        Fielder(name: "fine leg", angle: -150, distance: 45),
        Fielder(name: "the bowler", angle: 0, distance: 17),
    ])

    /// The fielder who catches a ball landing at `landing`, if any.
    func catcher(landingAt landing: (x: Double, z: Double)) -> Fielder? {
        fielders.first { f in
            let p = f.position
            return hypot(p.x - landing.x, p.z - landing.z) <= Field.catchRadius
        }
    }

    /// The fielder who gets to a ball travelling along `angle` (degrees) before
    /// it has gone `total` metres, if any.
    func stopper(angle: Double, total: Double) -> Fielder? {
        let a = angle.radians
        let dir = (x: cos(a), z: sin(a))
        return fielders
            .filter { f in
                // Along the path and before the ball stops.
                let p = f.position
                let along = p.x * dir.x + p.z * dir.z
                guard along > 0, along < total else { return false }
                let perp = abs(p.x * dir.z - p.z * dir.x)
                return perp <= Field.stopRadius
            }
            .min { $0.distance < $1.distance }
    }
}
