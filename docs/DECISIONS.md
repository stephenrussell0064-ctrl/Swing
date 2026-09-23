# Decisions

Newest first. One entry per decision that would otherwise have to be re-argued.
An entry exists so that the other person's Claude, which cannot read your
conversation, can find out why.

Format: what was decided, when, what else was considered, and what would change
our mind.

---

## 2026-09-23 — The host is a macOS app, and the protocol is a Swift package

SwiftUI, with SceneKit for the play view. Both of us are on Macs with Xcode, so
Swift on both sides costs nothing and buys the thing that matters: `protocol/` is
one package that the phone and the host both import, and the `Shot` schema
therefore cannot drift. A web host would have meant defining `Shot` twice and
writing a test to keep the two honest.

Considered: a LAN web page (Three.js) — the right answer only if one of us could
not build for iOS; tvOS — the best living-room feel and the worst development
loop.

Would change our mind: wanting to play on a TV without an Apple TV, or a third
person joining who is not on a Mac. Neither is true today. The sport modules are
pure functions over a `Shot`, so a second front end later is a rendering job, not
a rewrite.

## 2026-09-23 — Transport is Network.framework over Bonjour

Service type `_swing._tcp`. The phone browses, finds the host, handshakes on
protocol version.

A `Shot` is one small message, so this was never a latency decision — it becomes
one only for the live motion stream that draws the backswing on screen, and
Network.framework handles that on a LAN without trying.

Considered: Multipeer Connectivity, which needs no network at all. Worth
remembering if two phones playing each other ever matters.

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
