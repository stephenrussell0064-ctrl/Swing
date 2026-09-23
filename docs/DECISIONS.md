# Decisions

Newest first. One entry per decision that would otherwise have to be re-argued.
An entry exists so that the other person's Claude, which cannot read your
conversation, can find out why.

Format: what was decided, when, what else was considered, and what would change
our mind.

---

## 2026-09-23 — Swing runs entirely on the phone. There is no second screen.

**This reverses two entries below, both made the same day.** They are kept
struck through rather than deleted, because how the scaffold got it wrong is
worth more than the scaffold being tidy.

One iPhone app. No Mac, no Apple TV, no LAN, no pairing. Install it, stand up,
swing.

Ziggy raised this against the scaffold, and he was right. The reason the
scaffold said otherwise is embarrassing and instructive — read the struck-through
entry below and the argument for a macOS host is, in its own words, *"Both of us
are on Macs with Xcode, so Swift on both sides costs nothing."* That is a reason
about the two people building it, not about anyone playing it. Architecture that
optimises for the builders' hardware will do this every time.

Picture what the rejected design actually asked for: a MacBook propped up
somewhere in the room, pointed at the spot where you are about to swing a phone.
Nobody owns that setup and nobody is going to build it to try a game. Phone-only
is install-and-play, anywhere, which is most of the difference between a thing
people try and a thing people read about.

What survives the reversal: `Shot`, and the rule that the half reading the hand
knows nothing about sport. It stops being a network protocol and becomes an
internal seam — which is all it ever needed to be, and it is still what lets two
people build at once and lets a fourth sport cost nothing in `motion/`.

What dies: `Wire` — Bonjour, the handshake, version negotiation, the two message
enums. Deleted rather than parked. Dead code nobody runs is code that rots, and
the sport modules being pure functions over a `Shot` means a screen could be
added later as a rendering job, exactly as the struck-through entry claimed.

Would change our mind: a genuinely good reason to put the game on a television —
not a Mac — that survives the question *"would someone set this up before they
had ever played it?"*

## 2026-09-23 — `motion/` and `game/`, one seam, one owner each

Replaces `controller/` and `host/`, which named two apps that no longer exist.
`core/` (was `protocol/`) holds the seam. See [COLLABORATION.md](COLLABORATION.md)
and [ARCHITECTURE.md](ARCHITECTURE.md).

---

## OPEN — Ziggy's prototype already detects a golf swing, and this repo does not

There is working code that predates everything here: a basic setup that reads a
golf swing on the phone. Nothing in this repository has ever detected anything.

So the architecture is a proposal and that prototype is evidence, and the
evidence wins where they disagree. It already has, once, on something bigger than
anyone expected — see the top entry.

Resolve it the same way: the prototype lands as a branch and a pull request, both
of us read it, and only then do we decide what of the scaffold is worth keeping.
Do not refactor working swing detection to satisfy a document.

## 2026-09-23 — The half that reads the hand is sport-agnostic

`motion/` emits kinematics; `game/` interprets them. See
[ARCHITECTURE.md](ARCHITECTURE.md).

Considered: putting golf in the detector, which is simpler for exactly one sport
and wrong for the second. Rejected because it puts both of us in the same files
and makes every new sport a change to the hardest, most-tuned code in the app.

Note this was originally argued as *"no App Store round trip per sport"* — which
was only true when the game lived on a separate machine. Phone-only means every
sport ships in an app update regardless. The argument that survives is the one
about keeping detection stable and the two of us out of each other's way.

Would change our mind: a sport that genuinely cannot be derived from the release
window and needs the detector to reason about game state mid-motion. None of
golf, bowling or darts is that.

---

## ~~2026-09-23 — The host is a macOS app, and the protocol is a Swift package~~

**Superseded.** Reversed the same day by the top entry. Kept for the record.

> SwiftUI, with SceneKit for the play view. Both of us are on Macs with Xcode, so
> Swift on both sides costs nothing and buys the thing that matters: `protocol/`
> is one package that the phone and the host both import, and the `Shot` schema
> therefore cannot drift.
>
> Considered: a LAN web page (Three.js); tvOS — the best living-room feel and the
> worst development loop.
>
> Would change our mind: wanting to play on a TV without an Apple TV, or a third
> person joining who is not on a Mac.

The "would change our mind" clause did not anticipate the actual objection, which
was that no second screen should be required at all. Write that clause about the
player next time, not about the team.

## ~~2026-09-23 — Transport is Network.framework over Bonjour~~

**Superseded.** There is no transport. Nothing leaves the phone.

> Service type `_swing._tcp`. The phone browses, finds the host, handshakes on
> protocol version. Considered: Multipeer Connectivity, which needs no network at
> all — worth remembering if two phones playing each other ever matters.

That last line is the only part still worth keeping: two phones, no network, is a
real idea for a future where two people play in the same garden.
