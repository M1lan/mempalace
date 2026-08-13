# --- MemPalace Justfile -- uv-first project tasks ---

set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load := false
set positional-arguments

mod core '.just/core.just'
mod bench '.just/bench.just'
mod release '.just/release.just'

helpers := ".just/helpers"

# Project facts and quickstart.
[private]
default:
    @'{{ helpers }}/info-screen.bash'

# Plain machine-friendly recipe list.
[group('meta')]
help:
    @just --list --unsorted

# Static project facts.
[group('meta')]
info:
    @'{{ helpers }}/info-screen.bash'

# Unified recipe launcher.
[group('meta')]
[no-exit-message]
menu:
    @'{{ helpers }}/menu.bash'

# Tool and project health audit.
[group('meta')]
doctor:
    @'{{ helpers }}/doctor.bash'

# Machine-readable standard harness conformance gate.
[group('meta')]
harness-gate:
    @'{{ helpers }}/harness-gate.bash'

# Lint helper Bash files.
[group('lint')]
shellcheck-helpers:
    shellcheck -x -S warning -P '{{ helpers }}' '{{ helpers }}'/*.bash

# Check helper Bash formatting.
[group('lint')]
shfmt-check:
    shfmt -d -i 2 -ci -sr '{{ helpers }}'/*.bash

# Check lint, formatting, helpers, and harness conformance.
[group('check')]
check: core::lint core::fmt-check shellcheck-helpers shfmt-check harness-gate

# Full local pre-push gate.
[group('verify')]
verify: check core::test

# CI-equivalent quality gate.
[group('verify')]
ci: core::install check core::test-cov

# Install, verify, build, and validate artifacts.
[group('verify')]
all: core::install check core::test-cov release::build-check
