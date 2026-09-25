import Foundation
import SwingCore

/// Reads `fixtures/*.json` so a recorded swing can be fed to a sport as if it
/// had just happened. This is how the game is built sitting down.
public enum FixtureReplay {

    public static func load(_ url: URL) throws -> Fixture {
        let data = try Data(contentsOf: url)
        return try decoder.decode(Fixture.self, from: data)
    }

    /// Every fixture in a directory, sorted by id so the order is stable.
    public static func loadAll(in directory: URL) throws -> [Fixture] {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return try files
            .filter { $0.pathExtension == "json" }
            .map(load)
            .sorted { $0.id < $1.id }
    }

    public static func write(_ fixture: Fixture, to url: URL) throws {
        try encoder.encode(fixture).write(to: url, options: .atomic)
    }

    /// Rebase a recorded `Shot` so its release lands exactly `offset` seconds
    /// from a cue's contact time. Replaying a swing against a delivery means
    /// asking "what if this swing had been made now, this early or late".
    public static func retime(_ shot: Shot, toContact cue: Cue, offset: TimeInterval = 0) -> Shot {
        var s = shot
        s.timestamp = cue.contactTime + offset
        return s
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return e
    }()
}
