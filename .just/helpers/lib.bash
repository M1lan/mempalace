# lib.bash -- shared helpers for MemPalace Justfile.
# GNU Bash >= 5.3. Sourced, never executed.
# shellcheck shell=bash

((BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 3))) || {
  printf 'error: GNU Bash >= 5.3 required, got %s\n' "$BASH_VERSION" >&2
  exit 1
}

[[ -n "${_MEMPALACE_JUST_LIB_LOADED:-}" ]] && return 0
_MEMPALACE_JUST_LIB_LOADED=1

set -o pipefail

LIB_DIR=$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)
REPO_ROOT=$(cd -- "$LIB_DIR/../.." && pwd)
readonly LIB_DIR REPO_ROOT

has() { command -v -- "$1" > /dev/null 2>&1; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

fact_version() {
  local version
  version=$(uv run --quiet python -c 'import mempalace; print(mempalace.__version__)' 2> /dev/null) || version='?'
  printf '%s' "$version"
}

fact_python() {
  local version
  version=$(uv run --quiet python -c 'import sys; print(sys.version.split()[0])' 2> /dev/null) || version='not synchronized'
  printf '%s' "$version"
}

fact_branch() {
  local branch
  branch=$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2> /dev/null) || {
    printf '(no git)'
    return
  }
  if [[ $branch == HEAD && -d "$REPO_ROOT/.jj" ]] && has jj; then
    branch="jj @ $(jj --ignore-working-copy -R "$REPO_ROOT" log -r @ --no-graph -T 'change_id.shortest(8)' 2> /dev/null)"
  fi
  printf '%s' "$branch"
}

fact_dirty() {
  local status
  status=$(git -C "$REPO_ROOT" status --porcelain 2> /dev/null) || status=''
  if [[ -n $status ]]; then
    printf 'dirty'
  else
    printf 'clean'
  fi
}
