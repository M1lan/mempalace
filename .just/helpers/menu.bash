#!/usr/bin/env bash
# menu.bash -- unified recipe launcher generated from just metadata.
# Usage: menu.bash [--rows]

set -u
trap 'exit 130' INT TERM HUP
# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "$REPO_ROOT" || exit 1

for dependency in fzf gum jq just; do
  has "$dependency" || die "$dependency required; run just doctor"
done

# Emit one TSV row per public recipe: name, group, doc, parameter spec.
# Module recipes are prefixed (core::test) so nothing stays hidden.
rows() {
  just --dump --dump-format json 2> /dev/null | jq -r '
    def spec:
      [ .parameters[]?
        | .name
          + (if .kind == "star" or .kind == "plus" then "*"
             elif .default != null then "?"
             else "" end) ]
      | join(" ");
    def rows($prefix; $obj):
      ($obj.recipes // {})
      | to_entries[]
      | select(.key != "default")
      | select(.value.private | not)
      | [ $prefix + .key,
          (([.value.attributes[]? | objects | .group] | first) // "misc"),
          (.value.doc // ""),
          (.value | spec) ];
    def walk($prefix; $obj):
      rows($prefix; $obj),
      (($obj.modules // {}) | to_entries[] | walk($prefix + .key + "::"; .value));
    walk(""; .) | @tsv' | LC_ALL=C sort -t $'\t' -k2,2 -k1,1
}

if [[ ${1:-} == --rows ]]; then
  rows
  exit 0
fi

# Prompt for one parameter; an empty answer skips optional parameters.
prompt_param() {
  local token=$1 name value rc=0
  name=${token%[?*]}
  value=$(gum input --prompt " $name > " --placeholder "$token") || rc=$?
  ((rc == 0)) || return "$rc"
  printf '%s' "$value"
}

self=${BASH_SOURCE[0]}

while :; do
  listing=$(rows)
  [[ -n $listing ]] || die 'no recipes found; is this a Justfile project?'

  rc=0
  selection=$(printf '%s\n' "$listing" |
    fzf --delimiter=$'\t' \
      --with-nth=1,2,3 \
      --reverse \
      --border=rounded \
      --border-label=' mempalace ' \
      --prompt=' > ' \
      --header='enter run | tab preview | ctrl-r reload | esc quit' \
      --preview='just --show {1} 2>/dev/null || printf "no source for %s\n" {1}' \
      --preview-window='right,55%,<100(down)' \
      --bind='tab:toggle-preview' \
      --bind="ctrl-r:reload($(printf '%q' "$self") --rows)") || rc=$?

  ((rc == 130 || rc == 1)) && exit 0
  ((rc == 0)) || die "fzf failed with exit $rc"
  [[ -n $selection ]] || exit 0

  IFS=$'\t' read -r recipe _group _doc params <<< "$selection"

  args=()
  cancelled=0
  for token in ${params:-}; do
    rc=0
    value=$(prompt_param "$token") || rc=$?
    if ((rc != 0)); then
      cancelled=1
      break
    fi
    if [[ -z $value ]]; then
      if [[ $token != *[?*] ]]; then
        printf 'missing required parameter: %s\n' "$token" >&2
        cancelled=1
      fi
      break
    fi
    if [[ $token == *'*' ]]; then
      # Variadic parameters accept several whitespace-separated words.
      read -r -a extra <<< "$value"
      args+=("${extra[@]+"${extra[@]}"}")
    else
      args+=("$value")
    fi
  done
  ((cancelled == 0)) || continue

  command=$(printf 'just %q' "$recipe")
  for arg in "${args[@]+"${args[@]}"}"; do
    command+=$(printf ' %q' "$arg")
  done
  printf '%s\n' "$command"
  gum confirm "Run ${command}?" || continue

  just "$recipe" "${args[@]+"${args[@]}"}"
  status=$?
  printf '\nexit %s -- any key returns to the menu, esc quits\n' "$status"
  rc=0
  IFS= read -rsn1 key || rc=$?
  ((rc == 0)) || exit 0
  [[ $key == $'\e' ]] && exit 0
done
