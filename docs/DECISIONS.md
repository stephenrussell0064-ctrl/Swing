# Decisions

Newest first. One entry per decision that would otherwise have to be re-argued.
An entry exists so that the other person's Claude, which cannot read your
conversation, can find out why.

Format: what was decided, when, what else was considered, and what would change
our mind.

---

## 2026-09-25 — Timing sports are scored by `game/` against a `Cue`. The detector still knows nothing.

Cricket and tennis need the player to swing *at a moment*, not just to swing.
The obvious design puts that in the detector — "was the swing on time?" — and
that is exactly the design the sport-agnostic rule forbids. The
"would change our mind" clause on that rule anticipated this: *a sport that
needs the detector to reason about game state mid-motion.*

It turns out neither sport is that. `Shot` already carries `timestamp`, the
moment of release. `game/` knows when it asked for a hit, because it scheduled
the haptic script that led up to it. The difference between the two is the
timing. `Cue` (in `game/SwingGame`) is that comparison and nothing else.
`motion/` and `core/` are untouched, and a fourth timing sport (baseball,
table tennis) costs nothing there either.

Considered: a `cueTime` field on `Shot` that the detector fills in. Rejected —
it would make the detector aware that something was coming, and the field
would be meaningless for golf, bowling and darts.

Would change our mind: a sport where *which* motion to detect depends on game
state mid-swing. Still none.

## 2026-09-25 — With no screen, the game speaks and the ball is a rhythm in the hand

Two consequences of phone-only that the scaffold did not spell out and that
tennis and cricket forced:

**The phone talks.** Side calls, results, the score. Voice is not a nice-to-have
when the screen is behind your ear; it is the scoreboard. Speech synthesis, no
recorded audio, so every string in `game/` is a line the phone can say.

**An incoming ball is a `HapticScript`.** A list of `(time, event)` ending in
silence at the contact moment. One shared vocabulary across sports: quickening
ticks are a run-up, one or two ticks are a side call, a soft tap is release, a
*hard sharp tap is the bounce*, and the swing goes into the silence after it —
timed off the bounce, as the real sport is. Length, depth and pace are all
expressed as the shape of that rhythm. `game/README.md` has the table.

Considered: a haptic *at* the contact moment. Rejected — you cannot swing at a
tap you have not felt yet. The last cue has to come before the swing starts,
which is what the bounce is for.

Would change our mind: garden testing showing the bounce-to-contact gap is not
learnable by feel at cricket pace. Then the script gets a count-in.

## 2026-09-25 — A stand-in detector lives in `game/`, and dies when `motion/` lands

`game/SwingGameApp/StandIn/StandInDetector.swift` reads Core Motion and emits a
crude `Shot`. This is not a second detector and it is not a proposal. Ziggy's
prototype already does this properly, and the OPEN entry below still stands:
his code is the evidence.

It exists because the game half cannot be *felt* — the haptic rhythm, the
moment after a swing — without some `Shot` arriving when the phone is swung,
and this week the two of us cannot reach each other. It stays inside `game/`,
touches nothing in `motion/`, and knows nothing about sport.

The part that outlives it: it records every swing it reads as a `Fixture`
with its full trace. Tennis and cricket motions recorded now become the fixtures
the real detector is run against later. That re-run will change `expected` in
those files, and that diff is the review — exactly the workflow
`COLLABORATION.md` describes.

Would change our mind: nothing. It is deleted in the PR that brings `motion/`
in, and if that PR does not delete it, that is a review comment.

## 2026-09-25 — Left-handers are mirrored, and a spin axis mirrors the other way

Sports are written for the right hand; a left-hander's `Shot` is reflected
across the target line first. The sideways component of `direction` flips.
The spin axis is an axial vector, so under the same reflection the *other two*
components flip and the sideways one stays. Flip `z` on both, as the first
draft did, and a left-hander's topspin becomes slice.

Written down because it was got wrong within an hour of being written, and the
test that caught it (`HandednessTests`) is the reason it is now right.

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
