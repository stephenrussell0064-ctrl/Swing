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

**The stance.** Every ball starts the same way, borrowed from golf: hang the
phone down like a bat, screen facing the bowler (or the net), and hold still.
Half a second later it buzzes — a rumble, unlike any beat — and you are set.
Where the screen faced is the target line, refreshed every ball. There is no
aim button.

**Your swing is the beat.** The first time you are set, the phone asks for two
practice swings with no ball. It measures how long your swing takes from
leaving the stance to the fastest point, and that becomes the beat of every
count-in. So when it says "swing on the beat after the high one", your own
swing, started on the high beat, arrives exactly on time.

**The hand and the ear: a count-in.** Every ball is then a `HapticScript` —
four evenly spaced beats at your interval, felt as haptic thumps *and* heard as
clicks through the speaker, with the last beat accented and contact exactly one
beat later. You swing on a beat nobody plays, the way you clap on a downbeat you
can already hear coming. The vocabulary is shared across sports:

| Feel / hear | Means |
| --- | --- |
| long rumble | set. You are in the stance and the ball is about to come |
| quiet tick, or two | tennis: forehand / backhand |
| **beat, beat, beat** | the count-in, at your own swing's interval |
| **BEAT** (high, double thump) | the last one. Start your swing now |
| silence | contact, one beat later |
| crisp click | you middled it |
| dull click and a fizz | you got an edge, or a frame |
| long low buzz | you missed |
| three rising clicks | boundary, winner, wicket |

Pace scales your beat: a quick bowler is 0.85 of it, a spinner 1.2, a hard
tennis drive 0.75. Nothing else moves the grid. The first version tried to
encode length as the gap between bounce and contact and it was not playable —
see `docs/DECISIONS.md`. After every ball the phone says how your timing was
("A touch late." "Too early, by 180 milliseconds.").

**The screen.** A top-down ground or court. Fielders, the pitch, the rope; the
ball runs out along its line after a shot. In tennis the incoming ball crosses
toward the side it is coming to as the count plays, and yours lands where the
game says it did. The beats pulse along the bottom. All for the glance after,
and for whoever is watching.

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

**Batting.** Stance, buzz, four beats, the last one high. Start your swing on
it. Then:

- Timing (`Shot.timestamp` against the `Cue`) is contact quality. Miss the
  window and a straight ball bowls you; a ball outside off is a dot.
- Early steers the ball to leg, late to off — the bat has come round further.
- Swing direction is the shot's direction; elevation lofts it; speed carries it.
  Lofted onto a fielder is caught. Past the rope along the ground is four, over
  it is six. Otherwise runs by distance, unless a fielder is on the line.
- Poor contact quality is an edge: behind square on the off side, or into the
  keeper's gloves if it was thin.

**Bowling.** Stance, buzz, then no count: bowl when ready. Hand speed becomes ball speed; the release
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

- **Side.** From the ready position: buzz, then "Forehand." with one tick, or
  "Backhand." with two, 0.7 s before the count starts, which is long enough to
  move the hand across. Then four beats, the last one high, and you swing to
  meet the fifth.
- **Placement.** Early on a forehand goes cross-court, late goes down the line
  (mirrored for the backhand). Yaw adds to that. Past 4.1 m from centre is wide.
- **Depth.** Speed and the racket-face launch angle. The hand's elevation is
  compressed by half — a groundstroke path is much steeper than the ball's
  flight — and topspin (rotation about a horizontal axis with `ω × v` pointing
  down) pulls a hard ball back inside the baseline. Slice floats it.
- **Your serve.** Four beats, hit on the fifth. Must land in the service
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
`Shot`, crudely: the stance (hanging, top edge down, still) fixes the frame
from where the screen faces; a stroke is a rise and fall in rotation rate,
reported at its peak as soon as the rate has fallen well off it; direction is
where the screen faces at that peak; speed is peak rotation times an arm.
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
