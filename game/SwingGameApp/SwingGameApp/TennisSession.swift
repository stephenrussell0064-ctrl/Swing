import Foundation
import SwingCore
import SwingGame

/// Drives a `TennisMatch` on a real clock. Says which side, plays the ball's
/// rhythm into the hand, waits, scores, and keeps the rally going.
@MainActor
@Observable
final class TennisSession {
    private(set) var match: TennisMatch
    private(set) var headline = "Tennis"
    private(set) var detail = ""
    private(set) var isRunning = false

    let handedness: Handedness
    private let source: any ShotSource
    private let inbox = ShotInbox()
    private let haptics: HapticPlayer
    private let announcer: Announcer
    private let fixtures = FixtureStore.shared
    private var loop: Task<Void, Never>?

    init(source: any ShotSource, haptics: HapticPlayer, announcer: Announcer, handedness: Handedness) {
        self.match = TennisMatch(opponent: .clubPlayer, handedness: handedness, server: .you, gamesToWin: 4, seed: UInt64(Date().timeIntervalSince1970))
        self.source = source
        self.haptics = haptics
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
        match = TennisMatch(opponent: .clubPlayer, handedness: handedness, server: .you, gamesToWin: 4, seed: UInt64(Date().timeIntervalSince1970))
        start()
    }

    private func run() async {
        announcer.say("First to four games. One tap is forehand, two is backhand. Swing after the bounce.")
        headline = "First to four games"
        detail = "One tap forehand, two taps backhand."
        try? await Task.sleep(for: .seconds(4.5))

        var nextStartDelay: TimeInterval = 0.6
        while !Task.isCancelled {
            guard let (script, tolerance) = match.nextScript else {
                if case .over = match.state {
                    headline = match.score.gameAnnouncement
                    detail = "Tap Restart to play again."
                    isRunning = false
                }
                return
            }
            if let prompt = match.prompt {
                announcer.sayNow(prompt)
                headline = prompt
            }
            let start = Date.timeIntervalSinceReferenceDate + nextStartDelay
            let cue = Cue(script: script, startingAt: start, tolerance: tolerance)
            inbox.clear()
            haptics.play(script, at: start)
            if case .incoming(let ball, _) = match.state {
                detail = String(format: "%@ · %.0f mph", ball.side.rawValue.capitalized, ball.pace * 2.237)
            } else {
                detail = "Swing at the top of the toss."
            }

            let answer = await inbox.shot(for: cue, notBefore: start)
            if Task.isCancelled { return }
            let stateBefore = match.state
            let step = match.play(answer?.shot, cue: cue)
            haptics.play(step.stroke.haptic)
            announcer.sayNow(step.stroke.announcement)
            headline = step.stroke.announcement
            detail = describe(step)

            if let answer {
                let what: String
                switch stateBefore {
                case .yourServe: what = "Serve"
                case .incoming(let ball, let n): what = "\(ball.side.rawValue.capitalized) return, stroke \(n), ball at \(Int(ball.pace)) m/s"
                case .over: what = ""
                }
                fixtures.save(
                    answer.shot, trace: answer.trace, prefix: "tennis",
                    note: "\(what). Timing \(step.stroke.timing.map { String(format: "%+.3f s", $0.error) } ?? "n/a"). Game said: \(step.stroke.announcement)"
                )
            }

            if step.rallyContinues {
                // Their reply is on its way: the next script's own lead-in is
                // the time the ball takes to cross the net.
                nextStartDelay = 0.5
            } else {
                if let announcement = step.announcement {
                    try? await Task.sleep(for: .seconds(1.2))
                    announcer.say(announcement)
                    headline = announcement
                }
                nextStartDelay = 1.0
                try? await Task.sleep(for: .seconds(2.8))
            }
        }
    }

    private func describe(_ step: TennisMatch.Step) -> String {
        var parts: [String] = []
        if let t = step.stroke.timing {
            parts.append(String(format: "%+.0f ms", t.error * 1000))
        }
        if case .inPlay(let p) = step.stroke.outcome {
            parts.append(String(format: "%.1f m %@, depth %.0f%%", abs(p.lateral), p.lateral < 0 ? "left" : "right", p.depth * 100))
        }
        parts.append(match.score.pointAnnouncement)
        return parts.joined(separator: " · ")
    }
}
