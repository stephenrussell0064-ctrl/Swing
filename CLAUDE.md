# swing

Two people build this, on two machines, in two Claude accounts, against one
repository. You are one of them. The other one cannot see this conversation and
neither can their Claude — this file is the only thing we share in the moment.

Read `README.md`, then `docs/COLLABORATION.md`. Then `docs/DECISIONS.md`, which
is where the reasons live.

## Rules

- **Never commit to `main`.** Branch, then pull request. No exceptions for small
  changes; small changes are how the habit dies.
- **Stay in your directory.** `controller/` and `host/` have one owner each.
  Touching the other one means opening a PR and waiting, not just being careful.
- **`protocol/` changes alone.** A PR that edits `protocol/` edits nothing else,
  and it lands before anything is built on it. If you are changing the schema to
  make something in your own directory work, that is the signal to stop and ask
  the human to raise it with the other owner.
- **The controller does not know what a sport is.** No `driver`, no `strike`, no
  `bullseye` in `controller/`. It measures motion; the host interprets it. This
  is the load-bearing decision of the whole design.
- **Fixtures are the test suite.** When swing detection changes, re-run
  `fixtures/` and put the changed `Shot` numbers in the PR description. A
  detection change with no fixture diff has not been demonstrated to do anything.
- **Write decisions down.** Anything that took an argument to settle goes in
  `docs/DECISIONS.md` in the same PR. The other agent has no other way to learn
  it.
- **Pull before planning.** A plan built against a stale `main` is wrong in ways
  that are expensive to find later.

## Tone of the work

Prefer the small, testable, boring version. The genuinely hard part of this
project is making a swing *feel* right, and that is iteration against recorded
swings, not architecture. Leave room for it.
