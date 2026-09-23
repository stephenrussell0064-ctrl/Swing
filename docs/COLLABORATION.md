# Two people, two Claudes, one repository

There is no way to share a Claude Code session across two accounts, and there
should not be one. The coordination layer is git. Claude is a tool each of us
runs locally against the same repository, the same way we each run our own
editor.

That has one consequence worth stating plainly: **an agent writes large diffs
quickly.** Two agents working the same files will not produce a conflict you can
eyeball — they will produce two confident rewrites of the same function. Almost
everything below exists to stop that.

## The rules

1. **`main` is protected and nobody commits to it.** Feature branches, pull
   requests, the other person approves. Even for a one-line fix.

2. **You own a directory, not a task.** One of us owns `motion/`, the other
   owns `game/`. Inside your directory you do not need permission for anything.
   Outside it you open a PR and wait.

   > **Proposed, not yet agreed — settle it and write the names in.** Ziggy's
   > prototype already does swing detection, so `motion/` is his unless he says
   > otherwise, and `game/` is Stephen's. Swapping later is fine; doing both at
   > once is not.

3. **`core/` belongs to both of us.** A change to `Shot` breaks the other
   person's work in progress, so it gets its own PR, changes nothing else, and is
   merged before either of us builds on it. If you find yourself editing
   `core/` to make something in your own directory work, stop and say so
   first.

4. **Pull before you prompt.** Start every session with `git pull` on a fresh
   branch. An agent that plans against a week-old `main` will produce a plan that
   is wrong in ways that are hard to see.

5. **Write the decision down, not just the code.** `docs/DECISIONS.md` is how the
   other person's Claude learns why something is the way it is. It has no other
   way to find out — it cannot read your conversation.

6. **Fixtures over hardware.** See below. This is the one that actually makes
   parallel work possible.

## Fixtures: how we work without being in the same room

The game developer does not need to swing a phone all day, and the detection
developer does not need a working game.

`motion/` records real motion to `fixtures/*.json` — a full 100 Hz trace of
an actual golf swing, an actual bowling roll, an actual dart throw, plus the
`Shot` detection decided to emit from it. Those files are committed.

`game/` replays them. It gets a mode that reads a fixture and feeds it in as
if it had just been swung. So the game can be built, tuned and demoed sitting
down, and a change to swing detection can be proven against
every swing we have ever recorded instead of against whatever one of us can do in
the kitchen.

When detection changes, the fixtures get re-run and any `Shot` that changed shows
up in the diff. That is the regression test.

## CLAUDE.md is the shared brain

Both our Claudes read `CLAUDE.md` at the repository root. It is the only thing
that keeps two agents on two accounts pointed the same way. When you correct your
Claude on something that will come up again — a convention, a trap, a thing it
keeps getting wrong — put it in `CLAUDE.md` in a PR, so it corrects the other one
too.

Keep personal preferences out of it. Those belong in your own
`~/.claude/CLAUDE.md`, which is not shared.

## Practical setup, once each

```bash
git clone <repo-url> swing
cd swing
git config user.name "Your Name"
git config user.email "you@example.com"
```

Both of us need to be collaborators on the repository with push access. Whoever
creates it invites the other.
