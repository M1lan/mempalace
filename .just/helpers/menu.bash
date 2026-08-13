#!/usr/bin/env bash
# menu.bash -- unified recipe launcher generated from just metadata.
# Usage: menu.bash

set -u
trap 'exit 130' INT TERM HUP
# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "$REPO_ROOT" || exit 1

for dependency in fzf gum jq just; do
  has "$dependency" || die "$dependency required; run just doctor"
done

selection=$(just --dump --dump-format json |
  jq -r '
    .recipes
    | to_entries[]
    | select(.key != "default")
    | select(.value.private | not)
    | [
        .key,
        (([.value.attributes[]? | objects | .group] | first) // "misc"),
        (.value.doc // "")
      ]
    | @tsv' |
  LC_ALL=C sort -t $'\t' -k2,2 -k1,1 |
  fzf --delimiter=$'\t' \
    --with-nth=1,2,3 \
    --reverse \
    --border=rounded \
    --header='enter run | ctrl-/ preview | esc quit' \
    --preview='just --show {1} 2>/dev/null' \
    --bind='ctrl-/:toggle-preview') || exit_code=$?

exit_code=${exit_code:-0}
((exit_code == 130 || exit_code == 1)) && exit 0
((exit_code == 0)) || die "fzf failed with exit $exit_code"
[[ -n $selection ]] || exit 0

recipe=${selection%%$'\t'*}
command=$(printf 'just %q' "$recipe")
printf 'Run: %s\n' "$command"
gum confirm "Run $command?" || exit 0
exec just "$recipe"
