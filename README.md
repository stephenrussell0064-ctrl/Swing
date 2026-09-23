# Swing

One iPhone. You hold it in your hand and swing, roll, or throw it, and it plays
the shot: golf, bowling, darts, and whatever else fits in the hand.

No second screen. No Mac, no Apple TV, no pairing, nothing to set up. Install it,
stand up, swing.

## The three parts

| Part | What it is | Lives in |
| --- | --- | --- |
| **Motion** | Core Motion at 100 Hz, calibration, swing detection, fixture recording. Produces a `Shot`. | `motion/` |
| **Core** | `SwingCore`: the `Shot` type and the play frame. The seam between the other two. | `core/` |
| **Game** | Sport rules, physics, scoring, what you see. Consumes a `Shot`. | `game/` |

The seam is the whole point: `motion/` describes a motion in physics and knows
nothing about sport; `game/` decides what that motion meant. So a new sport costs
nothing in the hardest code in the app, and two people can build at once without
meeting in the same file.

## Status

Early. The scaffold has already been reversed once on something fundamental —
see the top of [docs/DECISIONS.md](docs/DECISIONS.md), which is worth reading
before you trust anything else in here. Ziggy's working golf prototype lands
next, and it is the first real code.

## Working on this

Two people, two machines, two Claude accounts, one repository. Read
[docs/COLLABORATION.md](docs/COLLABORATION.md) before your first branch — it is
short, and it is the difference between this working and this being a merge
conflict every evening. Then [docs/JOINING.md](docs/JOINING.md) for setup.
