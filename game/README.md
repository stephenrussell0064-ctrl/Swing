# game/

The half that decides what a motion meant. Stephen's directory.

Two things live here:

| | What | Runs where |
| --- | --- | --- |
| `SwingGame/` | Swift package. Sports as pure functions over a `Shot`, the timing model, scoring, fixture replay. No Core Motion, no UIKit. | `swift test`, on a Mac |
| `SwingGameApp/` | Xcode project. Haptics, voice, the play screen, and the sessions that run a sport on a real clock. | an iPhone |

```bash
cd game/SwingGame && swift test
open game/SwingGameApp/SwingGameApp.xcodeproj
```

The app needs a signing team set in Xcode once (Signing & Capabilities) before
it goes on a phone. Nothing else to configure.

## How a game works when you cannot look at it

The phone is in your hand and you are swinging it. For the whole of a shot the
screen is somewhere behind your ear. So the game talks to the hand and the ear,
and the screen is for the glance afterwards.

**The hand and the ear: a count-in.** Every ball the game sends at you is a
`HapticScript` — evenly spaced beats, felt as haptic taps *and* heard as clicks
through the speaker, with the last beat accented and contact exactly one beat
later. You swing on a beat nobody plays, the way you clap on a downbeat you
can already hear coming. The vocabulary is shared across sports so it only has
to be learned once:

| Feel / hear | Means |
| --- | --- |
| quiet tick, or two | tennis: forehand / backhand |
| **beat, beat, beat** | the count-in. Lock on to the interval |
| **BEAT** (high, hard) | the last one — the bounce. Swing so you meet the *next* beat |
| silence | contact. Your swing is already moving |
| crisp click | you middled it |
| dull click and a fizz | you got an edge, or a frame |
| long low buzz | you missed |
| three rising clicks | boundary, winner, wicket |

Pace is the interval: a quick bowler counts at 0.46 s, a spinner at 0.70 s, a
hard tennis drive at 0.42 s. Nothing else moves the grid. The first version
tried to encode length as the gap between bounce and contact and it was not
playable — see `docs/DECISIONS.md` for why. After every ball the phone says how
your timing was ("A touch late." "Too early, by 180 milliseconds.") so the grid
can be learned in a few balls.

**The ear: the phone speaks.** Side calls ("Forehand."), results ("Four!",
"Edged, caught behind!"), and the score between balls. The voice is the
scoreboard.

**The clock.** A `Cue` is the contact moment in the same clock as
`Shot.timestamp`. The game schedules the script against it; `motion/` (or the
stand-in) reports when the hand released; the difference is the timing. The
detector never knows a ball was coming. This is what lets timing sports exist
without touching `core/` or `motion/` — see `docs/DECISIONS.md`.

## Cricket

Bat an over, then bowl one, higher total wins. Three wickets each.

**Batting.** Four beats (three for a spinner), the last one high. Swing to meet
the next. Then:

- Timing (`Shot.timestamp` against the `Cue`) is contact quality. Miss the
  window and a straight ball bowls you; a ball outside off is a dot.
- Early steers the ball to leg, late to off — the bat has come round further.
- Swing direction is the shot's direction; elevation lofts it; speed carries it.
  Lofted onto a fielder is caught. Past the rope along the ground is four, over
  it is six. Otherwise runs by distance, unless a fielder is on the line.
- Poor contact quality is an edge: behind square on the off side, or into the
  keeper's gloves if it was thin.

**Bowling.** No cue: bowl when ready. Hand speed becomes ball speed; the release
angle sets the length (flatter is fuller); yaw off the calibrated line sets the
line; fast rotation about a vertical axis is spin and turns it. The phone's
batter (`Batter`) replies deterministically from a seeded luck stream, so the
same ball at the same index always gets the same treatment.

## Tennis

One set, first to four games. You serve first.

The screen cannot show a court, so the design refuses to need one. The ball is
always coming *to you*: the opponent's shot is a side call plus a script, you
swing into the silence, and the game works out where yours went from timing,
direction, speed and spin. If it lands in, the opponent either gets it back —
another side call, another script, the rally goes on — or does not, and you
hear the score.

- **Side.** "Forehand." with one tick, or "Backhand." with two, 0.7 s before
  the count starts, which is long enough to move the hand across. Then three
  beats, the last one high, and you swing to meet the fourth.
- **Placement.** Early on a forehand goes cross-court, late goes down the line
  (mirrored for the backhand). Yaw adds to that. Past 4.1 m from centre is wide.
- **Depth.** Speed and the racket-face launch angle. The hand's elevation is
  compressed by half — a groundstroke path is much steeper than the ball's
  flight — and topspin (rotation about a horizontal axis with `ω × v` pointing
  down) pulls a hard ball back inside the baseline. Slice floats it.
- **Your serve.** Three beats, hit on the fourth. Must land in the service
  box; two faults is the point.
- **Scoring.** Standard, spoken with your score first because you are the one
  who cannot see it. No tiebreak yet: 7–6 ends a set.

What is *not* detected: whether the swing was actually a forehand or a
backhand. Direction of travel cannot tell them apart from an angled shot.
`Shot.attitude` (which way the face pointed) probably can, once there are
recorded forehands and backhands to look at. That is the first thing fixtures
from a garden should settle.

## The stand-in detector

`SwingGameApp/StandIn/StandInDetector.swift` reads Core Motion and produces a
`Shot`, crudely: rotation-rate thresholds for the window, integrated
acceleration for speed and direction, the sample of peak hand speed as release.
It is scaffolding. It exists because `motion/` has not landed and the two of us
are not in the same room this week, and **it is deleted the day `motion/`
arrives.** It knows nothing about sport; if a sport word appears in it, take it
out.

The part worth keeping is the recording. Every swing it reads is saved to
`Documents/fixtures/<context>-<timestamp>.json` as a `Fixture` with its full
trace and a note about what the game made of it. Plug the phone into a Mac and
they are in Finder, or use the Files app, or share them from the "Recorded
swings" screen. Drop them into `fixtures/` in the repository. When the real
detector is run over them, `expected` changes and the diff is the review.

## Left-handers

Every sport is written for the right hand. A left-hander's `Shot` is mirrored
across the target line first — sideways direction flipped, and because a spin
axis is an axial vector, the *other two* components of it flipped, so a
left-hander's topspin stays topspin. This was got wrong once already and is
now tested.

## Simulator

There are no motion sensors in the simulator, so the play screen has a "Swing
now" button with sliders for speed, elevation and aim. It runs the whole loop —
haptic scripts (as system taps), voice, scoring — with the phone on the desk.
On a device the button is behind the ⋯ menu.
