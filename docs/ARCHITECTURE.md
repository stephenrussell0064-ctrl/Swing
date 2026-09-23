# Architecture

## The one idea

**The controller does not know what golf is.**

It measures a motion of the hand and describes it in physics: how fast, in what
direction, spinning about which axis, with what tempo. It sends that. The host
decides whether those numbers mean a 240-yard drive, a strike, or double top.

Everything follows from this:

- A new sport is a host-only change. No phone rebuild, no App Store round trip,
  no touching the other person's directory.
- The controller can be tuned against recorded swings forever without anyone
  agreeing on how golf works.
- The interesting, opinionated, fun work — ball flight, pin physics, scoring —
  is all in one place, and it is all pure functions over a `Shot`.

If you ever find `driver`, `strike` or `bullseye` in `controller/`, the design has
leaked and it should come back out.

## Controller (`controller/`)

iOS, Swift, Core Motion at 100 Hz (`CMDeviceMotion` — attitude, rotation rate,
user acceleration, gravity).

**Calibrate.** Before play, the user holds the phone and points it at the screen.
That fixes a frame: down-the-line, up, and across. Without this, "direction" is a
number about the Earth rather than about the game, and it is meaningless.

**Detect.** A swing is a window, not an instant. Watch for the magnitude of
rotation rate crossing a threshold, hold the buffer, find the peak, then find
release — the moment of maximum speed, just before the sharp deceleration.
Everything is computed from the ring buffer around that moment, which means
detection is retrospective and can be as careful as it likes.

**Describe.** Reduce the window to a `Shot` and send it. Fire a haptic on
release so the hand gets the feedback at the moment it expects it, not when the
screen catches up.

**Record.** Every detected swing can be written to `fixtures/` with its full
trace. This is a debug feature that is really the test suite.

## Protocol (`protocol/`)

Draft `Shot`, version 1 — expect this to move before anything is built:

```jsonc
{
  "v": 1,
  "id": "uuid",
  "t": 1737630000.123,      // release, device clock
  "kind": "swing",          // swing | roll | throw
  "releaseSpeed": 28.9,     // m/s
  "peakSpeed": 31.4,
  "direction": [0.98, 0.04, -0.19],  // unit vector, calibrated frame
  "attitude":  [0.71, 0.0, 0.70, 0.0], // quaternion at release
  "spinAxis":  [0.1, 0.99, 0.0],
  "spinRate":  12.3,        // rad/s about spinAxis
  "tempo": { "back": 0.78, "through": 0.26 },  // seconds
  "confidence": 0.86
}
```

Also here: discovery and handshake (how a phone finds the host on the LAN and
agrees a protocol version), and the optional live motion stream used to draw the
backswing on screen as it happens.

`v` is not decoration. The phone and the host will be at different versions on
someone's sofa at some point, and the handshake has to notice.

## Host (`host/`)

Receives `Shot`. Owns:

- **Sport modules** — one per sport, each a pure mapping from `Shot` to outcome.
  Golf: launch, spin, carry, run, lie. Bowling: entry angle, pin cascade.
  Darts: board coordinate.
- **Game loop and rules** — turns, scoring, players.
- **Rendering.**
- **Fixture replay** — feed a recorded `Shot` in as though a phone had sent it.
  Build the entire game with no phone attached.

## Testing

| Layer | How |
| --- | --- |
| Detection | Replay `fixtures/*.json`, assert the emitted `Shot`. Changes show as a diff in the numbers. |
| Sport modules | Pure functions. Table tests: this `Shot` in, this outcome out. |
| End to end | One phone, one host, one human, one evening. Rare, and that is the point. |
