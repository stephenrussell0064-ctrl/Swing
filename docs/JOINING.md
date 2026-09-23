# Joining this repository

Twenty minutes, once. Then read [COLLABORATION.md](COLLABORATION.md), which is
the part you will actually have to live by.

## 1. Clone and identify yourself

```bash
git clone <repo-url> swing
cd swing
git config user.name "Your Name"
git config user.email "you@example.com"
```

## 2. Check it builds

```bash
cd protocol && swift test
```

Ten tests, all green. If they are not, say so before doing anything else — that
package is the contract between the two apps and nothing built on a broken one
is worth reviewing.

## 3. Point Claude at it

Open the `swing` folder as the working directory. Claude reads `CLAUDE.md` at the
root on its own; there is nothing to paste and nothing to configure. Everything
shared lives in the repository:

| File | Shared? | What it is |
| --- | --- | --- |
| `CLAUDE.md` | **yes, committed** | The rules both our agents follow. Changed by PR, like code. |
| `.claude/settings.json` | **yes, committed** | Agreed tool permissions, so neither of us is answering the same prompts all day. |
| `docs/` | **yes, committed** | Architecture, decisions, this. |
| `.claude/settings.local.json` | no, gitignored | Yours. Machine paths, personal allowances. |
| `~/.claude/CLAUDE.md` | no, never in the repo | Your own preferences, on every project you own. Keep them out of here. |

The split matters: anything in `CLAUDE.md` steers *both* agents, so a personal
habit put there becomes a rule imposed on someone else's work.

## 4. Turn on the push guard

```bash
git config core.hooksPath .githooks
```

Once per clone, and it has to be each of us — git does not ship hooks with a
repository, which is why this is a line you type rather than a thing that just
works.

It refuses a push to `main`. GitHub will not do that for us: protected branches
on a private repository need a paid plan, and we are not on one.

## 5. Your first branch

```bash
git switch -c <yourname>/<what-it-does>
```

Never `main`. See [COLLABORATION.md](COLLABORATION.md) for why that is not
negotiable here, and for which directory is yours.
