# swing

One iPhone app. You hold the phone and swing it; it plays golf, bowling, darts.
No second screen, no Mac, nothing to pair.

Two people build this, on two machines, in two Claude accounts, against one
repository. You are one of them. The other one cannot see this conversation and
neither can their Claude — this file is the only thing we share in the moment.

Read `README.md`, then `docs/COLLABORATION.md`. Then `docs/DECISIONS.md`, which
is where the reasons live, and where you will find that the original scaffold was
wrong about something fundamental within a day of being written. Treat what is
here as the current best guess, not as settled.

## Rules

- **Never commit to `main`.** Branch, then pull request. No exceptions for small
  changes; small changes are how the habit dies.
- **Stay in your directory.** `motion/` and `game/` have one owner each. Touching
  the other one means opening a PR and waiting, not just being careful.
- **`core/` changes alone.** A PR that edits `core/` edits nothing else, and it
  lands before anything is built on it. If you are changing `Shot` to make
  something in your own directory work, that is the signal to stop and ask the
  human to raise it with the other owner.
- **`motion/` does not know what a sport is.** No `driver`, no `strike`, no
  `bullseye` in there. It measures the hand; `game/` interprets it. This is the
  load-bearing decision of the whole design and the one thing that survived the
  reversal.
- **Fixtures are the test suite.** When swing detection changes, re-run
  `fixtures/` and put the changed `Shot` numbers in the PR description. A
  detection change with no fixture diff has not been demonstrated to do anything.
- **Write decisions down.** Anything that took an argument to settle goes in
  `docs/DECISIONS.md` in the same PR. The other agent has no other way to learn
  it. When a decision is reversed, strike the old entry through and keep it —
  how we were wrong is worth more than a tidy document.
- **Pull before planning.** A plan built against a stale `main` is wrong in ways
  that are expensive to find later.

## Tone of the work

Prefer the small, testable, boring version. The genuinely hard part of this
project is making a swing *feel* right — with no screen to look at mid-motion,
the haptic at release and the moment just after are the entire experience. That
is iteration against recorded swings in a garden, not architecture. Leave room
for it.

If a decision is justified by what is convenient for the two of us building it,
that is not a reason. Check it against someone who has never played it and owns
nothing but a phone.
