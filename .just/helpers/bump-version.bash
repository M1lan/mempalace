#!/usr/bin/env bash
# bump-version.bash -- update package version and lockfile.
# Usage: bump-version.bash NEW_VERSION

set -u
# shellcheck source=lib.bash
source "$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)/lib.bash"
cd "$REPO_ROOT" || exit 1

new=${1:-}
[[ $new =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$ ]] || die 'version must resemble 1.2.3'
old=$(fact_version)

sd '(__version__ *= *")[^"]+(")' "\${1}${new}\${2}" mempalace/version.py
sd '^(version *= *")[^"]+(")' "\${1}${new}\${2}" pyproject.toml
uv lock
printf 'version: %s -> %s\n' "$old" "$new"
