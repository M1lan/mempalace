#!/usr/bin/env bash
# install-bin.bash -- install MemPalace through uv tool.
# Usage: install-bin.bash [bin-directory]

set -u
# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "$REPO_ROOT" || exit 1

has uv || die 'uv required'
package_name=mempalace
bin_dir=${1:-}

if [[ -n $bin_dir ]]; then
  UV_TOOL_BIN_DIR=$bin_dir uv tool install --force --from . "$package_name"
  target=$bin_dir
else
  uv tool install --force --from . "$package_name"
  target=$(NO_COLOR=1 uv tool dir --bin)
fi

target=$(cd -- "$target" && pwd -P)
printf 'installed: %s/%s\n' "$target" "$package_name"
if [[ :$PATH: != *":$target:"* ]]; then
  printf 'warning: %s is not on PATH\n' "$target" >&2
fi
