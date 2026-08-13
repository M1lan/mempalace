# --- Core project recipes ---

set working-directory := '..'

# Synchronize project dependencies.
[group('setup')]
install:
    uv sync --all-extras

# Synchronize every optional dependency group.
[group('setup')]
install-all:
    uv sync --all-extras --all-groups

# Refresh the dependency lockfile.
[group('setup')]
lock:
    uv lock

# Upgrade dependencies and synchronize the environment.
[group('setup')]
upgrade:
    uv lock --upgrade
    uv sync --all-extras

# Run Ruff checks without modifying files.
[group('lint')]
lint:
    uv run ruff check .

# Apply safe Ruff fixes.
[group('lint')]
lint-fix:
    uv run ruff check --fix .

# Check Python formatting.
[group('lint')]
fmt-check:
    uv run ruff format --check .

# Format Python sources.
[group('lint')]
fmt:
    uv run ruff format .

# Apply lint fixes and formatting.
[group('lint')]
fix: lint-fix fmt

# Run default tests; forwards extra pytest arguments.
[group('test')]
test *args:
    uv run pytest tests/ -v --ignore=tests/benchmarks {{args}}

# Run tests with enforced coverage.
[group('test')]
test-cov *args:
    uv run pytest tests/ -v --ignore=tests/benchmarks --cov=mempalace --cov-report=term-missing --cov-fail-under=85 {{args}}

# Run one test file or node ID.
[group('test')]
test-one target:
    uv run pytest -v "{{target}}"

# Re-run previously failed tests.
[group('test')]
test-failed:
    uv run pytest tests/ -v --ignore=tests/benchmarks --lf

# Watch the default test suite.
[group('test')]
test-watch:
    uv run --with pytest-watch ptw -- tests/ --ignore=tests/benchmarks

# Run slow non-benchmark tests.
[group('test')]
test-slow:
    uv run pytest tests/ -v --ignore=tests/benchmarks -m "not benchmark and not stress"

# Run benchmark-marked tests.
[group('test')]
test-bench-suite:
    uv run pytest tests/benchmarks -v -m benchmark

# Run destructive stress tests.
[group('test')]
test-stress:
    uv run pytest tests/benchmarks -v -m stress

# Generate HTML coverage output.
[group('test')]
coverage-html:
    uv run pytest tests/ --ignore=tests/benchmarks --cov=mempalace --cov-report=html --cov-report=term-missing

# Run MemPalace CLI with forwarded arguments.
[group('run')]
run *args:
    uv run python -m mempalace {{args}}

# Show palace status.
[group('run')]
status:
    uv run python -m mempalace status

# Show wake-up context.
[group('run')]
wake-up *args:
    uv run python -m mempalace wake-up {{args}}

# Start MCP server on standard input and output.
[group('run')]
mcp-server:
    uv run python -m mempalace.mcp_server

# Run a Python file under project environment.
[group('run')]
exec target *args:
    uv run python "{{target}}" {{args}}

# Start interactive Python with MemPalace loaded.
[group('run')]
repl:
    uv run python -i -c 'import mempalace; print(f"mempalace {mempalace.__version__} loaded")'

# Print package version.
[group('release')]
version:
    @uv run --quiet python -c 'import mempalace; print(mempalace.__version__)'

# Show source TODO markers.
[group('inspect')]
todos:
    @rg -n 'TODO|FIXME|HACK|XXX|BUG' --type py || printf 'None found.\n'

# Show Python source line counts.
[group('inspect')]
sloc:
    @tokei mempalace tests

# Lint existing hook scripts.
[group('lint')]
hooks-lint:
    shellcheck hooks/*.sh
