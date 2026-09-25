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
        #expect(t.feedback == nil)
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

    @Test("early is negative and late is positive, and the phone says which")
    func sign() {
        let cue = TestShots.cue(tolerance: 0.1)
        #expect(cue.timing(of: TestShots.straightSwing(at: -0.05)).grade == .early)
        #expect(cue.timing(of: TestShots.straightSwing(at: 0.05)).grade == .late)
        #expect(cue.timing(of: TestShots.straightSwing(at: -0.2)).grade == .tooEarly)
        #expect(cue.timing(of: TestShots.straightSwing(at: 0.2)).grade == .tooLate)
        #expect(cue.timing(of: TestShots.straightSwing(at: 0.2)).missed)
        #expect(cue.timing(of: TestShots.straightSwing(at: 0.05)).feedback == "A touch late.")
        #expect(cue.timing(of: TestShots.straightSwing(at: -0.2)).feedback == "Too early, by 200 milliseconds.")
        #expect(cue.timing(of: TestShots.straightSwing(at: 0.6)).feedback == "Way too late.")
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

@Suite("Count-in scripts")
struct HapticScriptTests {

    @Test("beats are evenly spaced, the last is accented, and contact is one beat after it")
    func grid() {
        for bowler in Delivery.Bowler.allCases {
            let d = Delivery(bowler: bowler, line: 0, length: .good, pace: 30)
            let s = d.script()
            let times = s.entries.map(\.at)
            #expect(times.count == bowler.beats)
            let gaps = zip(times.dropFirst(), times).map { $0 - $1 }
            for g in gaps { #expect(abs(g - bowler.beat) < 1e-9) }
            #expect(s.entries.last!.event == HapticVocabulary.accent)
            #expect(s.entries.dropLast().allSatisfy { $0.event == HapticVocabulary.beat })
            #expect(abs(s.contactAt - (times.last! + bowler.beat)) < 1e-9)
        }
    }

    @Test("the last cue comes before contact: nothing is played at the moment to swing")
    func silenceAtContact() {
        let s = Delivery(bowler: .fast, line: 0, length: .yorker, pace: 38).script()
        #expect(s.duration < s.contactAt)
        #expect(!s.entries.contains { abs($0.at - s.contactAt) < 1e-9 })
    }

    @Test("length does not move the grid — it is unlearnable at pace, so it only changes the outcome")
    func lengthDoesNotMoveGrid() {
        let scripts = Delivery.Length.allCases.map { Delivery(bowler: .fast, line: 0, length: $0, pace: 36).script() }
        #expect(Set(scripts).count == 1)
    }

    @Test("a quick bowler's beat is shorter than a spinner's, and the window with it")
    func paceSetsTheBeat() {
        let quick = Delivery(bowler: .fast, line: 0, length: .good, pace: 37)
        let spin = Delivery(bowler: .spin, line: 0, length: .good, pace: 20)
        #expect(quick.bowler.beat < spin.bowler.beat)
        #expect(quick.tolerance < spin.tolerance)
        #expect(quick.tolerance >= 0.14)
        #expect(spin.tolerance <= 0.24)
    }

    @Test("tennis: forehand is one tick, backhand is two, then the same count-in")
    func tennisSideCue() {
        let fh = IncomingBall(side: .forehand, pace: 25, depth: 0.7)
        let bh = IncomingBall(side: .backhand, pace: 25, depth: 0.7)
        let fs = fh.script(), bs = bh.script()
        #expect(fs.entries.filter { $0.event == HapticVocabulary.tick }.count == 1)
        #expect(bs.entries.filter { $0.event == HapticVocabulary.tick }.count == 2)
        #expect(fs.entries.filter { $0.event == HapticVocabulary.beat }.count == 2)
        #expect(fs.entries.last!.event == HapticVocabulary.accent)
        #expect(abs(fs.contactAt - (fs.entries.last!.at + fh.beat)) < 1e-9)
        // The beats start after the side call, with time to move the hand.
        #expect(fs.entries.first { $0.event == HapticVocabulary.beat }!.at == IncomingBall.sideLead)
    }

    @Test("a harder tennis ball is a shorter beat, within human limits")
    func tennisBeat() {
        let soft = IncomingBall(side: .forehand, pace: 18, depth: 0.5)
        let hard = IncomingBall(side: .forehand, pace: 34, depth: 0.5)
        #expect(soft.beat > hard.beat)
        #expect(hard.beat >= 0.42)
        #expect(soft.beat <= 0.68)
    }

    @Test("their serve has no side call and a longer count")
    func serveScript() {
        let s = IncomingBall(side: .forehand, pace: 30, depth: 0.8, isServe: true).script()
        #expect(!s.entries.contains { $0.event == HapticVocabulary.tick })
        #expect(s.entries.count == 4)
        #expect(Serve.script.entries.count == 3)
        #expect(Serve.script.entries.last!.event == HapticVocabulary.accent)
    }

    @Test("script entries are kept in time order however they were given")
    func sorted() {
        let s = HapticScript(
            entries: [.init(at: 1, event: HapticVocabulary.tick), .init(at: 0, event: HapticVocabulary.accent)],
            contactAt: 2
        )
        #expect(s.entries.map(\.at) == [0, 1])
        #expect(s.duration == 1)
    }
}
