#!/usr/bin/env bash
# bootstrap.sh - set up Claude Code from this dotfiles repo on macOS or Ubuntu.
# Compatible with bash 3.2 (the macOS default) and bash 5 (Ubuntu).

set -eu

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [options]

Sets up your Claude config folder from this repo and installs your plugins.

Profiles:
  (default)            Personal machine. Symlinks files, so changes you make
                       flow straight back into this repo.
  --work               Work machine. Copies files instead of linking them, so
                       nothing written at work can flow back into this personal
                       repo. Does not add the personal marketplace.

Options:
  --github-user NAME   Your GitHub user name. Fills the placeholder in
                       claude/settings.json the first time you run this.
  --config-dir DIR     Claude config folder (default: $CLAUDE_CONFIG_DIR,
                       or ~/.claude).
  --no-plugins         Skip adding the marketplace and installing plugins
                       (with --check: skip checking for the Claude Code CLI).
  --dry-run            Show what would happen without changing anything.
  --check              Report differences between this repo and the config
                       folder, then exit.
  -h, --help           Show this help.
EOF
}

repo_dir="$(cd "$(dirname "$0")" && pwd)"
src_dir="$repo_dir/claude"
profile="personal"
github_user=""
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
dry_run=0
check_only=0
do_plugins=1
marketplace_name="lee-claude"
plugins="lw-core lw-safety lw-personal"
items="CLAUDE.md rules settings.json"

while [ $# -gt 0 ]; do
  case "$1" in
    --work) profile="work" ;;
    --github-user)
      [ $# -ge 2 ] || { echo "--github-user needs a value" >&2; exit 1; }
      github_user="$2"; shift ;;
    --config-dir)
      [ $# -ge 2 ] || { echo "--config-dir needs a value" >&2; exit 1; }
      config_dir="$2"; shift ;;
    --no-plugins) do_plugins=0 ;;
    --dry-run) dry_run=1 ;;
    --check) check_only=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

say() { printf '%s\n' "$*"; }

run() {
  if [ "$dry_run" -eq 1 ]; then
    say "  [dry-run] $*"
  else
    "$@"
  fi
}

source_for() {
  # $1 = item name in the config folder
  if [ "$profile" = "work" ] && [ "$1" = "settings.json" ]; then
    printf '%s\n' "$src_dir/settings.work.json"
  else
    printf '%s\n' "$src_dir/$1"
  fi
}

# ---------------------------------------------------------------- check mode
if [ "$check_only" -eq 1 ]; then
  say "Checking $config_dir against $src_dir ($profile profile)"
  status=0
  for name in $items; do
    src="$(source_for "$name")"
    dest="$config_dir/$name"
    if [ "$profile" = "personal" ]; then
      if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        say "  ok          $name"
      elif [ -L "$dest" ]; then
        say "  WRONG LINK  $name -> $(readlink "$dest")"; status=1
      elif [ -e "$dest" ]; then
        say "  NOT LINKED  $name (a plain file or folder replaced the link; re-run bootstrap)"; status=1
      else
        say "  MISSING     $name"; status=1
      fi
    else
      if [ ! -e "$dest" ]; then
        say "  MISSING     $name"; status=1
      elif diff -rq "$src" "$dest" >/dev/null 2>&1; then
        say "  same        $name"
      else
        say "  changed     $name (edited on this machine; those changes stay here)"
      fi
    fi
  done
  if [ "$profile" = "personal" ] && grep -q 'YOUR_GITHUB_USER' "$src_dir/settings.json"; then
    say "  TODO        claude/settings.json still has the YOUR_GITHUB_USER placeholder"; status=1
  fi
  if [ "$do_plugins" -eq 1 ]; then
    if command -v claude >/dev/null 2>&1; then
      say "  ok          Claude Code CLI found"
    else
      say "  MISSING     Claude Code CLI (claude) not on PATH"; status=1
    fi
  fi
  exit "$status"
fi

# ---------------------------------------------------------------- set up
say "Setting up $config_dir ($profile profile)"
[ "$dry_run" -eq 1 ] && say "Dry run: nothing will be changed."

settings_src="$src_dir/settings.json"

# Fill the GitHub user placeholder once (personal profile only).
if [ "$profile" = "personal" ] && grep -q 'YOUR_GITHUB_USER' "$settings_src"; then
  if [ -z "$github_user" ]; then
    echo "claude/settings.json still has the YOUR_GITHUB_USER placeholder." >&2
    echo "Run again with: ./bootstrap.sh --github-user <your-github-user>" >&2
    exit 1
  fi
  case "$github_user" in
    *[!A-Za-z0-9-]*) echo "That doesn't look like a GitHub user name: $github_user" >&2; exit 1 ;;
  esac
  run sed -i.bak "s/YOUR_GITHUB_USER/$github_user/g" "$settings_src"
  run rm -f "$settings_src.bak"
  say "  filled in your GitHub user in claude/settings.json (commit this change)"
fi

run mkdir -p "$config_dir"
backup_dir="$config_dir/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

backup() {
  # $1 = path in the config folder to move aside
  if [ -e "$1" ] || [ -L "$1" ]; then
    run mkdir -p "$backup_dir"
    run mv "$1" "$backup_dir/"
    say "  backed up $(basename "$1") to $backup_dir/"
  fi
}

for name in $items; do
  src="$(source_for "$name")"
  dest="$config_dir/$name"
  if [ ! -e "$src" ]; then
    say "  skipped   $name (not in this repo)"
    continue
  fi
  if [ "$profile" = "personal" ]; then
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      say "  ok        $name (already linked)"
      continue
    fi
    backup "$dest"
    run ln -s "$src" "$dest"
    say "  linked    $name -> $src"
  else
    # Work settings are copied once, then owned by the work machine (work plugins
    # and company tweaks live there). CLAUDE.md and rules are refreshed each run.
    if [ "$name" = "settings.json" ] && [ -e "$dest" ] && [ ! -L "$dest" ]; then
      say "  kept      settings.json (already set up on this machine)"
      continue
    fi
    backup "$dest"
    run cp -R "$src" "$dest"
    say "  copied    $name"
  fi
done

# ---------------------------------------------------------------- plugins
if [ "$do_plugins" -eq 1 ] && [ "$profile" = "personal" ]; then
  # CLAUDE_MARKETPLACE_SOURCE overrides the source, e.g. a local path for testing.
  source_repo="${CLAUDE_MARKETPLACE_SOURCE:-}"
  if [ -z "$source_repo" ]; then
    source_repo="$(sed -n 's/.*"repo"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$settings_src" | head -n 1)"
    if [ -n "$github_user" ]; then
      source_repo="$(printf '%s' "$source_repo" | sed "s/YOUR_GITHUB_USER/$github_user/")"
    fi
  fi
  if ! command -v claude >/dev/null 2>&1; then
    say "Claude Code CLI not found. Install it, then run this script again."
  elif [ -z "$source_repo" ]; then
    say "Could not find the marketplace repo in claude/settings.json; skipping plugins."
  else
    say "Adding marketplace $source_repo and installing plugins"
    if [ "$dry_run" -eq 1 ]; then
      say "  [dry-run] claude plugin marketplace add $source_repo"
    elif ! claude plugin marketplace add "$source_repo"; then
      say "  warning: could not add the marketplace (check 'gh auth status' or your SSH key)"
    fi
    for p in $plugins; do
      if [ "$dry_run" -eq 1 ]; then
        say "  [dry-run] claude plugin install $p@$marketplace_name"
      elif ! claude plugin install "$p@$marketplace_name"; then
        say "  warning: could not install $p@$marketplace_name"
      fi
    done
  fi
fi

if [ "$profile" = "work" ]; then
  say ""
  say "Work profile done. Files were copied, not linked, so changes made here stay here."
  say "To add your reviewed work copy of lw-core and lw-safety:"
  say "  claude plugin marketplace add <work-org>/<work-repo>"
  say "  claude plugin install lw-core@<work-marketplace-name>"
  say "Company managed settings take priority over these files."
fi

# lw-safety hooks need jq or python3 to read their input.
if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
  say "Note: lw-safety hooks need jq or python3. Install one (macOS: brew install jq; Ubuntu: sudo apt install jq)."
fi

say "Done. Start a new Claude Code session to load the changes."
