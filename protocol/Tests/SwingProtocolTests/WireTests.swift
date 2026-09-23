import Foundation
import Testing
@testable import SwingProtocol

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

    @Test("vectors are arrays on the wire, not objects")
    func vectorsEncodeAsArrays() throws {
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(shot)
        ) as! [String: Any]

        #expect(json["direction"] as? [Double] == [0.98, 0.04, -0.19])
        #expect(json["attitude"] as? [Double] == [0.71, 0, 0.70, 0])
        #expect(json["v"] as? Int == Wire.version)
        #expect(json["kind"] as? String == "swing")
    }

    /// The controller and the host are two apps shipped separately. A field the
    /// phone renames is a field the host silently loses, so the wire names are
    /// pinned here rather than left to the compiler.
    @Test("wire field names are fixed")
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
}

@Suite("Version negotiation")
struct VersionTests {

    @Test("accepts a peer inside the supported range")
    func acceptsCurrent() {
        #expect(Wire.supports(Wire.version))
        #expect(Wire.supports(Wire.minimumSupportedVersion))
    }

    @Test("refuses a peer outside it")
    func refusesOutside() {
        #expect(!Wire.supports(Wire.minimumSupportedVersion - 1))
        #expect(!Wire.supports(Wire.version + 1))
    }

    @Test("messages round-trip with their case intact")
    func messageRoundTrip() throws {
        let sent = Wire.ControllerMessage.shot(shot)
        let data = try JSONEncoder().encode(sent)

        guard case .shot(let received) = try JSONDecoder()
            .decode(Wire.ControllerMessage.self, from: data)
        else {
            Issue.record("decoded as the wrong case")
            return
        }
        #expect(received == shot)
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
