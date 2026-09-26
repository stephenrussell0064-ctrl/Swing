import Foundation
import SwingCore
import SwingGame

/// Drives a `CricketMatch` on a real clock. Every ball begins from the
/// stance: the player hangs the phone down and holds still, it buzzes, the
/// count-in plays, they swing. Bat an over, then bowl one.
@MainActor
@Observable
final class CricketSession {
    private(set) var match: CricketMatch
    private(set) var headline = "Cricket"
    private(set) var detail = ""
    private(set) var isRunning = false
    private(set) var stage = Stage.idle
    private(set) var activeScript: ActiveScript?
    private(set) var lastDelivery: Delivery?
    private(set) var lastBatting: BattingResult?
    private(set) var lastBowling: BowlingResult?
    private(set) var lastResultAt: TimeInterval = 0
    private(set) var profile = SwingProfile.default

    let handedness: Handedness
    private let source: any ShotSource
    private let inbox = ShotInbox()
    private let haptics: HapticPlayer
    private let clicks: ClickPlayer
    private let announcer: Announcer
    private let fixtures = FixtureStore.shared
    private var loop: Task<Void, Never>?

    private let practiceSwings = 2
    private let practiceBalls = 2

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
        activeScript = nil
        stage = .idle
        announcer.stop()
        headline = "Stopped"
    }

    func restart() {
        stop()
        match = CricketMatch(oversPerSide: 1, wicketsPerSide: 3, seed: UInt64(Date().timeIntervalSince1970))
        lastBatting = nil
        lastBowling = nil
        start()
    }

    // MARK: - The flow

    private func run() async {
        headline = "Take your stance"
        detail = "Hang the phone down like a bat, screen facing the bowler. Hold still."
        announcer.sayNow("Cricket. Hang the phone down like a bat, with the screen facing the bowler, and hold still.")
        stage = .stance
        guard await source.awaitStance(timeout: 120), !Task.isCancelled else { return }
        haptics.play(ReadyCue.haptic)

        await learnSwing()
        if Task.isCancelled { return }

        announcer.say(String(format: "Your swing takes about %.1f seconds, so that is the beat. Every ball: stance, buzz, four beats, and swing so the bat arrives on the fifth. Two practice balls first.", profile.beat))
        headline = String(format: "Beat: %.1f s", profile.beat)
        detail = "Stance, buzz, four beats, swing to meet the fifth."
        try? await Task.sleep(for: .seconds(7))

        for n in 1...practiceBalls where !Task.isCancelled {
            await practice(n)
        }
        if Task.isCancelled { return }

        announcer.say(match.phaseAnnouncement)
        headline = "You're batting"
        detail = "Same count. Now it counts."
        try? await Task.sleep(for: .seconds(3))

        while !Task.isCancelled {
            switch match.phase {
            case .batting:
                await bat()
            case .bowling:
                await bowl()
            case .finished:
                stage = .finished
                headline = match.scoreAnnouncement
                detail = "Tap Restart to play again."
                announcer.say(match.scoreAnnouncement)
                isRunning = false
                return
            }
        }
    }

    /// Return to the stance. Buzzes when set.
    private func stance() async -> Bool {
        stage = .stance
        headline = "Back to your stance"
        guard await source.awaitStance(timeout: 120), !Task.isCancelled else { return false }
        haptics.play(ReadyCue.haptic)
        return true
    }

    /// Practice swings, no count. Measures how long this player's swing
    /// takes and how hard they turn, so the count-in and the detector both
    /// fit them.
    private func learnSwing() async {
        for n in 1...practiceSwings where !Task.isCancelled {
            stage = .profiling(n)
            if n == 1 {
                announcer.sayNow("Set. Now take one full practice swing, as if a ball were there.")
                headline = "Practice swing"
                detail = "A full swing, from the stance."
            } else {
                guard await stance() else { return }
                announcer.sayNow("Once more.")
                headline = "Once more"
            }
            inbox.clear()
            let swings = await inbox.swings(notBefore: Date.timeIntervalSinceReferenceDate, firstWithin: 15, window: 1.2)
            guard let best = swings.max(by: { $0.shot.spinRate < $1.shot.spinRate }) else {
                announcer.say("Didn't catch that.")
                continue
            }
            if let measured = SwingProfile.measured(from: best.shot) {
                profile = n == 1 ? measured : profile.merging(swingDuration: measured.swingDuration, peakRotation: measured.peakRotation)
                source.profile = profile
            }
            haptics.play(HapticVocabulary.cleanStrike)
            detail = String(format: "%.2f s to contact · %.0f rad/s at the peak", best.shot.tempo.back, best.shot.spinRate)
            fixtures.save(
                best.shot, trace: best.trace, prefix: "swing-profile",
                note: "Practice swing \(n) of \(practiceSwings), no ball. Duration \(String(format: "%.2f", best.shot.tempo.back)) s, peak \(String(format: "%.1f", best.shot.spinRate)) rad/s."
            )
        }
    }

    /// One count-in and one swing, from the stance. Returns what the hand
    /// did, or nil.
    private func countAndSwing(_ delivery: Delivery, label: String) async -> (cue: Cue, answer: ShotInbox.Entry?)? {
        guard await stance() else { return nil }
        try? await Task.sleep(for: .milliseconds(500))
        if Task.isCancelled { return nil }
        let script = delivery.script(for: profile)
        let start = Date.timeIntervalSinceReferenceDate + 0.3
        let cue = Cue(script: script, startingAt: start, tolerance: delivery.tolerance(for: profile))
        inbox.clear()
        stage = .countIn
        activeScript = ActiveScript(script: script, start: start)
        headline = label
        haptics.play(script, at: start)
        clicks.schedule(script, at: start)
        let answer = await inbox.shot(for: cue, notBefore: start)
        activeScript = nil
        if Task.isCancelled { return nil }
        return (cue, answer)
    }

    private func practice(_ n: Int) async {
        let delivery = Delivery.practice
        lastDelivery = delivery
        detail = "Practice \(n) of \(practiceBalls). Beat, beat, beat, BEAT — swing."
        guard let (cue, answer) = await countAndSwing(delivery, label: "Practice \(n)") else { return }
        stage = .result
        lastResultAt = Date.timeIntervalSinceReferenceDate
        let words: String
        if let shot = answer?.shot {
            let timing = cue.timing(of: shot)
            words = timing.feedback ?? "Timed it."
            detail = String(format: "%+.0f ms", timing.error * 1000)
            haptics.play(timing.missed ? HapticVocabulary.miss : HapticVocabulary.cleanStrike)
            // Show the practice hit on the field too.
            lastBatting = Batting.play(shot: shot, delivery: delivery, cue: cue, handedness: handedness)
            fixtures.save(
                shot, trace: answer?.trace ?? [], prefix: "cricket-practice",
                note: "Practice ball \(n), beat \(String(format: "%.2f", delivery.beat(for: profile))) s. Timing \(String(format: "%+.3f s", timing.error)). Game said: \(words)"
            )
        } else {
            words = "No swing."
            haptics.play(HapticVocabulary.miss)
        }
        announcer.sayNow(words)
        headline = words
        try? await Task.sleep(for: .seconds(2.5))
    }

    private func bat() async {
        let delivery = match.nextDelivery()
        lastDelivery = delivery
        detail = "\(delivery.bowler.spoken.capitalized), \(Int(delivery.pace * 2.237)) mph"
        guard let (cue, answer) = await countAndSwing(delivery, label: "Here it comes") else { return }
        let result = Batting.play(shot: answer?.shot, delivery: delivery, cue: cue, handedness: handedness)
        stage = .result
        lastResultAt = Date.timeIntervalSinceReferenceDate
        lastBatting = result
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

        try? await Task.sleep(for: .seconds(2.5))
        if match.phase != .batting {
            headline = "Now bowl"
            detail = "Stance, buzz, then bowl when you're ready."
            announcer.say(match.phaseAnnouncement)
            try? await Task.sleep(for: .seconds(4))
        } else if match.yours.balls % 2 == 0 {
            announcer.say(match.scoreAnnouncement)
            try? await Task.sleep(for: .seconds(1.5))
        }
    }

    private func bowl() async {
        guard await stance() else { return }
        stage = .bowling
        inbox.clear()
        let armed = Date.timeIntervalSinceReferenceDate + 0.3
        headline = "Bowl when ready"
        detail = "Ball \(match.theirs.balls + 1) of \(match.ballsPerInnings)"
        guard let answer = await inbox.nextShot(notBefore: armed), !Task.isCancelled else { return }
        let ball = Bowling.ball(from: answer.shot)
        let result = Bowling.face(ball, batter: match.batter, ballIndex: match.nextBowlingIndex, seed: match.seed)
        stage = .result
        lastResultAt = Date.timeIntervalSinceReferenceDate
        lastBowling = result
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
        try? await Task.sleep(for: .seconds(2.5))
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
