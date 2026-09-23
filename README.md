# Swing

An iPhone is the controller. You hold it in your hand and swing, roll, or throw it,
and a game on a nearby screen plays the shot: golf, bowling, darts, and whatever
else fits in the hand.

The phone does not draw the game. It reads the motion, decides that a swing
happened, describes that swing in a few numbers, and sends it. Everything else —
physics, scoring, what you see — happens on the host.

## The three pieces

| Piece | What it is | Lives in |
| --- | --- | --- |
| **Controller** | iOS app. Core Motion at 100 Hz, swing detection, calibration, haptics. Sends a `Shot`. | `controller/` |
| **Protocol** | The `Shot` event and the discovery/handshake rules. The contract between the other two. | `protocol/` |
| **Host** | Runs the game. Physics, sport rules, scoring, rendering. Receives a `Shot`. | `host/` |

The protocol is the whole point of the split: once a `Shot` is defined, the
controller and the host can be built at the same time, on different machines, by
people who are not in the same room — and tested apart, because a recorded swing
is just a file.

## Status

Nothing is built yet. Two decisions are still open and are recorded in
[docs/DECISIONS.md](docs/DECISIONS.md): what the host runs on, and what the
transport is.

## Working on this

Two people, two machines, two Claude accounts, one repository. Read
[docs/COLLABORATION.md](docs/COLLABORATION.md) before your first branch — it is
short, and it is the difference between this working and this being a merge
conflict every evening.
