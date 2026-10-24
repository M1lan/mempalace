#!/usr/bin/env bash
# lifecycle.bash -- install, reinstall, uninstall, update, status.
# Usage: lifecycle.bash <install|reinstall|uninstall|update|status> [bin-dir]

set -u
trap 'exit 130' INT TERM HUP
# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "$REPO_ROOT" || exit 1

has uv || die 'uv required; see just doctor'

PACKAGE=mempalace
readonly PACKAGE

# Print the version of the installed uv tool, or the empty string.
tool_version() {
  installed_version
}

# True when the package is installed as a uv tool.
tool_installed() {
  [[ -n $(tool_version) ]]
}

# Absolute directory holding installed uv tool executables.
tool_bin_dir() {
  local dir
  dir=$(NO_COLOR=1 uv tool dir --bin 2> /dev/null) || return 1
  (cd -- "$dir" && pwd -P)
}

# Synchronize the project virtual environment.
sync_env() {
  printf '==> uv sync --all-extras\n'
  uv sync --all-extras
}

# Rebuild the project virtual environment from scratch.
resync_env() {
  printf '==> uv sync --all-extras --reinstall\n'
  uv sync --all-extras --reinstall
}

# Install or overwrite the user-local CLI, honoring an explicit bin directory.
install_tool() {
  local bin_dir=${1:-}
  printf '==> uv tool install --force\n'
  if [[ -n $bin_dir ]]; then
    UV_TOOL_BIN_DIR=$bin_dir uv tool install --force --from . "$PACKAGE"
  else
    uv tool install --force --from . "$PACKAGE"
  fi
}

# Remove the user-local CLI when present.
uninstall_tool() {
  if ! tool_installed; then
    printf 'not installed as uv tool: %s\n' "$PACKAGE"
    return 0
  fi
  printf '==> uv tool uninstall %s\n' "$PACKAGE"
  uv tool uninstall "$PACKAGE"
}

# Warn when installed executables are unreachable through PATH.
warn_path() {
  local bin_dir=${1:-}
  [[ -n $bin_dir ]] || bin_dir=$(tool_bin_dir) || return 0
  [[ :$PATH: == *":$bin_dir:"* ]] || printf 'warning: %s is not on PATH\n' "$bin_dir" >&2
}

# Fast-forward the checkout when it is clean and tracks an upstream branch.
pull_repo() {
  has git || {
    printf 'skip pull: git missing\n'
    return 0
  }
  if [[ -n $(git status --porcelain 2> /dev/null) ]]; then
    printf 'skip pull: working tree dirty\n'
    return 0
  fi
  local upstream
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2> /dev/null) || {
    printf 'skip pull: no upstream for %s\n' "$(fact_branch)"
    return 0
  }
  printf '==> git pull --ff-only (%s)\n' "$upstream"
  git pull --ff-only || {
    printf 'pull failed; leaving checkout untouched\n' >&2
    return 1
  }
}

# Report repository, environment, and installed CLI state.
show_status() {
  local installed bin_dir
  installed=$(tool_version)
  printf 'repository  %s\n' "$(fact_version)"
  printf 'branch      %s (%s)\n' "$(fact_branch)" "$(fact_dirty)"
  printf 'python      %s\n' "$(fact_python)"
  printf 'installed   %s\n' "${installed:-not installed}"
  if bin_dir=$(tool_bin_dir); then
    printf 'bin dir     %s\n' "$bin_dir"
  fi
  if [[ -n $installed && $installed != "$(fact_version)" ]]; then
    printf 'stale: installed %s differs from repository %s; run just reinstall\n' \
      "$installed" "$(fact_version)"
  fi
}

action=${1:-}
bin_dir=${2:-}

case $action in
  install)
    sync_env
    install_tool "$bin_dir"
    warn_path "$bin_dir"
    printf 'installed %s %s\n' "$PACKAGE" "$(tool_version)"
    ;;
  reinstall)
    uninstall_tool
    resync_env
    install_tool "$bin_dir"
    warn_path "$bin_dir"
    printf 'reinstalled %s %s\n' "$PACKAGE" "$(tool_version)"
    ;;
  uninstall)
    uninstall_tool
    ;;
  update)
    before=$(tool_version)
    pull_repo || exit 1
    sync_env
    if [[ -n $before ]]; then
      install_tool "$bin_dir"
      warn_path "$bin_dir"
      printf 'updated %s: %s -> %s\n' "$PACKAGE" "$before" "$(tool_version)"
    else
      printf 'environment updated; %s not installed as uv tool (just install)\n' "$PACKAGE"
    fi
    ;;
  status)
    show_status
    ;;
  *)
    die 'usage: lifecycle.bash <install|reinstall|uninstall|update|status> [bin-dir]'
    ;;
esac
