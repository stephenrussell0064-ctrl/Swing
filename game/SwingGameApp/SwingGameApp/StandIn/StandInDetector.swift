import CoreMotion
import Foundation
import simd
import SwingCore

// SCAFFOLDING. Delete this file the day `motion/` lands.
//
// Ziggy's prototype already detects a swing and this does not try to compete
// with it. It exists because the game half cannot be felt on a phone without
// *some* `Shot` arriving when the phone is swung, and the two of us are not
// in the same room this week. It is the crudest thing that produces a `Shot`
// with every field filled in from real motion, and — the part that is worth
// keeping — it records the trace it cut the `Shot` from, so the tennis and
// cricket swings recorded with it become fixtures the real detector is run
// against later. That re-run will overwrite `expected`; that is the design.
//
// It knows nothing about sport. If a sport word appears in here, take it out.

@MainActor
@Observable
final class StandInDetector: ShotSource {
    var handler: ((Shot, [MotionSample]) -> Void)?
    private(set) var isCalibrated = false
    private(set) var status = "Not started"
    /// For the screen: how fast the phone is turning right now, rad/s.
    private(set) var liveRotation: Double = 0

    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    /// One reading, already rotated into the world frame (Z up), with a wall
    /// clock time so it can be compared to a cue.
    private struct Raw: Sendable {
        var wall: TimeInterval
        var attitude: simd_quatd
        var rotationRate: SIMD3<Double>
        var acceleration: SIMD3<Double>   // m/s², gravity removed
        var gravity: SIMD3<Double>
    }

    /// World → play rotation, fixed at calibration.
    private var frame: simd_quatd?

    private var buffer: [Raw] = []
    private let bufferSeconds: TimeInterval = 4

    private enum State {
        case idle
        case moving(start: Int)
        case swinging(start: Int, peakOmega: Double, peakOmegaAt: Int)
    }
    private var state = State.idle
    private var velocity = SIMD3<Double>.zero
    private var speeds: [Double] = []       // |velocity| per sample since motion start
    private var velocities: [SIMD3<Double>] = []

    // Thresholds. Tuned by feel against one phone in one kitchen, which is
    // exactly the kind of tuning `motion/` exists to do properly.
    private let moveOmega = 2.0
    private let moveAccel = 1.5
    private let swingOmega = 5.0
    private let releaseFraction = 0.35
    private let velocityLeak = 0.998

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
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { @Sendable [weak self] motion, error in
            if let error { NSLog("swing: device motion error \(error)") }
            guard let motion else { return }
            let q = motion.attitude.quaternion
            let attitude = simd_quatd(ix: q.x, iy: q.y, iz: q.z, r: q.w)
            let raw = Raw(
                wall: bootToWall + motion.timestamp,
                attitude: attitude,
                rotationRate: attitude.act(SIMD3(motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z)),
                acceleration: attitude.act(SIMD3(motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z)) * 9.81,
                gravity: attitude.act(SIMD3(motion.gravity.x, motion.gravity.y, motion.gravity.z))
            )
            Task { @MainActor in self?.ingest(raw) }
        }
        status = isCalibrated ? "Ready" : "Calibrate first"
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        status = "Stopped"
    }

    /// Hold the phone pointing down the target line, top edge forward, for a
    /// second. The horizontal projection of that becomes play-frame x.
    func calibrate() async -> Bool {
        status = "Hold still…"
        let start = Date.timeIntervalSinceReferenceDate
        var stillFor: TimeInterval = 0
        var lastAttitude: simd_quatd?
        while Date.timeIntervalSinceReferenceDate - start < 4 {
            try? await Task.sleep(for: .milliseconds(50))
            guard let last = buffer.last else { continue }
            if simd_length(last.rotationRate) < 0.35 {
                stillFor += 0.05
                lastAttitude = last.attitude
                if stillFor >= 0.8 { break }
            } else {
                stillFor = 0
            }
        }
        guard stillFor >= 0.8, let attitude = lastAttitude else {
            status = "Couldn't hold still. Try again."
            return false
        }
        // Device +Y (toward the top edge) in the world, flattened.
        var forward = attitude.act(SIMD3(0, 1, 0))
        forward.z = 0
        guard simd_length(forward) > 0.2 else {
            status = "Point the top of the phone forward, not up."
            return false
        }
        let x = simd_normalize(forward)
        let y = SIMD3<Double>(0, 0, 1)
        let z = simd_cross(x, y)
        // Rows are the play axes in world coordinates, so this maps world → play.
        let m = simd_double3x3(rows: [x, y, z])
        frame = simd_quatd(m)
        isCalibrated = true
        status = "Ready"
        return true
    }

    // MARK: - Detection

    private func ingest(_ raw: Raw) {
        buffer.append(raw)
        if let first = buffer.first, raw.wall - first.wall > bufferSeconds {
            let cut = buffer.firstIndex { raw.wall - $0.wall <= bufferSeconds } ?? 0
            buffer.removeFirst(cut)
            adjustIndices(by: -cut)
        }
        let omega = simd_length(raw.rotationRate)
        liveRotation = omega
        guard isCalibrated else { return }

        let i = buffer.count - 1
        let dt = i > 0 ? raw.wall - buffer[i - 1].wall : 0.01

        switch state {
        case .idle:
            if omega > moveOmega || simd_length(raw.acceleration) > moveAccel {
                state = .moving(start: i)
                velocity = .zero
                speeds = []
                velocities = []
                integrate(raw, dt: dt)
                status = "Moving"
            }

        case .moving(let start):
            integrate(raw, dt: dt)
            if omega > swingOmega {
                state = .swinging(start: start, peakOmega: omega, peakOmegaAt: i)
                status = "Swinging"
            } else if omega < 1, simd_length(raw.acceleration) < 1, raw.wall - buffer[start].wall > 0.6 {
                state = .idle
                status = "Ready"
            }

        case .swinging(let start, var peakOmega, var peakAt):
            integrate(raw, dt: dt)
            if omega > peakOmega {
                peakOmega = omega
                peakAt = i
            }
            let sincePeak = raw.wall - buffer[peakAt].wall
            let ended = omega < peakOmega * releaseFraction && sincePeak > 0.05
            let tooLong = raw.wall - buffer[start].wall > 2.5
            if ended || tooLong {
                emit(start: start, end: i, peakOmega: peakOmega, peakOmegaAt: peakAt)
                state = .idle
                status = "Ready"
            } else {
                state = .swinging(start: start, peakOmega: peakOmega, peakOmegaAt: peakAt)
            }
        }
    }

    private func integrate(_ raw: Raw, dt: TimeInterval) {
        velocity = velocity * velocityLeak + raw.acceleration * dt
        velocities.append(velocity)
        speeds.append(simd_length(velocity))
    }

    private func adjustIndices(by delta: Int) {
        switch state {
        case .idle: break
        case .moving(let s): state = .moving(start: max(0, s + delta))
        case .swinging(let s, let p, let at): state = .swinging(start: max(0, s + delta), peakOmega: p, peakOmegaAt: max(0, at + delta))
        }
    }

    private func emit(start: Int, end: Int, peakOmega: Double, peakOmegaAt: Int) {
        guard let frame, end > start, !speeds.isEmpty else { return }
        // Release: the moment of peak rotation. The gyroscope is the honest
        // sensor here — integrated acceleration drifts, and a bat or racket is
        // turning fastest at the moment it would meet the ball. Speed and
        // direction still come from the integrated velocity at that moment.
        let releaseIndex = min(max(peakOmegaAt, start), end)
        let releaseOffset = min(releaseIndex - start, speeds.count - 1)
        let releaseRaw = buffer[releaseIndex]
        let v = velocities[min(releaseOffset, velocities.count - 1)]
        let releaseSpeed = simd_length(v)
        let peakSpeed = speeds.max() ?? releaseSpeed

        let worldDirection = releaseSpeed > 0.5 ? simd_normalize(v) : simd_normalize(SIMD3(1, 0, 0.0))
        let playDirection = frame.act(worldDirection)
        let playSpin = frame.act(releaseRaw.rotationRate)
        let spinRate = simd_length(playSpin)
        let spinAxis = spinRate > 1e-3 ? playSpin / spinRate : SIMD3(0, 1, 0)

        // Tempo: the hand goes back before it comes through. Find where the
        // velocity along the release direction last crossed zero.
        var crossing = start
        for k in stride(from: min(releaseOffset, velocities.count - 1), to: 0, by: -1) {
            if simd_dot(velocities[k], worldDirection) > 0 && simd_dot(velocities[k - 1], worldDirection) <= 0 {
                crossing = start + k
                break
            }
        }
        let back = buffer[crossing].wall - buffer[start].wall
        let through = max(0, releaseRaw.wall - buffer[crossing].wall)

        let shot = Shot(
            timestamp: releaseRaw.wall,
            kind: through < 0.15 && back < 0.3 ? .throw : .swing,
            releaseSpeed: releaseSpeed,
            peakSpeed: peakSpeed,
            direction: Vector3(playDirection.x, playDirection.y, playDirection.z),
            attitude: quaternion(frame * releaseRaw.attitude),
            spinAxis: Vector3(spinAxis.x, spinAxis.y, spinAxis.z),
            spinRate: spinRate,
            tempo: .init(back: back, through: through),
            confidence: min(peakOmega / 12, 1) * (releaseSpeed > 1 ? 1 : 0.5)
        )

        // The trace: half a second before the hand moved to a little after it
        // stopped, all in the play frame, so a fixture reads the same on any
        // phone pointed down any line.
        let from = buffer.firstIndex { $0.wall >= buffer[start].wall - 0.5 } ?? start
        let t0 = buffer[from].wall
        let trace = buffer[from...end].map { r in
            let acc = frame.act(r.acceleration) / 9.81
            let rot = frame.act(r.rotationRate)
            let g = frame.act(r.gravity)
            return MotionSample(
                t: r.wall - t0,
                attitude: quaternion(frame * r.attitude),
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
