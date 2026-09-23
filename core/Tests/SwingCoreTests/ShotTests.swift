import Foundation
import Testing
@testable import SwingCore

private let shot = Shot(
    id: UUID(uuidString: "0B5B9A1E-5E5F-4C7A-9E31-2E9F1C7A8D40")!,
    timestamp: 1_758_585_600,
    kind: .swing,
    releaseSpeed: 28.9,
    peakSpeed: 31.4,
    direction: Vector3(0.98, 0.04, -0.19),
    attitude: Quaternion(w: 0.71, x: 0, y: 0.70, z: 0),
    spinAxis: Vector3(0.1, 0.99, 0),
    spinRate: 12.3,
    tempo: .init(back: 0.78, through: 0.26),
    confidence: 0.86
)

@Suite("Shot coding")
struct ShotCodingTests {

    @Test("survives a round trip unchanged")
    func roundTrip() throws {
        let data = try JSONEncoder().encode(shot)
        #expect(try JSONDecoder().decode(Shot.self, from: data) == shot)
    }

    @Test("vectors are arrays on disk, not objects")
    func vectorsEncodeAsArrays() throws {
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(shot)
        ) as! [String: Any]

        #expect(json["direction"] as? [Double] == [0.98, 0.04, -0.19])
        #expect(json["attitude"] as? [Double] == [0.71, 0, 0.70, 0])
        #expect(json["v"] as? Int == Shot.currentVersion)
        #expect(json["kind"] as? String == "swing")
    }

    /// Nothing leaves the phone, so these names are not a wire contract — but
    /// fixtures are committed and outlive the build that wrote them. A renamed
    /// field is a recorded swing we can no longer read, and the whole point of
    /// keeping them is that they still load in a year.
    @Test("field names on disk are fixed")
    func fieldNames() throws {
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(shot)
        ) as! [String: Any]

        #expect(
            Set(json.keys) == [
                "v", "id", "t", "kind", "releaseSpeed", "peakSpeed",
                "direction", "attitude", "spinAxis", "spinRate",
                "tempo", "confidence",
            ]
        )
    }

    @Test("a fixture round-trips with its samples and its expected Shot")
    func fixtureRoundTrip() throws {
        let fixture = Fixture(
            id: "driver-thin-01",
            recordedAt: Date(timeIntervalSince1970: 1_758_585_600),
            note: "Full driver, caught it thin.",
            deviceModel: "iPhone17,1",
            samples: [
                MotionSample(
                    t: 0,
                    attitude: .identity,
                    rotationRate: Vector3(0.1, 0, 0),
                    userAcceleration: Vector3(0, 0, 0),
                    gravity: Vector3(0, -1, 0)
                )
            ],
            expected: shot
        )

        let data = try JSONEncoder().encode(fixture)
        let decoded = try JSONDecoder().decode(Fixture.self, from: data)

        #expect(decoded == fixture)
        #expect(decoded.expected == shot)
        #expect(decoded.samples.count == 1)
    }
}

@Suite("Geometry")
struct GeometryTests {

    @Test("the play frame is right-handed: forward × up is the player's right")
    func rightHanded() {
        let forward = Vector3(1, 0, 0)
        let up = Vector3(0, 1, 0)
        #expect(forward.cross(up) == Vector3(0, 0, 1))
    }

    @Test("the zero vector has no direction")
    func zeroHasNoDirection() {
        #expect(Vector3.zero.normalized == nil)
    }

    @Test("normalizing gives unit length")
    func normalizing() throws {
        let n = try #require(Vector3(3, 0, 4).normalized)
        #expect(abs(n.magnitude - 1) < 1e-12)
        #expect(n == Vector3(0.6, 0, 0.8))
    }

    @Test("tempo ratio is nil rather than infinite when nothing moved")
    func tempoRatio() {
        #expect(Shot.Tempo(back: 0.78, through: 0.26).ratio == 3)
        #expect(Shot.Tempo(back: 0.78, through: 0).ratio == nil)
    }
}
