import Foundation
import Testing
import SwingCore
@testable import SwingGame

@Suite("Handedness")
struct HandednessTests {

    @Test("mirroring flips the sideways direction and keeps topspin as topspin")
    func mirrorKeepsSpinSense() {
        // Travel +x, topspin: ω about −z.
        let right = TestShots.straightSwing(direction: Vector3(1, 0.1, -0.2), spinAxis: Vector3(0, 0, -1), spinRate: 20)
        let left = right.mirroredAcrossTargetLine()
        #expect(left.direction.z == -right.direction.z)
        #expect(left.direction.x == right.direction.x)
        #expect(left.spinAxis == right.spinAxis)
        #expect(abs(Ballistics.topspin(of: left) - Ballistics.topspin(of: right)) < 1e-9)
    }

    @Test("sidespin does flip when mirrored")
    func sidespinFlips() {
        // ω about +y (vertical): a right-hander's sidespin becomes the
        // left-hander's opposite sidespin.
        let right = TestShots.straightSwing(spinAxis: Vector3(0, 1, 0), spinRate: 20)
        let left = right.mirroredAcrossTargetLine()
        #expect(left.spinAxis == Vector3(0, -1, 0))
    }

    @Test("mirroring twice is the identity")
    func involution() {
        let shot = TestShots.straightSwing(direction: Vector3(1, 0.2, 0.3), spinAxis: Vector3(0.3, 0.5, 0.8), spinRate: 9)
        #expect(shot.mirroredAcrossTargetLine().mirroredAcrossTargetLine() == shot)
    }

    @Test("a right-hander's shot is unchanged")
    func rightIsIdentity() {
        let shot = TestShots.straightSwing(direction: Vector3(1, 0.2, 0.3))
        #expect(Handedness.right.asRightHanded(shot) == shot)
        #expect(Handedness.left.asRightHanded(shot) != shot)
    }
}
