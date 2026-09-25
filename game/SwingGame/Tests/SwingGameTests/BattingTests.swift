import Foundation
import Testing
import SwingCore
@testable import SwingGame

@Suite("Cricket batting")
struct BattingTests {

    let straight = Delivery(bowler: .fast, line: 0, length: .good, pace: 36)
    let outsideOff = Delivery(bowler: .fast, line: 0.5, length: .good, pace: 36)

    @Test("no shot at a straight ball is bowled")
    func noShotStraight() {
        let r = Batting.play(shot: nil, delivery: straight, cue: TestShots.cue())
        #expect(r.outcome == .bowled)
        #expect(r.contact == .noShot)
        #expect(r.haptic == HapticVocabulary.miss)
    }

    @Test("no shot at a ball outside off is a dot, not a wicket")
    func noShotOutsideOff() {
        let r = Batting.play(shot: nil, delivery: outsideOff, cue: TestShots.cue())
        #expect(r.outcome == .dot)
    }

    @Test("a wide is a run to the batter and no ball faced, whatever the swing")
    func wide() {
        let d = Delivery(bowler: .fast, line: 1.2, length: .good, pace: 36)
        let r = Batting.play(shot: TestShots.straightSwing(), delivery: d, cue: TestShots.cue())
        #expect(r.outcome == .wide)
        #expect(r.outcome.runs == 1)
        #expect(!r.outcome.countsAsBall)
    }

    @Test("swinging far too late at a straight one is bowled")
    func tooLate() {
        let r = Batting.play(shot: TestShots.straightSwing(at: 0.4), delivery: straight, cue: TestShots.cue())
        #expect(r.outcome == .bowled)
        #expect(r.contact == .missed)
        #expect(r.timing?.grade == .tooLate)
    }

    @Test("a well-timed straight drive along the ground goes down the ground for runs")
    func straightDrive() {
        let r = Batting.play(shot: TestShots.straightSwing(speed: 12), delivery: straight, cue: TestShots.cue())
        #expect(r.contact == .middled)
        guard let f = r.flight else { Issue.record("no flight"); return }
        #expect(abs(f.angle) < 5)
        #expect(!f.lofted)
        switch r.outcome {
        case .runs, .four, .dot: break
        default: Issue.record("unexpected \(r.outcome)")
        }
    }

    @Test("hit harder, the same swing goes further")
    func harderGoesFurther() {
        let soft = Batting.play(shot: TestShots.straightSwing(speed: 8), delivery: straight, cue: TestShots.cue())
        let hard = Batting.play(shot: TestShots.straightSwing(speed: 16), delivery: straight, cue: TestShots.cue())
        #expect(soft.flight!.total < hard.flight!.total)
    }

    @Test("hit hard enough along the ground and it is four")
    func four() {
        // A swing steered away from the fielders on the straight-ish angles.
        let r = Batting.play(
            shot: TestShots.straightSwing(speed: 20, direction: Vector3(1, 0.05, 0.75)),
            delivery: straight, cue: TestShots.cue()
        )
        #expect(r.outcome == .four)
        #expect(r.haptic == HapticVocabulary.celebration)
    }

    @Test("lofted and hit hard is six")
    func six() {
        let r = Batting.play(
            shot: TestShots.straightSwing(speed: 22, direction: Vector3(1, 0.7, -0.2)),
            delivery: straight, cue: TestShots.cue()
        )
        #expect(r.flight!.lofted)
        #expect(r.outcome == .six)
    }

    @Test("lofted straight to a fielder is caught")
    func caught() {
        // Mid-off stands at 20°, 28 m. A gentle loft that lands there — most
        // of the ball's speed is the bowler's pace coming back off the bat.
        let r = Batting.play(
            shot: TestShots.straightSwing(speed: 4.7, direction: Vector3(cos(20.0.radians), 0.9, sin(20.0.radians))),
            delivery: straight, cue: TestShots.cue()
        )
        #expect(r.flight!.lofted)
        if case .caught(let by) = r.outcome {
            #expect(by == "mid-off")
        } else {
            Issue.record("expected a catch, got \(r.outcome) landing at \(r.flight!.landing())")
        }
    }

    @Test("early steers the ball to leg; late steers it to off")
    func timingSteers() {
        let early = Batting.play(shot: TestShots.straightSwing(at: -0.05, speed: 14), delivery: straight, cue: TestShots.cue())
        let late = Batting.play(shot: TestShots.straightSwing(at: 0.05, speed: 14), delivery: straight, cue: TestShots.cue())
        #expect(early.flight!.angle < 0)
        #expect(late.flight!.angle > 0)
    }

    @Test("a left-hander's leg side is on the other side of the field")
    func handedness() {
        let shot = TestShots.straightSwing(speed: 14, direction: Vector3(1, 0.05, -0.6))
        let right = Batting.play(shot: shot, delivery: straight, cue: TestShots.cue(), handedness: .right)
        let left = Batting.play(shot: shot, delivery: straight, cue: TestShots.cue(), handedness: .left)
        #expect(abs(right.flight!.angle + left.flight!.angle) < 1e-9)
    }

    @Test("badly timed but not missed is an edge")
    func edge() {
        let r = Batting.play(shot: TestShots.straightSwing(at: 0.09), delivery: straight, cue: TestShots.cue(tolerance: 0.12))
        #expect(r.contact == .edged)
        #expect(r.haptic == HapticVocabulary.mishit)
        #expect(r.announcement.hasPrefix("Edged"))
    }

    @Test("a thin edge is caught behind")
    func thinEdge() {
        let r = Batting.play(shot: TestShots.straightSwing(at: 0.11), delivery: straight, cue: TestShots.cue(tolerance: 0.12))
        #expect(r.outcome == .caught(by: "wicketkeeper"))
    }

    @Test("reaching for a wide-ish ball costs contact quality")
    func reach() {
        let shot = TestShots.straightSwing(at: 0.03, speed: 12)
        let close = Batting.play(shot: shot, delivery: straight, cue: TestShots.cue())
        let far = Batting.play(shot: shot, delivery: Delivery(bowler: .fast, line: 0.85, length: .good, pace: 36), cue: TestShots.cue())
        #expect(far.flight!.speed < close.flight!.speed)
    }
}

@Suite("Cricket field")
struct FieldTests {

    @Test("a fielder on the path stops a ground shot")
    func stops() {
        let f = Field.standard
        #expect(f.stopper(angle: 20, total: 40)?.name == "mid-off")
        #expect(f.stopper(angle: 20, total: 20) == nil)
        #expect(f.stopper(angle: 37, total: 60) == nil)
    }

    @Test("a lofted ball landing on a fielder is caught")
    func catches() {
        let f = Field.standard
        let cover = f.fielders.first { $0.name == "cover" }!
        let p = cover.position
        #expect(f.catcher(landingAt: (p.x + 3, p.z - 2))?.name == "cover")
        #expect(f.catcher(landingAt: (p.x + 20, p.z)) == nil)
    }
}
