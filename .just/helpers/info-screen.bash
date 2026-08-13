#!/usr/bin/env bash
# info-screen.bash -- concise MemPalace project facts.
# Usage: info-screen.bash

set -u
# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "$REPO_ROOT" || exit 1

printf 'MemPalace %s\n' "$(fact_version)"
printf 'python    %s\n' "$(fact_python)"
printf 'uv        %s\n' "$(uv --version 2> /dev/null || printf missing)"
printf 'branch    %s (%s)\n' "$(fact_branch)" "$(fact_dirty)"
printf 'commands  just menu | just doctor | just verify\n'
