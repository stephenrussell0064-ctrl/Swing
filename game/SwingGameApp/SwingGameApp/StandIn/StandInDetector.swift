import CoreMotion
import Foundation
import simd
import SwingCore
import SwingGame

// SCAFFOLDING. Delete this file the day `motion/` lands.
//
// Ziggy's prototype already detects a swing and this does not try to compete
// with it. It exists because the game half cannot be felt on a phone without
// *some* `Shot` arriving when the phone is swung, and the two of us are not
// in the same room this week. It is the crudest thing that produces a `Shot`
// with every field filled in from real motion, and — the part that is worth
// keeping — it records the trace it cut the `Shot` from, so the swings
// recorded with it become fixtures the real detector is run against later.
// That re-run will overwrite `expected`; that is the design.
//
// It knows nothing about sport. If a sport word appears in here, take it out.
//
// How it works:
//
// - **Stance.** The player hangs the phone down, top edge to the floor, and
//   holds still. That is the address position, borrowed from golf. Where the
//   screen faces at that moment is the target line; that fixes the play frame.
//   Every ball starts from the stance, so the frame is refreshed every ball
//   and the player can turn between balls without anything going wrong.
// - **Strokes.** A stroke is a rise and fall in rotation rate. Each one is
//   reported as a `Shot` timestamped at its peak, as soon as the rate has
//   fallen well off the peak — not at the end of the follow-through, which is
//   hundreds of milliseconds later and was why the first version "did not
//   work": the shot arrived after the game had stopped waiting. A backswing
//   is a stroke too; `game/` picks the one nearest its cue.
// - **Direction** is where the screen faces at the peak — the bat face — not
//   the integrated velocity, which drifts. Speed is peak rotation times an
//   arm's length.
// - **Tempo.back** is the time from leaving rest (the hand last being still
//   for 150 ms) to the peak, so a practice swing measures how long this
//   player's swing takes.

@MainActor
@Observable
final class StandInDetector: ShotSource {
    var handler: ((Shot, [MotionSample]) -> Void)?
    private(set) var isCalibrated = false
    private(set) var status = "Not started"
    private(set) var inStance = false
    /// For the screen: how fast the phone is turning right now, rad/s.
    private(set) var liveRotation: Double = 0
    var profile: SwingProfile = .default

    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    private struct Raw: Sendable {
        var wall: TimeInterval
        /// Device → world (Z up).
        var attitude: simd_quatd
        var rotationRate: SIMD3<Double>     // world, rad/s
        var acceleration: SIMD3<Double>     // world, m/s², gravity removed
        var gravity: SIMD3<Double>          // world, g
        var deviceGravity: SIMD3<Double>    // device frame, g
        var omega: Double
    }

    /// World → play rotation, fixed at the stance.
    private var frame: simd_quatd?
    private var buffer: [Raw] = []
    private let bufferSeconds: TimeInterval = 5

    // Rest: still for a moment. Leaving rest starts a motion.
    private var restCandidateSince: TimeInterval?
    private var atRest = true
    private var motionStart: TimeInterval?
    private let restOmega = 1.2
    private let restHold: TimeInterval = 0.15

    // Stance: hanging, top edge down, still.
    private var stanceSince: TimeInterval?
    private let stanceHold: TimeInterval = 0.6

    // Strokes.
    private enum Stroke {
        case idle
        case rising(peak: Double, peakWall: TimeInterval, peakIndex: Int)
        case cooldown
    }
    private var stroke = Stroke.idle
    private var strokeThreshold: Double { max(2.5, profile.peakRotation * 0.35) }

    func start() {
        guard manager.isDeviceMotionAvailable else {
            status = "No motion sensors"
            return
        }
        manager.deviceMotionUpdateInterval = 1.0 / 100
        queue.maxConcurrentOperationCount = 1
        let bootToWall = Date.timeIntervalSinceReferenceDate - ProcessInfo.processInfo.systemUptime
        // `@Sendable` matters: without it, a closure formed inside this
        // main-actor method is main-actor-isolated, and Core Motion calling it
        // on its own queue trips the Swift 6 runtime isolation check (SIGTRAP).
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { @Sendable [weak self] motion, _ in
            guard let motion else { return }
            let q = motion.attitude.quaternion
            let attitude = simd_quatd(ix: q.x, iy: q.y, iz: q.z, r: q.w)
            let rot = SIMD3(motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z)
            let g = SIMD3(motion.gravity.x, motion.gravity.y, motion.gravity.z)
            let raw = Raw(
                wall: bootToWall + motion.timestamp,
                attitude: attitude,
                rotationRate: attitude.act(rot),
                acceleration: attitude.act(SIMD3(motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z)) * 9.81,
                gravity: attitude.act(g),
                deviceGravity: g,
                omega: simd_length(rot)
            )
            Task { @MainActor in self?.ingest(raw) }
        }
        status = "Hang the phone down and hold still"
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        status = "Stopped"
    }

    func awaitStance(timeout: TimeInterval) async -> Bool {
        status = "Hang the phone down and hold still"
        let deadline = Date.timeIntervalSinceReferenceDate + timeout
        while Date.timeIntervalSinceReferenceDate < deadline, !Task.isCancelled {
            if inStance, let last = buffer.last {
                fixFrame(from: last.attitude)
                status = "Set"
                return true
            }
            try? await Task.sleep(for: .milliseconds(40))
        }
        return false
    }

    /// The screen normal, flattened, is forward. With the phone hanging
    /// straight down the screen faces horizontally, so this is well defined;
    /// if someone manages to hang it with the screen facing the floor, keep
    /// whatever frame we had.
    private func fixFrame(from attitude: simd_quatd) {
        var forward = attitude.act(SIMD3(0, 0, 1))
        forward.z = 0
        guard simd_length(forward) > 0.2 else {
            isCalibrated = frame != nil
            return
        }
        let x = simd_normalize(forward)
        let y = SIMD3<Double>(0, 0, 1)
        let z = simd_cross(x, y)
        frame = simd_quatd(simd_double3x3(rows: [x, y, z]))
        isCalibrated = true
    }

    // MARK: - Detection

    private func ingest(_ raw: Raw) {
        buffer.append(raw)
        if let first = buffer.first, raw.wall - first.wall > bufferSeconds {
            let cut = buffer.firstIndex { raw.wall - $0.wall <= bufferSeconds } ?? 0
            buffer.removeFirst(cut)
            if case .rising(let p, let w, let i) = stroke {
                stroke = .rising(peak: p, peakWall: w, peakIndex: max(0, i - cut))
            }
        }
        liveRotation = raw.omega

        // Stance.
        let hanging = raw.deviceGravity.y > 0.8 && raw.omega < 0.6
        if hanging {
            if stanceSince == nil { stanceSince = raw.wall }
            inStance = raw.wall - stanceSince! >= stanceHold
        } else {
            stanceSince = nil
            inStance = false
        }

        // Rest.
        if raw.omega < restOmega {
            if restCandidateSince == nil { restCandidateSince = raw.wall }
            if raw.wall - restCandidateSince! >= restHold {
                atRest = true
                motionStart = nil
            }
        } else {
            restCandidateSince = nil
            if atRest {
                atRest = false
                motionStart = raw.wall
            }
        }

        guard isCalibrated else { return }
        let i = buffer.count - 1

        switch stroke {
        case .idle:
            if raw.omega > strokeThreshold {
                stroke = .rising(peak: raw.omega, peakWall: raw.wall, peakIndex: i)
                status = "Swinging"
            }
        case .rising(var peak, var peakWall, var peakIndex):
            if raw.omega > peak {
                peak = raw.omega
                peakWall = raw.wall
                peakIndex = i
            }
            if raw.omega < peak * 0.6, raw.wall - peakWall >= 0.04 {
                emit(peakIndex: peakIndex, peak: peak)
                stroke = .cooldown
                status = "Ready"
            } else {
                stroke = .rising(peak: peak, peakWall: peakWall, peakIndex: peakIndex)
            }
        case .cooldown:
            if raw.omega < strokeThreshold * 0.5 {
                stroke = .idle
            }
        }
    }

    private func emit(peakIndex: Int, peak: Double) {
        guard let frame, peakIndex < buffer.count else { return }
        let r = buffer[peakIndex]

        // The face: where the screen points at the peak, in the play frame.
        // A face can be held either way round, so make it point forward.
        var face = frame.act(r.attitude.act(SIMD3(0, 0, 1)))
        if face.x < 0 { face = -face }
        let dir = simd_length(face) > 1e-6 ? simd_normalize(face) : SIMD3(1, 0, 0)

        let spinPlay = frame.act(r.rotationRate)
        let spinRate = simd_length(spinPlay)
        let spinAxis = spinRate > 1e-3 ? spinPlay / spinRate : SIMD3(0, 1, 0)

        // Hand speed: rotation times an arm's length.
        let speed = peak * 0.6

        let start = motionStart ?? (r.wall - 0.3)
        let back = max(0.05, r.wall - start)

        let shot = Shot(
            timestamp: r.wall,
            kind: .swing,
            releaseSpeed: speed,
            peakSpeed: speed,
            direction: Vector3(dir.x, dir.y, dir.z),
            attitude: quaternion(frame * r.attitude),
            spinAxis: Vector3(spinAxis.x, spinAxis.y, spinAxis.z),
            spinRate: peak,
            tempo: .init(back: back, through: 0),
            confidence: min(peak / max(profile.peakRotation, 1), 1)
        )

        // The trace: a little before the hand moved to now, in the play frame.
        let from = buffer.firstIndex { $0.wall >= start - 0.3 } ?? 0
        let t0 = buffer[from].wall
        let trace = buffer[from...].map { s in
            let acc = frame.act(s.acceleration) / 9.81
            let rot = frame.act(s.rotationRate)
            let g = frame.act(s.gravity)
            return MotionSample(
                t: s.wall - t0,
                attitude: quaternion(frame * s.attitude),
                rotationRate: Vector3(rot.x, rot.y, rot.z),
                userAcceleration: Vector3(acc.x, acc.y, acc.z),
                gravity: Vector3(g.x, g.y, g.z)
            )
        }
        handler?(shot, trace)
    }

    private func quaternion(_ q: simd_quatd) -> Quaternion {
        Quaternion(w: q.real, x: q.imag.x, y: q.imag.y, z: q.imag.z)
    }
}
