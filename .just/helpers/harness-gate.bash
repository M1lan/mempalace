#!/usr/bin/env bash
# harness-gate.bash -- machine-readable standard harness conformance check.
# Usage: harness-gate.bash

set -u
# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "$REPO_ROOT" || exit 1

has jq || die 'jq required for harness gate'

checks='[]'
all_ok=true

add_check() {
  local id=$1 ok=$2 detail=$3 remedy=$4
  checks=$(jq -cn \
    --argjson checks "$checks" \
    --arg id "$id" \
    --argjson ok "$ok" \
    --arg detail "$detail" \
    --arg remedy "$remedy" \
    '$checks + [{id: $id, ok: $ok, detail: $detail, remedy: $remedy}]')
  [[ $ok == true ]] || all_ok=false
}

just_lines=0
while IFS= read -r _line; do
  ((++just_lines))
done < Justfile
if ((just_lines <= 250)) && [[ -f .just/helpers/lib.bash ]]; then
  add_check justfile-system true "$just_lines Justfile lines; helper library present" ''
else
  add_check justfile-system false "$just_lines Justfile lines" 'split recipes into .just/helpers and keep Justfile at 250 lines or fewer'
fi

if [[ -f mise.toml ]] && mise config get tools.python > /dev/null 2>&1; then
  add_check mise true 'mise.toml loads' ''
else
  add_check mise false 'mise.toml missing or invalid' 'add valid mise.toml with project tool versions'
fi

betterhook_status=''
if [[ -f betterhook.toml ]] && betterhook_status=$(betterhook status 2> /dev/null) && jq -e '.diagnostics | length == 0' <<< "$betterhook_status" > /dev/null; then
  add_check betterhook true 'betterhook.toml loads without diagnostics' ''
else
  add_check betterhook false 'betterhook.toml missing or invalid' 'add valid betterhook.toml'
fi

if [[ -f sgconfig.yml ]] && ast-grep scan --config sgconfig.yml > /dev/null 2>&1; then
  add_check ast-grep true 'sgconfig.yml validates' ''
else
  add_check ast-grep false 'sgconfig.yml missing or invalid' 'add valid sgconfig.yml'
fi

if has codeidx; then
  index_output=''
  index_exit=0
  index_output=$(codeidx status "$REPO_ROOT" 2>&1) || index_exit=$?
  if ((index_exit == 0)); then
    add_check code-index true "$index_output" ''
  else
    add_check code-index false "$index_output" 'refresh stale configured index with its native sync command'
  fi
else
  add_check code-index false 'codeidx unavailable' 'install codeidx from agent-shell-harness'
fi

jq -cn \
  --arg schema 'harness-gate/1' \
  --argjson ok "$all_ok" \
  --argjson checks "$checks" \
  '{schema: $schema, ok: $ok, checks: $checks}'

[[ $all_ok == true ]]
