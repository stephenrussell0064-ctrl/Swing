# Architecture

One iPhone app. No second screen, no Mac, no Apple TV, nothing to pair. You
install it, stand up, and swing.

## The one idea

**The half that reads the hand does not know what golf is.**

`motion/` measures a motion and describes it in physics: how fast, in what
direction, spinning about which axis, with what tempo. `game/` decides whether
those numbers mean a 240-yard drive, a strike, or double top.

Everything follows from this:

- A new sport is a `game/` change. `motion/` is not touched, not rebuilt in your
  head, not re-tuned.
- Swing detection can be tuned against recorded swings forever without anyone
  agreeing on how golf works.
- The interesting, opinionated work — ball flight, pin physics, scoring — is all
  in one place and it is all pure functions over a `Shot`.
- Two people can build at once without meeting in the same file.

If `driver`, `strike` or `bullseye` ever appear in `motion/`, the design has
leaked and it comes back out.

## The three parts

| | What | Owner |
| --- | --- | --- |
| `motion/` | Core Motion at 100 Hz, calibration, swing detection, fixture recording. Produces a `Shot`. | one of us |
| `core/` | `SwingCore`: the `Shot` type, the play frame, `MotionSample`, `Fixture`. The seam. | both, by PR |
| `game/` | Sport modules, physics, scoring, SwiftUI. Consumes a `Shot`. | the other |

## motion/

**Calibrate.** The player holds the phone and points it down the target line —
where they mean the ball to go. That fixes the play frame. With no screen in the
room there is nothing else to aim at, so the player's declared line is the only
reference the game has, and getting this to feel unfussy is real work.

**Detect.** A swing is a window, not an instant. Watch the magnitude of rotation
rate cross a threshold, hold the ring buffer, find the peak, then find release —
maximum speed, just before the sharp deceleration. Detection is retrospective,
which is what lets it be careful.

**Describe.** Reduce the window to a `Shot`. Fire a haptic at release, so the
hand gets its feedback when it expects it rather than when the screen catches up.
With no second screen the haptic is doing more work than it would otherwise: for
the length of the follow-through it is the only feedback there is.

**Record.** Any detected swing can be written to `fixtures/` with its full trace.
A debug feature that is really the test suite.

## core/

`SwingCore`, a Swift package. `Shot` is the seam: `motion/` produces it, `game/`
consumes it, neither knows anything else about the other.

It is **not** a wire format — nothing leaves the phone. But `Shot` is still
`Codable` with pinned field names, because fixtures are committed and outlive the
build that wrote them. A renamed field is a recorded swing nobody can read again.

## game/

SwiftUI. Owns:

- **Sport modules** — one per sport, each a pure mapping from `Shot` to outcome.
  Golf: launch, spin, carry, run, lie. Bowling: entry angle, pin cascade. Darts:
  board coordinate.
- **Game loop and rules** — turns, scoring, players.
- **What you see**, and the shape of the moment after a shot — which is the whole
  game, because the phone is in your hand and you look at it *after* you swing,
  not during.
- **Fixture replay** — feed a recorded `Shot` in as though it had just been
  swung. Build and tune the entire game sitting down.

## Testing

| Layer | How |
| --- | --- |
| Detection | Replay `fixtures/*.json`, assert the emitted `Shot`. Changes show as a diff in the numbers. |
| Sport modules | Pure functions. Table tests: this `Shot` in, this outcome out. |
| The feel | One phone, one human, one garden. Rare, irreplaceable, and the only test that actually matters. |
