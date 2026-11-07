#!/usr/bin/env bash
# Tests for bootstrap.sh in throwaway home folders (no Claude Code CLI needed).
# Run from the repository root: bash tests/test-bootstrap.sh
# On macOS, run with /bin/bash to test the bash 3.2 that ships with the OS.

set -u

root="$(cd "$(dirname "$0")/.." && pwd)"
t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT

# Work on a copy so the real repo is never touched.
cp -R "$root" "$t/repo"
bootstrap="$t/repo/bootstrap.sh"
sh_bin="$BASH"

pass=0
fail=0
ok() { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL: $*"; }

# 1. Personal profile links the three items.
HOME="$t/h1" "$sh_bin" "$bootstrap" --no-plugins >/dev/null 2>&1 || bad "personal run failed"
for item in CLAUDE.md rules settings.json; do
  if [ -L "$t/h1/.claude/$item" ]; then ok; else bad "personal: $item is not a link"; fi
done
if HOME="$t/h1" "$sh_bin" "$bootstrap" --check --no-plugins >/dev/null 2>&1; then ok; else bad "personal --check reported drift"; fi

# 2. Re-running is safe and creates no backups.
HOME="$t/h1" "$sh_bin" "$bootstrap" --no-plugins >/dev/null 2>&1 || bad "personal re-run failed"
if ls -d "$t/h1/.claude/.dotfiles-backup-"* >/dev/null 2>&1; then bad "re-run created a backup"; else ok; fi

# 3. Drift is detected when a link is replaced by a plain file.
rm "$t/h1/.claude/CLAUDE.md" && echo "plain" > "$t/h1/.claude/CLAUDE.md"
if HOME="$t/h1" "$sh_bin" "$bootstrap" --check --no-plugins >/dev/null 2>&1; then bad "drift not detected"; else ok; fi

# 4. Existing files are backed up, not lost.
mkdir -p "$t/h2/.claude" && echo "old" > "$t/h2/.claude/CLAUDE.md"
HOME="$t/h2" "$sh_bin" "$bootstrap" --no-plugins >/dev/null 2>&1 || bad "backup run failed"
if grep -q old "$t/h2/.claude/.dotfiles-backup-"*/CLAUDE.md 2>/dev/null; then ok; else bad "existing CLAUDE.md was not backed up"; fi

# 5. Work profile copies (never links) and uses settings.work.json.
HOME="$t/h3" "$sh_bin" "$bootstrap" --work >/dev/null 2>&1 || bad "work run failed"
for item in CLAUDE.md rules settings.json; do
  if [ -e "$t/h3/.claude/$item" ] && [ ! -L "$t/h3/.claude/$item" ]; then ok; else bad "work: $item is missing or a link"; fi
done
if grep -q extraKnownMarketplaces "$t/h3/.claude/settings.json"; then bad "work settings include the personal marketplace"; else ok; fi

# 6. Work-side edits never reach the repo, and work settings are kept on re-run.
echo "- work note" >> "$t/h3/.claude/CLAUDE.md"
echo '{"kept": true}' > "$t/h3/.claude/settings.json"
HOME="$t/h3" "$sh_bin" "$bootstrap" --work >/dev/null 2>&1 || bad "work re-run failed"
if grep -q "work note" "$t/repo/claude/CLAUDE.md"; then bad "work edit leaked into the repo"; else ok; fi
if grep -q kept "$t/h3/.claude/settings.json"; then ok; else bad "work settings.json was overwritten"; fi

# 7. Dry run changes nothing.
HOME="$t/h4" "$sh_bin" "$bootstrap" --dry-run --no-plugins >/dev/null 2>&1 || bad "dry run failed"
if [ -e "$t/h4/.claude/CLAUDE.md" ]; then bad "dry run changed files"; else ok; fi

# 8. --config-dir is honoured.
"$sh_bin" "$bootstrap" --config-dir "$t/alt" --no-plugins >/dev/null 2>&1 || bad "--config-dir run failed"
if [ -L "$t/alt/CLAUDE.md" ]; then ok; else bad "--config-dir not honoured"; fi

echo "Passed: $pass  Failed: $fail  (bash $BASH_VERSION)"
[ "$fail" -eq 0 ]
