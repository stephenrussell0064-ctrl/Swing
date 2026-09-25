import Foundation
import SwingCore
@testable import SwingGame

/// Hand-made shots for table tests. Real recorded ones live in `fixtures/`
/// and get replayed through the same functions; these exist so the rules can
/// be pinned down before a single swing has been recorded.
enum TestShots {
    static let contactTime: TimeInterval = 1_000

    /// A straight, level, well-struck bat swing at `contactTime + offset`.
    static func straightSwing(
        at offset: TimeInterval = 0,
        speed: Double = 12,
        direction: Vector3 = Vector3(1, 0.05, 0),
        spinAxis: Vector3 = Vector3(0, 0, 1),
        spinRate: Double = 4,
        kind: Shot.Kind = .swing
    ) -> Shot {
        Shot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            timestamp: contactTime + offset,
            kind: kind,
            releaseSpeed: speed,
            peakSpeed: speed,
            direction: direction.normalized!,
            attitude: .identity,
            spinAxis: spinAxis.normalized!,
            spinRate: spinRate,
            tempo: .init(back: 0.6, through: 0.2),
            confidence: 0.9
        )
    }

    static func cue(tolerance: TimeInterval = 0.12) -> Cue {
        Cue(contactTime: contactTime, tolerance: tolerance)
    }
}
