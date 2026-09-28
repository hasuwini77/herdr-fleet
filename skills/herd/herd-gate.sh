#!/usr/bin/env bash
# herd-gate.sh — the inner diff gate. Run by a herd session around any
# write-capable inner agent (Claude `Agent` / Codex `spawn_agent`).
#
#   herd-gate.sh baseline
#       exit 0  tree clean (safe to start a write-capable inner agent)
#       exit 2  tree dirty — commit your in-flight work first (list printed)
#
#   herd-gate.sh check [--bucket NAME] [--oob-dir DIR] -- <owned-path>...
#       exit 0  every change is inside the owned paths
#       exit 1  out-of-bounds changes were PRESERVED (patch + copies + MANIFEST
#               under $oob_dir/<bucket>-<utc-ts>/) and then reverted
#       exit 2  fail closed — staged, renamed/copied, unmerged, or submodule
#               changes found: NOTHING was reverted; inspect by hand
#   Ignored paths (`!!`) are listed and never touched — build products.
#
# Owned paths are repo-relative prefixes: `src/foo` owns `src/foo` and
# everything under it. Runs from anywhere inside the worktree.
set -euo pipefail

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-2}"; }

cmd="${1:-}"; shift || true
case "$cmd" in
  baseline)
    dirty="$(git status --porcelain=v1 --untracked-files=all)"
    if [[ -z "$dirty" ]]; then echo "GATE baseline clean"; exit 0; fi
    echo "GATE baseline DIRTY — commit your in-flight work before starting a write-capable inner agent:" >&2
    printf '%s\n' "$dirty" >&2
    exit 2 ;;
  check) ;;
  -h|--help|help) usage 0 ;;
  *) usage 2 ;;
esac

bucket="bucket"; oob_root="${HERD_OOB_DIR:-$HOME/herd-oob}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket) bucket="$2"; shift 2 ;;
    --oob-dir) oob_root="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo "unknown option: $1" >&2; usage 2 ;;
  esac
done
[[ $# -gt 0 ]] || { echo "check needs at least one owned path after --" >&2; usage 2; }

root="$(git rev-parse --show-toplevel)"; cd "$root"
owned=()
for p in "$@"; do p="${p#./}"; p="${p%/}"; [[ -n "$p" ]] && owned+=("$p"); done

in_bounds() { # $1 = repo-relative path
  local path="$1" o
  for o in "${owned[@]}"; do
    [[ "$path" == "$o" || "$path" == "$o/"* ]] && return 0
  done
  return 1
}
is_submodule() { [[ "$(git ls-files --stage -- "$1" 2>/dev/null | awk '{print $1}')" == 160000 ]]; }

# Parse `git status -z`: entries are "XY path\0", renames/copies "XY new\0old\0".
ok=() oob_mod=() oob_del=() oob_new=() ignored=() closed=()
while IFS= read -r -d '' entry; do
  xy="${entry:0:2}"; path="${entry:3}"
  x="${xy:0:1}"; y="${xy:1:1}"
  if [[ "$x" == R || "$x" == C || "$y" == R || "$y" == C ]]; then
    IFS= read -r -d '' _old || true   # consume the second NUL-terminated field
    closed+=("rename/copy: $path"); continue
  fi
  case "$xy" in
    '!!') ignored+=("$path"); continue ;;
    '??') if in_bounds "$path"; then ok+=("$path"); else oob_new+=("$path"); fi; continue ;;
  esac
  if [[ "$x" == U || "$y" == U || "$xy" == AA || "$xy" == DD ]]; then closed+=("unmerged: $path"); continue; fi
  if [[ "$x" != ' ' ]]; then closed+=("staged ($xy): $path"); continue; fi
  if is_submodule "$path"; then closed+=("submodule: $path"); continue; fi
  if in_bounds "$path"; then ok+=("$path"); continue; fi
  case "$y" in
    D) oob_del+=("$path") ;;
    *) oob_mod+=("$path") ;;
  esac
done < <(git status --porcelain=v1 -z --untracked-files=all --ignored=matching)

if [[ ${#ignored[@]} -gt 0 ]]; then
  echo "GATE ignored (build products, untouched): ${#ignored[@]}"; printf '  !! %s\n' "${ignored[@]}"
fi
if [[ ${#closed[@]} -gt 0 ]]; then
  echo "GATE FAIL-CLOSED — nothing reverted; inspect by hand:" >&2
  printf '  %s\n' "${closed[@]}" >&2
  exit 2
fi
if [[ ${#oob_mod[@]} -eq 0 && ${#oob_del[@]} -eq 0 && ${#oob_new[@]} -eq 0 ]]; then
  echo "GATE ok — ${#ok[@]} changed path(s), all inside owned paths"; exit 0
fi

ts="$(date -u +%Y%m%dT%H%M%SZ)"; dir="$oob_root/$bucket-$ts"
mkdir -p "$dir/files"; manifest="$dir/MANIFEST"
{ echo "bucket=$bucket"; echo "repo=$root"; echo "head=$(git rev-parse HEAD)"; echo "ts=$ts"; echo "owned=${owned[*]}"; } > "$manifest"
if [[ ${#oob_mod[@]} -gt 0 || ${#oob_del[@]} -gt 0 ]]; then
  git diff HEAD -- "${oob_mod[@]+"${oob_mod[@]}"}" "${oob_del[@]+"${oob_del[@]}"}" > "$dir/changes.patch"
fi
for p in "${oob_mod[@]+"${oob_mod[@]}"}"; do
  mkdir -p "$dir/files/$(dirname "$p")"; cp -p "$p" "$dir/files/$p"; printf 'modified\t%s\n' "$p" >> "$manifest"
done
for p in "${oob_del[@]+"${oob_del[@]}"}"; do
  mkdir -p "$dir/files/$(dirname "$p")"; git show "HEAD:$p" > "$dir/files/$p"; printf 'deleted\t%s\n' "$p" >> "$manifest"
done
for p in "${oob_new[@]+"${oob_new[@]}"}"; do
  mkdir -p "$dir/files/$(dirname "$p")"; cp -p "$p" "$dir/files/$p"; printf 'untracked\t%s\n' "$p" >> "$manifest"
done
# Preserved — now revert (tracked back to HEAD, untracked removed).
if [[ ${#oob_mod[@]} -gt 0 || ${#oob_del[@]} -gt 0 ]]; then
  git checkout HEAD -- "${oob_mod[@]+"${oob_mod[@]}"}" "${oob_del[@]+"${oob_del[@]}"}"
fi
for p in "${oob_new[@]+"${oob_new[@]}"}"; do rm -f -- "$p"; done

echo "GATE OUT-OF-BOUNDS — preserved then reverted: $((${#oob_mod[@]}+${#oob_del[@]}+${#oob_new[@]})) path(s)" >&2
sed -n '6,$p' "$manifest" | sed 's/^/  /' >&2
echo "GATE preserved at: $dir" >&2
exit 1
