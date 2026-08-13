# --- Build and release recipes ---

set working-directory := '..'

BIN_DIR := env_var_or_default("BIN_DIR", env_var_or_default("UV_TOOL_BIN_DIR", ""))

# Build source and wheel artifacts.
[group('release')]
build:
    uv build

# Validate built artifacts.
[group('release')]
build-check: build
    uvx twine check dist/*

# Install MemPalace as user-local uv tool.
[group('release')]
install-bin:
    @.just/helpers/install-bin.bash "{{BIN_DIR}}"

# Upload artifacts to TestPyPI.
[group('release')]
publish-test: build-check
    uvx twine upload --repository testpypi dist/*

# Upload artifacts to PyPI.
[group('release')]
publish: build-check
    uvx twine upload dist/*

# Update package version and lockfile.
[group('release')]
bump-version new:
    @.just/helpers/bump-version.bash "{{new}}"

# Create annotated version tag.
[group('release')]
tag:
    @version="$$(uv run --quiet python -c 'import mempalace; print(mempalace.__version__)')"; git tag -a "v$$version" -m "Release v$$version"; printf 'tagged v%s\n' "$$version"
