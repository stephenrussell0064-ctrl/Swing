import Foundation
import Testing
import SwingCore
@testable import SwingGame

@Suite("Cue and timing")
struct CueTests {

    @Test("a shot exactly on the cue is perfect")
    func perfect() {
        let t = TestShots.cue().timing(of: TestShots.straightSwing())
        #expect(t.error == 0)
        #expect(t.quality == 1)
        #expect(t.grade == .perfect)
        #expect(!t.missed)
    }

    @Test("quality falls off quadratically, so a small error costs little")
    func quadratic() {
        let cue = TestShots.cue(tolerance: 0.1)
        let small = cue.timing(of: TestShots.straightSwing(at: 0.02)).quality
        let half = cue.timing(of: TestShots.straightSwing(at: 0.05)).quality
        let edge = cue.timing(of: TestShots.straightSwing(at: 0.1)).quality
        #expect(abs(small - 0.96) < 1e-9)
        #expect(abs(half - 0.75) < 1e-9)
        #expect(edge == 0)
    }

    @Test("early is negative and late is positive")
    func sign() {
        let cue = TestShots.cue(tolerance: 0.1)
        #expect(cue.timing(of: TestShots.straightSwing(at: -0.05)).grade == .early)
        #expect(cue.timing(of: TestShots.straightSwing(at: 0.05)).grade == .late)
        #expect(cue.timing(of: TestShots.straightSwing(at: -0.2)).grade == .tooEarly)
        #expect(cue.timing(of: TestShots.straightSwing(at: 0.2)).grade == .tooLate)
        #expect(cue.timing(of: TestShots.straightSwing(at: 0.2)).missed)
    }

    @Test("a cue built from a script lands on the script's contact moment")
    func fromScript() {
        let d = Delivery(bowler: .fast, line: 0, length: .good, pace: 36)
        let script = d.script()
        let cue = Cue(script: script, startingAt: 500, tolerance: d.tolerance)
        #expect(cue.contactTime == 500 + script.contactAt)
        #expect(cue.deadline > cue.contactTime)
    }
}

@Suite("Haptic scripts")
struct HapticScriptTests {

    @Test("a delivery's script ends in silence: the last cue is the bounce, before contact")
    func bounceBeforeContact() {
        for length in Delivery.Length.allCases where length != .fullToss {
            let d = Delivery(bowler: .medium, line: 0, length: length, pace: 30)
            let s = d.script()
            let last = s.entries.last!
            #expect(last.event == HapticVocabulary.bounce)
            #expect(last.at < s.contactAt)
        }
    }

    @Test("a yorker bounces later than a short ball")
    func lengthOrdersTheBounce() {
        func bounceAt(_ l: Delivery.Length) -> TimeInterval {
            Delivery(bowler: .fast, line: 0, length: l, pace: 36).script().entries.last!.at
        }
        #expect(bounceAt(.short) < bounceAt(.good))
        #expect(bounceAt(.good) < bounceAt(.full))
        #expect(bounceAt(.full) < bounceAt(.yorker))
    }

    @Test("a full toss has no bounce")
    func fullToss() {
        let s = Delivery(bowler: .fast, line: 0, length: .fullToss, pace: 36).script()
        #expect(!s.entries.contains { $0.event == HapticVocabulary.bounce })
    }

    @Test("a fast bowler's run-up quickens toward release")
    func runUpQuickens() {
        let s = Delivery(bowler: .fast, line: 0, length: .good, pace: 36).script()
        let ticks = s.entries.filter { $0.event == HapticVocabulary.tick }.map(\.at)
        #expect(ticks.count == 5)
        let gaps = zip(ticks.dropFirst(), ticks).map { $0 - $1 }
        for (a, b) in zip(gaps, gaps.dropFirst()) {
            #expect(b < a)
        }
    }

    @Test("a spinner takes less time to arrive at the crease than a quick, but the ball takes longer")
    func spinnerTempo() {
        let quick = Delivery(bowler: .fast, line: 0, length: .good, pace: 37)
        let spin = Delivery(bowler: .spin, line: 0, length: .good, pace: 20)
        #expect(spin.bowler.runUp < quick.bowler.runUp)
        #expect(spin.flightTime > quick.flightTime)
        #expect(spin.tolerance > quick.tolerance)
    }

    @Test("tennis: forehand is one tick, backhand is two, then the same bounce cue as cricket")
    func tennisSideCue() {
        let fh = IncomingBall(side: .forehand, pace: 25, depth: 0.7).script()
        let bh = IncomingBall(side: .backhand, pace: 25, depth: 0.7).script()
        #expect(fh.entries.filter { $0.event == HapticVocabulary.tick }.count == 1)
        #expect(bh.entries.filter { $0.event == HapticVocabulary.tick }.count == 2)
        #expect(fh.entries.last!.event == HapticVocabulary.bounce)
        #expect(fh.entries.last!.at < fh.contactAt)
    }

    @Test("script entries are kept in time order however they were given")
    func sorted() {
        let s = HapticScript(
            entries: [.init(at: 1, event: HapticVocabulary.tick), .init(at: 0, event: HapticVocabulary.bounce)],
            contactAt: 2
        )
        #expect(s.entries.map(\.at) == [0, 1])
        #expect(s.duration == 1)
    }
}
