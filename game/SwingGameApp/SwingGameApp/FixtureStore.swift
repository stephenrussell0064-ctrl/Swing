import Foundation
import SwingCore
import SwingGame
import UIKit

/// Saves every detected swing to `Documents/fixtures/`, which the app exposes
/// to the Files app and to a Mac over USB. Drag them into `fixtures/` in the
/// repository and they are the test suite.
@MainActor
@Observable
final class FixtureStore {
    static let shared = FixtureStore()

    private(set) var fixtures: [Fixture] = []
    private(set) var urls: [URL] = []

    let directory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("fixtures", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init() {
        reload()
    }

    func reload() {
        let all = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        urls = all.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        fixtures = urls.compactMap { try? FixtureReplay.load($0) }
    }

    /// `prefix` says what was going on: "cricket-batting", "tennis-return".
    /// It is not sport leaking into detection; it is a human note about the
    /// room, and the detector never sees it.
    func save(_ shot: Shot, trace: [MotionSample], prefix: String, note: String) {
        guard !trace.isEmpty else { return }
        let stamp = Self.stamp.string(from: Date())
        let id = "\(prefix)-\(stamp)"
        let fixture = Fixture(
            id: id,
            recordedAt: Date(),
            note: note,
            deviceModel: Self.deviceModel,
            samples: trace,
            expected: shot
        )
        do {
            try FixtureReplay.write(fixture, to: directory.appendingPathComponent("\(id).json"))
            reload()
        } catch {
            // A fixture that failed to write is a swing lost, not a crash.
        }
    }

    func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        reload()
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static let deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let name = mirror.children.compactMap { $0.value as? Int8 }.prefix { $0 != 0 }.map { Character(UnicodeScalar(UInt8($0))) }
        return name.isEmpty ? UIDevice.current.model : String(name)
    }()
}
