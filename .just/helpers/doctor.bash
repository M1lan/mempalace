#!/usr/bin/env bash
# doctor.bash -- dependency and project health audit.
# Usage: doctor.bash

set -u
# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "$REPO_ROOT" || exit 1

required=(bash just uv git rg fd jq shellcheck shfmt ast-grep mise betterhook codeidx)
recommended=(gum fzf bat tokei rumdl)
missing_required=0

printf 'REQUIRED\n'
for tool in "${required[@]}"; do
  if has "$tool"; then
    printf '  %-14s ok\n' "$tool"
  else
    printf '  %-14s MISSING\n' "$tool"
    missing_required=1
  fi
done

printf 'RECOMMENDED\n'
for tool in "${recommended[@]}"; do
  if has "$tool"; then
    printf '  %-14s ok\n' "$tool"
  else
    printf '  %-14s missing\n' "$tool"
  fi
done

printf 'PROJECT\n'
for path in Justfile .just/helpers mise.toml betterhook.toml sgconfig.yml; do
  if [[ -e $path ]]; then
    printf '  %-22s ok\n' "$path"
  else
    printf '  %-22s MISSING\n' "$path"
    missing_required=1
  fi
done

if "$LIB_DIR/harness-gate.bash" > /dev/null; then
  printf '  %-22s ok\n' harness-gate
else
  printf '  %-22s FAILED\n' harness-gate
  missing_required=1
fi

exit "$missing_required"
