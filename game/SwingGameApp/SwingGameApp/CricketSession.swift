import Foundation
import SwingCore
import SwingGame

/// Drives a `CricketMatch` on a real clock: plays each delivery's haptic
/// script, waits for the hand, scores it, speaks. Bat an over, then bowl one.
@MainActor
@Observable
final class CricketSession {
    private(set) var match: CricketMatch
    /// Big text for the glance after the ball.
    private(set) var headline = "Cricket"
    private(set) var detail = ""
    private(set) var isRunning = false
    /// The last delivery, for the screen and for the fixture note.
    private(set) var lastDelivery: Delivery?

    let handedness: Handedness
    private let source: any ShotSource
    private let inbox = ShotInbox()
    private let haptics: HapticPlayer
    private let clicks: ClickPlayer
    private let announcer: Announcer
    private let fixtures = FixtureStore.shared
    private var loop: Task<Void, Never>?

    init(source: any ShotSource, haptics: HapticPlayer, clicks: ClickPlayer, announcer: Announcer, handedness: Handedness) {
        self.match = CricketMatch(oversPerSide: 1, wicketsPerSide: 3, seed: UInt64(Date().timeIntervalSince1970))
        self.source = source
        self.haptics = haptics
        self.clicks = clicks
        self.announcer = announcer
        self.handedness = handedness
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        source.handler = { [weak self] shot, trace in
            self?.inbox.push(shot, trace: trace)
        }
        loop = Task { [weak self] in
            await self?.run()
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        isRunning = false
        announcer.stop()
        headline = "Stopped"
    }

    func restart() {
        stop()
        match = CricketMatch(oversPerSide: 1, wicketsPerSide: 3, seed: UInt64(Date().timeIntervalSince1970))
        start()
    }

    private func run() async {
        announcer.say(match.phaseAnnouncement)
        headline = "You're batting"
        detail = "Count the beats. Swing on the one after the high one."
        try? await Task.sleep(for: .seconds(4.5))

        while !Task.isCancelled {
            switch match.phase {
            case .batting:
                await bat()
            case .bowling:
                await bowl()
            case .finished:
                headline = match.scoreAnnouncement
                detail = "Tap Restart to play again."
                announcer.say(match.scoreAnnouncement)
                isRunning = false
                return
            }
        }
    }

    private func bat() async {
        let delivery = match.nextDelivery()
        lastDelivery = delivery
        let script = delivery.script()
        let start = Date.timeIntervalSinceReferenceDate + 0.8
        let cue = Cue(script: script, startingAt: start, tolerance: delivery.tolerance)
        inbox.clear()
        headline = "Here it comes"
        detail = "\(delivery.bowler.rawValue.capitalized), \(Int(delivery.pace * 2.237)) mph · \(delivery.bowler.beats) beats"
        haptics.play(script, at: start)
        clicks.schedule(script, at: start)

        let answer = await inbox.shot(for: cue, notBefore: start)
        if Task.isCancelled { return }
        let result = Batting.play(shot: answer?.shot, delivery: delivery, cue: cue, handedness: handedness)
        haptics.play(result.haptic)
        announcer.sayNow([result.announcement, result.timing?.feedback].compactMap { $0 }.joined(separator: " "))
        match.record(result)
        headline = result.announcement
        detail = describe(result, delivery: delivery)

        if let answer {
            fixtures.save(
                answer.shot, trace: answer.trace, prefix: "cricket-bat",
                note: "Batting vs \(delivery.bowler.rawValue) \(delivery.length.rawValue) at \(Int(delivery.pace)) m/s, line \(String(format: "%.2f", delivery.line)). "
                    + "Timing \(result.timing.map { String(format: "%+.3f s", $0.error) } ?? "n/a"). Game said: \(result.announcement)"
            )
        }

        try? await Task.sleep(for: .seconds(2.2))
        if match.phase != .batting {
            headline = "Now bowl"
            detail = "Point the phone at the stumps. Bowl when you're ready."
            announcer.say(match.phaseAnnouncement)
            try? await Task.sleep(for: .seconds(4))
        } else if match.yours.balls % 2 == 0 {
            announcer.say(match.scoreAnnouncement)
            try? await Task.sleep(for: .seconds(1.5))
        }
    }

    private func bowl() async {
        inbox.clear()
        let armed = Date.timeIntervalSinceReferenceDate + 0.5
        headline = "Bowl when ready"
        detail = "Ball \(match.theirs.balls + 1) of \(match.ballsPerInnings)"
        guard let answer = await inbox.nextShot(notBefore: armed), !Task.isCancelled else { return }
        let ball = Bowling.ball(from: answer.shot)
        let result = Bowling.face(ball, batter: match.batter, ballIndex: match.nextBowlingIndex, seed: match.seed)
        haptics.play(result.haptic)
        announcer.sayNow(result.announcement)
        match.record(result)
        headline = result.announcement
        if let ball {
            let side = abs(ball.line) < 0.05 ? "middle stump" : String(format: "%.2f m %@", abs(ball.line), ball.line > 0 ? "outside off" : "down leg")
            detail = "\(Int(ball.pace * 2.237)) mph, \(ball.length.spoken), \(side)"
        } else {
            detail = "That motion was not read as a bowl."
        }
        fixtures.save(
            answer.shot, trace: answer.trace, prefix: "cricket-bowl",
            note: "Bowling. Read as \(ball.map { "\($0.length.rawValue) at \(Int($0.pace)) m/s, line \(String(format: "%.2f", $0.line))" } ?? "not a bowl"). Game said: \(result.announcement)"
        )
        try? await Task.sleep(for: .seconds(2.2))
        if match.phase == .bowling {
            announcer.say(match.scoreAnnouncement)
            try? await Task.sleep(for: .seconds(1.5))
        }
    }

    private func describe(_ r: BattingResult, delivery: Delivery) -> String {
        var parts: [String] = []
        if let t = r.timing {
            parts.append(String(format: "%+.0f ms", t.error * 1000))
        }
        if let f = r.flight {
            parts.append(String(format: "%.0f m at %.0f°", f.total, f.angle))
        }
        parts.append("\(delivery.length.spoken) ball")
        return parts.joined(separator: " · ")
    }
}
