#!/usr/bin/env bash
# install.sh — link the herd + crew skills into every agent's skill dir and put
# herd-watch on PATH. Safe by default: symlinks only, never clobbers a real
# directory, never touches the Codex config unless --codex-config is passed.
#
#   ./install.sh                 link skills + herd-watch (symlinks only)
#   ./install.sh --dry-run       print every action, change nothing
#   ./install.sh --codex-config  also register the herd-* agent types in
#                                $CODEX_HOME/config.toml (backup + parse check)
#
# Honors $HOME and $CODEX_HOME (default $HOME/.codex) so it can be validated
# against a throwaway home first. Rollback = remove the symlinks it lists.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
codex_home="${CODEX_HOME:-$HOME/.codex}"
dry=0; codex_config=0
for a in "$@"; do
  case "$a" in
    --dry-run) dry=1 ;;
    --codex-config) codex_config=1 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done
run() { if [[ $dry -eq 1 ]]; then echo "DRY    $*"; else "$@"; fi; }
linked="LINKED"; [[ $dry -eq 1 ]] && linked="WOULD "

# 1 · skills → ~/.claude/skills, ~/.codex/skills, ~/.agents/skills
skill_dirs=("$HOME/.claude/skills" "$codex_home/skills" "$HOME/.agents/skills")
for base in "${skill_dirs[@]}"; do
  run mkdir -p "$base"
  for s in herd crew; do
    target="$base/$s"
    if [[ -e "$target" && ! -L "$target" ]]; then
      # A real directory that is byte-identical to the repo copy is a hand-made copy, not
      # another install's property — adopt it as a symlink so `git pull` updates it too.
      if diff -rq "$target" "$repo/skills/$s" >/dev/null 2>&1; then
        run rm -rf "$target"
        run ln -sfn "$repo/skills/$s" "$target"
        echo "$linked $target -> $repo/skills/$s (adopted: was an identical copy)"
      else
        echo "SKIP   $target exists, is not a symlink and differs from the repo copy (that agent's own install may own it; remove it to use the repo copy)"
      fi
      continue
    fi
    run ln -sfn "$repo/skills/$s" "$target"
    echo "$linked $target -> $repo/skills/$s"
  done
done

# 2 · herd-watch on PATH (the skill also resolves it by path when PATH lacks ~/.local/bin)
run mkdir -p "$HOME/.local/bin"
if [[ -e "$HOME/.local/bin/herd-watch" && ! -L "$HOME/.local/bin/herd-watch" ]]; then
  echo "SKIP   $HOME/.local/bin/herd-watch exists and is not a symlink"
else
  run ln -sfn "$repo/skills/herd/herd-watch.sh" "$HOME/.local/bin/herd-watch"
  echo "$linked $HOME/.local/bin/herd-watch -> $repo/skills/herd/herd-watch.sh"
fi

# 3 · Codex agent types (opt-in)
if [[ $codex_config -eq 1 ]]; then
  cfg="$codex_home/config.toml"
  if [[ ! -f "$cfg" ]]; then echo "SKIP   $cfg not found — start Codex once so it exists, then re-run with --codex-config" >&2; exit 1; fi
  # Any python >= 3.11 will do (tomllib). Ubuntu 22.04 / WSL2 ships 3.10 as python3, so look
  # past it: versioned binaries on PATH first, then whatever uv manages.
  find_py() {
    local c
    for c in python3 python3.14 python3.13 python3.12 python3.11; do
      command -v "$c" >/dev/null 2>&1 && "$c" -c 'import tomllib' 2>/dev/null && { command -v "$c"; return 0; }
    done
    if command -v uv >/dev/null 2>&1; then
      c="$(uv python find '>=3.11' 2>/dev/null)" && [[ -n "$c" ]] && "$c" -c 'import tomllib' 2>/dev/null && { echo "$c"; return 0; }
    fi
    return 1
  }
  if ! py="$(find_py)"; then echo "SKIP   a python >= 3.11 (tomllib) is required to validate $cfg — none on PATH, none via \`uv python find\`; not touching it" >&2; exit 1; fi
  parse() { "$py" -c 'import sys,tomllib; tomllib.load(open(sys.argv[1],"rb"))' "$1" 2>/dev/null; }
  if ! parse "$cfg"; then echo "SKIP   $cfg does not parse as TOML — fix it before registering agents" >&2; exit 1; fi
  if grep -q -E '^# herd agents|^\[agents\.herd-' "$cfg"; then
    echo "SKIP   $cfg already has herd agent entries (marker or [agents.herd-*] header) — not appending a second copy"
  else
    ts="$(date -u +%Y%m%dT%H%M%SZ)"; bak="$cfg.bak-herd-$ts"
    block="$(cat <<TOML

# herd agents — registered by $repo/install.sh --codex-config ($ts); role files live in the repo
[agents.herd-scout]
description = "Read-only investigator for a herd session: one bounded question, findings report, never edits."
config_file = "$repo/codex/agents/herd-scout.toml"

[agents.herd-worker]
description = "Write-capable inner agent for a herd bucket's declared split: one disjoint sub-path, never commits."
config_file = "$repo/codex/agents/herd-worker.toml"

[agents.herd-reviewer]
description = "Fresh-context reviewer of a herd bucket's diff: severity-classified findings, no fixes."
config_file = "$repo/codex/agents/herd-reviewer.toml"
TOML
)"
    if [[ $dry -eq 1 ]]; then
      echo "DRY    cp $cfg $bak"; echo "DRY    append to $cfg:"; printf '%s\n' "$block" | sed 's/^/       /'
    else
      cp -p "$cfg" "$bak"
      printf '%s\n' "$block" >> "$cfg"
      if parse "$cfg"; then
        echo "WROTE  $cfg (+3 [agents.herd-*] blocks) — backup: $bak"
      else
        cp -p "$bak" "$cfg"
        echo "RESTORED $cfg from $bak — appended config failed to parse; nothing changed" >&2
        exit 1
      fi
    fi
  fi
  for f in "$repo"/codex/agents/herd-*.toml; do parse "$f" || { echo "BAD    $f does not parse" >&2; exit 1; }; done
  echo "OK     role files parse: $(ls "$repo"/codex/agents/ | tr '\n' ' ')"
fi

echo
echo "Rollback: rm the LINKED symlinks above$( [[ $codex_config -eq 1 ]] && echo '; restore the config backup named above' )."
echo "Next: paste claude-md-snippet.md into ~/.claude/CLAUDE.md and codex-agents-snippet.md into $codex_home/AGENTS.md."
echo "Requires: herdr on PATH (HERDR_ENV=1 inside panes), jq, git. Verified with herdr 0.8.2, Codex CLI 0.152, Claude Code (macOS, Linux/WSL2)."
