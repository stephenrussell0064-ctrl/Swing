import Foundation
import Testing
import SwingCore
@testable import SwingGame

@Suite("Fixture replay")
struct ReplayTests {

    @Test("a fixture written by the game can be read back and its shot retimed onto a cue")
    func roundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let shot = TestShots.straightSwing()
        let fixture = Fixture(
            id: "cover-drive-01",
            recordedAt: Date(timeIntervalSince1970: 1_758_585_600),
            note: "Cover drive, garden, stand-in detector.",
            deviceModel: "iPhone17,1",
            samples: [MotionSample(t: 0, attitude: .identity, rotationRate: .zero, userAcceleration: .zero, gravity: Vector3(0, -1, 0))],
            expected: shot
        )
        try FixtureReplay.write(fixture, to: dir.appendingPathComponent("cover-drive-01.json"))
        try FixtureReplay.write(fixture, to: dir.appendingPathComponent("not-a-fixture.txt"))

        let all = try FixtureReplay.loadAll(in: dir)
        #expect(all.count == 1)
        #expect(all[0] == fixture)

        let cue = Cue(contactTime: 5_000, tolerance: 0.1)
        let retimed = FixtureReplay.retime(shot, toContact: cue, offset: -0.03)
        #expect(abs(cue.timing(of: retimed).error + 0.03) < 1e-9)
        #expect(retimed.direction == shot.direction)
    }

    @Test("the on-disk shape uses core's pinned field names")
    func fieldNames() throws {
        let data = try FixtureReplay.encoder.encode(TestShots.straightSwing())
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["v"] as? Int == Shot.currentVersion)
        #expect(json["t"] != nil)
    }
}

@Suite("Catalogue")
struct SportTests {

    @Test("every sport has a calibration prompt, and only cricket and tennis play on this branch")
    func catalogue() {
        for s in Sport.allCases {
            #expect(!s.calibrationPrompt.isEmpty)
            #expect(!s.blurb.isEmpty)
        }
        #expect(Sport.allCases.filter(\.isPlayable) == [.cricket, .tennis])
    }
}
