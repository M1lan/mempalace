# ──────────────────────────────────────────────────────────────────────────
# MemPalace — Justfile
# ──────────────────────────────────────────────────────────────────────────
# Project task runner built entirely on top of `uv`. Every Python command
# runs through `uv run` (project venv) or `uvx` (ephemeral tool venv), so
# there is no dependency on system `python3`, `pip`, or globally installed
# packages. Install uv once — everything else follows.
#
#   macOS:  brew install uv
#   Linux:  curl -LsSf https://astral.sh/uv/install.sh | sh
#
# Usage:
#   just                       # show available recipes (default = list)
#   just <recipe> [args...]    # run a recipe
#   just --list                # explicit list
#
# Conventions:
#   • All recipes are non-interactive and safe for CI unless noted.
#   • Variables can be overridden on the command line, e.g.:
#       just LIMIT=20 bench-longmemeval
#       just LME_DATA=~/data/lme.json bench-smoke
# ──────────────────────────────────────────────────────────────────────────

set shell              := ["bash", "-eu", "-o", "pipefail", "-c"]
set dotenv-load        := true
set positional-arguments := true

# ── Variables ─────────────────────────────────────────────────────────────

# Package import name (from pyproject.toml).
PKG        := "mempalace"

# Default coverage floor (matches pyproject.toml / CI).
COV_MIN    := "30"

# Where benchmark runners expect their datasets (override per-invocation).
LME_DATA    := env_var_or_default("LME_DATA",    "/tmp/longmemeval-data/longmemeval_s_cleaned.json")
LOCOMO_DATA := env_var_or_default("LOCOMO_DATA", "/tmp/locomo/data/locomo10.json")

# Generic knobs passed through to benchmark recipes.
LIMIT       := env_var_or_default("LIMIT",       "")
MODE        := env_var_or_default("MODE",        "raw")
GRANULARITY := env_var_or_default("GRANULARITY", "session")
TOP_K       := env_var_or_default("TOP_K",       "10")

# Colors for human-facing output.
BOLD       := '\033[1m'
RESET      := '\033[0m'

# ── Default recipe ────────────────────────────────────────────────────────

# Show the full recipe list (default target).
default:
    @just --list --unsorted

# Print project + environment info (queries the uv-managed venv).
info:
    @printf '{{BOLD}}MemPalace{{RESET}}   task runner\n'
    @printf '  package        : {{PKG}}\n'
    @printf '  uv             : '; (command -v uv >/dev/null && uv --version) || { echo 'NOT INSTALLED — see header of Justfile'; exit 1; }
    @printf '  venv python    : '; uv run --quiet python -c 'import sys; print(sys.version.split()[0], "at", sys.executable)'
    @printf '  ruff           : '; uv run --quiet ruff --version
    @printf '  pytest         : '; uv run --quiet pytest --version
    @printf '  {{PKG}}      : '; uv run --quiet python -c 'import {{PKG}}; print({{PKG}}.__version__)'
    @printf '  repo root      : '; pwd

# ──────────────────────────────────────────────────────────────────────────
# Environment setup
# ──────────────────────────────────────────────────────────────────────────

# Create the uv-managed virtualenv and install the project in editable mode
# with the dev dependency group. Idempotent — safe to run repeatedly.
install:
    @command -v uv >/dev/null 2>&1 || { echo "uv is required — install it (see header of Justfile)"; exit 1; }
    uv sync --all-extras

# Install with every optional extra and every dependency group.
install-all:
    @command -v uv >/dev/null 2>&1 || { echo "uv is required — install it (see header of Justfile)"; exit 1; }
    uv sync --all-extras --all-groups

# Recreate the venv from scratch.
reinstall: clean-venv install

# Lock dependencies.
lock:
    uv lock

# Upgrade the lockfile and re-sync the environment.
upgrade:
    uv lock --upgrade
    uv sync --all-extras

# Install pre-commit git hooks (pre-commit runs via uvx — no install needed).
hooks-install:
    uvx pre-commit install

# Run pre-commit on the entire tree.
hooks-run:
    uvx pre-commit run --all-files

# ──────────────────────────────────────────────────────────────────────────
# Lint / format
# ──────────────────────────────────────────────────────────────────────────

# Run ruff linter (no auto-fix) — mirrors CI.
lint:
    uv run ruff check .

# Run ruff linter with auto-fix.
lint-fix:
    uv run ruff check --fix .

# Check that files are formatted (no changes applied) — mirrors CI.
fmt-check:
    uv run ruff format --check .

# Apply ruff formatting in-place.
fmt:
    uv run ruff format .

# Lint + format check, everything CI enforces.
check: lint fmt-check

# Convenience: auto-fix lint + apply formatting.
fix: lint-fix fmt

# ──────────────────────────────────────────────────────────────────────────
# Tests
# ──────────────────────────────────────────────────────────────────────────

# Default test suite — matches CI (fast tests only, benchmarks ignored).
# Extra positional args are forwarded to pytest.
test *ARGS:
    uv run pytest tests/ -v --ignore=tests/benchmarks "$@"

# Test suite with coverage, matching the CI invocation exactly.
test-cov *ARGS:
    uv run pytest tests/ -v --ignore=tests/benchmarks \
        --cov={{PKG}} --cov-report=term-missing --cov-fail-under={{COV_MIN}} "$@"

# Generate an HTML coverage report in htmlcov/.
coverage-html:
    uv run pytest tests/ --ignore=tests/benchmarks \
        --cov={{PKG}} --cov-report=html --cov-report=term-missing
    @echo "→ open htmlcov/index.html"

# Run a single test file or node ID.
#   just test-one tests/test_searcher.py::test_semantic_hit
test-one TARGET:
    uv run pytest -v "{{TARGET}}"

# Re-run only the tests that failed in the previous run.
test-failed:
    uv run pytest tests/ -v --ignore=tests/benchmarks --lf

# Watch mode — pulls pytest-watch into an ephemeral overlay env.
test-watch:
    uv run --with pytest-watch ptw -- tests/ --ignore=tests/benchmarks

# Enable the `slow` marker in addition to the defaults.
test-slow:
    uv run pytest tests/ -v --ignore=tests/benchmarks -m "not benchmark and not stress"

# Run the in-tree pytest benchmark suite (tests/benchmarks/**).
test-bench-suite:
    uv run pytest tests/benchmarks -v -m benchmark

# Run destructive large-scale stress tests. NOT for CI.
test-stress:
    uv run pytest tests/benchmarks -v -m stress

# ──────────────────────────────────────────────────────────────────────────
# Benchmarks (standalone runners in ./benchmarks)
# ──────────────────────────────────────────────────────────────────────────

# LongMemEval — headline 96.6% R@5 benchmark.
#   Env: LME_DATA (path), MODE (raw|aaak|rooms), LIMIT (int), GRANULARITY
#   Override on the CLI, e.g.:
#     just LME_DATA=~/data/lme.json LIMIT=20 bench-longmemeval
bench-longmemeval *ARGS:
    uv run python benchmarks/longmemeval_bench.py "{{LME_DATA}}" \
        --mode {{MODE}} \
        {{ if LIMIT != "" { "--limit " + LIMIT } else { "" } }} \
        --granularity {{GRANULARITY}} \
        "$@"

# LoCoMo multi-hop reasoning benchmark.
bench-locomo *ARGS:
    uv run python benchmarks/locomo_bench.py "{{LOCOMO_DATA}}" \
        --granularity {{GRANULARITY}} \
        --top-k {{TOP_K}} \
        {{ if LIMIT != "" { "--limit " + LIMIT } else { "" } }} \
        "$@"

# ConvoMem (Salesforce) — downloads data from HuggingFace on first run.
#   Categories: user_evidence, assistant_facts_evidence, changing_evidence,
#               abstention_evidence, preference_evidence, implicit_connection_evidence, all
bench-convomem CATEGORY="all" *ARGS:
    uv run python benchmarks/convomem_bench.py --category {{CATEGORY}} \
        {{ if LIMIT != "" { "--limit " + LIMIT } else { "--limit 50" } }} \
        "$@"

# MemBench runner.
bench-membench *ARGS:
    uv run python benchmarks/membench_bench.py "$@"

# Quick smoke test — 20 LongMemEval questions (~30s), only runs if data present.
bench-smoke:
    @if [ ! -f "{{LME_DATA}}" ]; then \
        echo "LongMemEval data not found at {{LME_DATA}}"; \
        echo "Run: just bench-fetch-longmemeval"; \
        exit 1; \
    fi
    uv run python benchmarks/longmemeval_bench.py "{{LME_DATA}}" --limit 20

# Run every standalone benchmark (takes a while).
bench-all: bench-longmemeval bench-locomo bench-convomem bench-membench

# Fetch the LongMemEval dataset to LME_DATA.
bench-fetch-longmemeval:
    @mkdir -p "$(dirname "{{LME_DATA}}")"
    @if [ -f "{{LME_DATA}}" ]; then \
        echo "→ already present: {{LME_DATA}}"; \
    else \
        echo "→ downloading LongMemEval to {{LME_DATA}}"; \
        curl -fsSL -o "{{LME_DATA}}" \
            https://huggingface.co/datasets/xiaowu0162/longmemeval-cleaned/resolve/main/longmemeval_s_cleaned.json; \
    fi

# Clone the LoCoMo dataset repo to LOCOMO_DATA's parent.
bench-fetch-locomo:
    @LOCOMO_REPO="$(dirname "$(dirname "{{LOCOMO_DATA}}")")"; \
    if [ -d "$LOCOMO_REPO/.git" ]; then \
        echo "→ already cloned: $LOCOMO_REPO"; \
    else \
        git clone https://github.com/snap-research/locomo.git "$LOCOMO_REPO"; \
    fi

# ──────────────────────────────────────────────────────────────────────────
# Run the CLI / MCP server
# ──────────────────────────────────────────────────────────────────────────

# Run the mempalace CLI — forwards all positional args.
#   just run search "auth decisions"
run *ARGS:
    uv run python -m {{PKG}} "$@"

# Shortcut: palace status.
status:
    uv run python -m {{PKG}} status

# Shortcut: wake-up context dump.
wake-up *ARGS:
    uv run python -m {{PKG}} wake-up "$@"

# Launch the MCP server (stdin/stdout). Ctrl-C to stop.
mcp-server:
    uv run python -m {{PKG}}.mcp_server

# Run a file / module under the project interpreter.
#   just exec examples/basic_mining.py
exec TARGET *ARGS:
    uv run python "{{TARGET}}" "$@"

# Drop into an interactive Python REPL with mempalace imported.
repl:
    uv run python -i -c "import {{PKG}}; print(f'mempalace {{ '{' }}{{PKG}}.__version__{{ '}' }} loaded')"

# ──────────────────────────────────────────────────────────────────────────
# Hook scripts (Claude Code auto-save hooks)
# ──────────────────────────────────────────────────────────────────────────

# Lint the hook shell scripts with shellcheck (if installed).
hooks-lint:
    @if command -v shellcheck >/dev/null 2>&1; then \
        shellcheck hooks/*.sh; \
    else \
        echo "shellcheck not installed — skipping"; \
    fi

# Make hook scripts executable.
hooks-chmod:
    chmod +x hooks/*.sh

# ──────────────────────────────────────────────────────────────────────────
# Build / release
# ──────────────────────────────────────────────────────────────────────────

# Build sdist + wheel into dist/ using uv.
build: clean-dist
    uv build
    @ls -lh dist/

# Validate the built artifacts with twine (via uvx — no install needed).
build-check: build
    uvx twine check dist/*

# Override-able target bin directory for `install-bin`. Empty => uv's default
# (~/.local/bin). Set BIN_DIR=~/bin to install there instead.
BIN_DIR := env_var_or_default("BIN_DIR", env_var_or_default("UV_TOOL_BIN_DIR", ""))

# Uses `uv tool install` — creates an isolated venv for the tool and drops
# a `mempalace` shim into uv's tool bin dir (default: ~/.local/bin).
# Override the target directory:
#   just BIN_DIR=~/bin install-bin
#   UV_TOOL_BIN_DIR=~/bin just install-bin
# Install the `mempalace` CLI as a user-local tool on your PATH (~/.local/bin).
install-bin:
    @command -v uv >/dev/null 2>&1 || { echo "uv is required — install it (see header of Justfile)"; exit 1; }
    @if [ -n "{{BIN_DIR}}" ]; then \
        echo "→ installing mempalace to {{BIN_DIR}}"; \
        UV_TOOL_BIN_DIR="{{BIN_DIR}}" uv tool install --force --from . {{PKG}}; \
        TARGET="{{BIN_DIR}}"; \
    else \
        echo "→ installing mempalace to uv's default tool bin dir"; \
        uv tool install --force --from . {{PKG}}; \
        TARGET="$(NO_COLOR=1 uv tool dir --bin)"; \
    fi; \
    TARGET="$(cd "$TARGET" && pwd -P)"; \
    echo; \
    echo "→ installed: $TARGET/mempalace"; \
    case ":$PATH:" in \
        *":$TARGET:"*) ;; \
        *) echo "⚠  $TARGET is not on your PATH — add it to your shell rc:"; \
           echo "     export PATH=\"$TARGET:\$PATH\"" ;; \
    esac

# Uninstall the user-local `mempalace` CLI installed via `install-bin`.
uninstall-bin:
    @command -v uv >/dev/null 2>&1 || { echo "uv is required — install it (see header of Justfile)"; exit 1; }
    uv tool uninstall {{PKG}}

# Upload to TestPyPI (requires TWINE_* env vars or ~/.pypirc).
publish-test: build-check
    uvx twine upload --repository testpypi dist/*

# Upload to PyPI (requires TWINE_* env vars or ~/.pypirc).
publish: build-check
    uvx twine upload dist/*

# Print the current package version.
version:
    @uv run --quiet python -c "import {{PKG}}; print({{PKG}}.__version__)"

# Bump the version in mempalace/version.py and pyproject.toml.
#   just bump-version 3.0.15
bump-version NEW:
    @OLD="$(uv run --quiet python -c 'import {{PKG}}; print({{PKG}}.__version__)')"; \
    echo "→ bumping {{PKG}}: $OLD → {{NEW}}"; \
    sed -i.bak -E 's/(__version__ *= *")[^"]+(")/\1{{NEW}}\2/' {{PKG}}/version.py && rm {{PKG}}/version.py.bak; \
    sed -i.bak -E 's/^(version *= *")[^"]+(")/\1{{NEW}}\2/' pyproject.toml && rm pyproject.toml.bak; \
    uv lock; \
    echo "→ done. don't forget to commit + tag."

# Create an annotated git tag for the current version.
tag:
    @V="$(uv run --quiet python -c 'import {{PKG}}; print({{PKG}}.__version__)')"; \
    git tag -a "v$V" -m "Release v$V"; \
    echo "→ tagged v$V (push with: git push origin v$V)"

# ──────────────────────────────────────────────────────────────────────────
# Cleaning
# ──────────────────────────────────────────────────────────────────────────

# Remove build artifacts (dist/, build/, *.egg-info).
clean-dist:
    rm -rf dist build *.egg-info

# Remove Python bytecode and pytest/ruff caches.
clean-cache:
    fd -HI -t d '^(__pycache__|.pytest_cache|.ruff_cache|.mypy_cache)$' . -x rm -rf {}
    fd -HI -t f '.pyc$' . -x rm -f {}

# Remove coverage artifacts.
clean-cov:
    rm -rf .coverage htmlcov coverage.xml

# Remove the managed virtualenv.
clean-venv:
    rm -rf .venv

# Clean everything except the venv.
clean: clean-dist clean-cache clean-cov

# Full nuke: also removes the venv.
distclean: clean clean-venv

# ──────────────────────────────────────────────────────────────────────────
# Code navigation / fzf helpers
# ──────────────────────────────────────────────────────────────────────────

# Show all TODO/FIXME/HACK/XXX comments in source.
todos:
    @rg -n 'TODO|FIXME|HACK|XXX|BUG' --type py || echo "None found."

# Count lines of code.
sloc:
    @rg --files --type py mempalace/ | xargs wc -l | sort -n

# Fuzzy-pick a source file to open in $EDITOR.
fzf-edit:
    #!/usr/bin/env bash
    set -euo pipefail
    file=$(fd -e py -t f | fzf --preview 'bat --color=always --style=numbers {}')
    [[ -n "${file}" ]] && "${EDITOR:-vi}" "${file}"

# Fuzzy-pick a recipe to run.
fzf:
    @just --choose

# Fuzzy-search source code and jump to match in $EDITOR.
fzf-grep:
    #!/usr/bin/env bash
    set -euo pipefail
    match=$(rg --line-number --no-heading '.' --type py | \
      fzf --delimiter ':' --preview 'bat --color=always --style=numbers --highlight-line {2} {1}')
    [[ -n "${match}" ]] && "${EDITOR:-vi}" "+$(echo "${match}" | cut -d: -f2)" "$(echo "${match}" | cut -d: -f1)"

# Fuzzy-pick a class or function definition to jump to.
fzf-func:
    #!/usr/bin/env bash
    set -euo pipefail
    match=$(rg -n '^(class |def )' --type py | fzf --delimiter ':' \
      --preview 'bat --color=always --style=numbers --highlight-line {2} {1}')
    [[ -n "${match}" ]] && "${EDITOR:-vi}" "+$(echo "${match}" | cut -d: -f2)" "$(echo "${match}" | cut -d: -f1)"

# ──────────────────────────────────────────────────────────────────────────
# Aggregate / CI meta-recipes
# ──────────────────────────────────────────────────────────────────────────

# The exact sequence GitHub Actions runs. Green here == green in CI.
ci: install check test-cov

# Fast local pre-commit flow — format, lint, test.
verify: fix test

# Everything: install, check, test, build, validate artifacts.
all: install check test-cov build-check
