# dotfiles

My hand-written Claude Code configuration, kept in git so my Ubuntu machine can
be rebuilt in a few minutes, and the work Mac can be set up from a reviewed copy. Skills, subagents and hooks live in the
separate `claude-marketplace` repo; this repo only holds personal config and
tells Claude Code which plugins to install.

| Path | Becomes | What it is |
|---|---|---|
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | "How I work" instructions for every project |
| `claude/rules/` | `~/.claude/rules/` | Topic rules (`terraform.md` loads only for `.tf` files) |
| `claude/settings.json` | `~/.claude/settings.json` | Permissions, plus the marketplace and plugins to enable |
| `claude/settings.work.json` | `~/.claude/settings.json` (work) | The same permissions, with no personal marketplace |
| `bootstrap.sh` | | Sets everything up (macOS bash 3.2 and Ubuntu) |
| `tests/test-bootstrap.sh` | | Tests the script in throwaway home folders (CI runs it on Ubuntu and macOS) |

## Before you start

- Claude Code installed and signed in (`claude --version`)
- Git access to your private repos (`gh auth login`, or an SSH key)
- `jq` or `python3`, which the `lw-safety` hooks use (macOS 15+ ships `jq`; Ubuntu: `sudo apt install jq`)

## Personal machine (Ubuntu)

```bash
gh repo clone leewilson86/claude-marketplace ~/claude-marketplace
gh repo clone leewilson86/dotfiles ~/dotfiles
~/dotfiles/bootstrap.sh
```

Clone both side by side: the marketplace repo's work pack tool looks for
`../dotfiles`. The script links the files into `~/.claude` (existing files are
moved to `~/.claude/.dotfiles-backup-<time>/`), adds the
`leewilson86/claude-marketplace` marketplace and installs `lw-core`, `lw-safety`
and `lw-personal`.

Because the files are **linked**, changes you or Claude make to `~/.claude/CLAUDE.md`,
`rules/` or `settings.json` land straight in this repo. Commit them like any other change.

Keep machines in step:

```bash
cd ~/dotfiles && git pull && ./bootstrap.sh --check
```

## Which machine runs what

| Machine | Account | What it runs |
|---|---|---|
| Ubuntu | Personal | This repo: `./bootstrap.sh` (links files) |
| iPhone / iPad | Personal | Nothing to install (see below) |
| Mac | Work | The **reviewed work copy** only: `dotfiles/bootstrap.sh --work` |

The Mac never clones this repo. The `bootstrap.sh`, `CLAUDE.md`, `rules/` and
`settings.work.json` reach it as text, through the work pack that
`claude-marketplace/tools/make-work-pack.sh` builds and your SDLC review approves.
Your personal `settings.json` is never exported.

## Work machine (from the reviewed work repo)

```bash
cd <work-repo>/dotfiles && ./bootstrap.sh --work
```

The work profile **copies** files instead of linking them, so anything written
at work stays on the Mac. It doesn't add the personal marketplace; the work repo's
README says how to add the reviewed `lw-core` and `lw-safety`. Company managed
settings always take priority.

Re-running `--work` refreshes `CLAUDE.md` and `rules/` (old copies are backed up)
and leaves the Mac's `settings.json` alone.

## iPhone and iPad

Nothing to install. The app sees what lives in your Claude account: memory,
profile preferences, uploaded skills, and plugins from your marketplace where
the app supports them. Claude Code cloud sessions use each repo's committed
`.claude/` settings, not this repo.

## Deliberately not in this repo

| Item | Why |
|---|---|
| `~/.claude/.credentials.json`, `~/.claude.json` | Login and app state. Secret, and rebuilt on sign-in |
| `projects/` transcripts, `history.jsonl` | Plain text, may contain secrets |
| Auto memory | Stays on each machine. Move anything worth keeping into `CLAUDE.md` or `rules/` |
| `plugins/` cache | Rebuilt from the marketplace |

## Why no dotfiles tool?

| Option | Pros | Cons |
|---|---|---|
| This script (now) | + Nothing to install<br>+ Easy to read | − No per-machine templates |
| chezmoi (later) | + Per-machine templates<br>+ Password manager integration | − Another tool to learn |

Move to chezmoi if machines start needing different settings.
