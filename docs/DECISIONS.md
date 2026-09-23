# Decisions

Newest first. One entry per decision that would otherwise have to be re-argued.
An entry exists so that the other person's Claude, which cannot read your
conversation, can find out why.

Format: what was decided, when, what else was considered, and what would change
our mind.

---

## OPEN — What does the host run on?

Blocks: the host language, whether a physics core can be shared with the phone,
and where the game is actually played.

- **macOS app** (SwiftUI + SceneKit/RealityKit). Swift on both sides, so
  `protocol/` becomes a Swift package both targets import and the schema cannot
  drift. Needs both of us on a Mac with Xcode.
- **Web** (TypeScript + Three.js, served on the LAN). Runs on any screen with a
  browser, including a TV. Lets a collaborator without a Mac own the whole host.
  Cost: the `Shot` schema exists twice, in Swift and in TypeScript, and has to be
  kept honest by a test.
- **tvOS.** The best living-room answer and the worst development loop. Later,
  not first.

## OPEN — Transport

Not urgent: a `Shot` is one small message, so nothing here is a latency problem.
It becomes one only if we stream live motion to draw the backswing on screen.

- Network.framework + Bonjour (`_swing._tcp`) if the host is Swift.
- WebSocket over the LAN if the host is web.
- Multipeer Connectivity — phone-to-phone without a network, worth remembering if
  two players on two phones ever matters.

---

## 2026-09-23 — The controller is sport-agnostic

The phone emits kinematics; the host interprets them. See
[ARCHITECTURE.md](ARCHITECTURE.md).

Considered: putting golf in the phone, which is simpler for exactly one sport and
wrong for the second. Rejected because it makes every new sport an App Store
release and puts both of us in the same files.

Would change our mind: a sport that genuinely cannot be derived from the release
window and needs the phone to reason about game state mid-motion. None of golf,
bowling or darts is that.

## 2026-09-23 — Two directories, two owners, one shared protocol

See [COLLABORATION.md](COLLABORATION.md).
