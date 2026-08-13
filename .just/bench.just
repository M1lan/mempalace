# --- Benchmark recipes ---

set working-directory := '..'

LME_DATA := env_var_or_default("LME_DATA", env_var("HOME") + "/tmp/longmemeval-data/longmemeval_s_cleaned.json")
LOCOMO_DATA := env_var_or_default("LOCOMO_DATA", env_var("HOME") + "/tmp/locomo/data/locomo10.json")
LIMIT := env_var_or_default("LIMIT", "")
MODE := env_var_or_default("MODE", "raw")
GRANULARITY := env_var_or_default("GRANULARITY", "session")
TOP_K := env_var_or_default("TOP_K", "10")

# Run LongMemEval benchmark.
[group('benchmark')]
longmemeval *args:
    uv run python benchmarks/longmemeval_bench.py "{{LME_DATA}}" --mode "{{MODE}}" {{ if LIMIT != "" { "--limit " + LIMIT } else { "" } }} --granularity "{{GRANULARITY}}" {{args}}

# Run LoCoMo benchmark.
[group('benchmark')]
locomo *args:
    uv run python benchmarks/locomo_bench.py "{{LOCOMO_DATA}}" --granularity "{{GRANULARITY}}" --top-k "{{TOP_K}}" {{ if LIMIT != "" { "--limit " + LIMIT } else { "" } }} {{args}}

# Run ConvoMem benchmark.
[group('benchmark')]
convomem category="all" *args:
    uv run python benchmarks/convomem_bench.py --category "{{category}}" {{ if LIMIT != "" { "--limit " + LIMIT } else { "--limit 50" } }} {{args}}

# Run MemBench benchmark.
[group('benchmark')]
membench *args:
    uv run python benchmarks/membench_bench.py {{args}}

# Run short LongMemEval smoke benchmark.
[group('benchmark')]
smoke:
    @[[ -f "{{LME_DATA}}" ]] || { printf 'missing dataset: %s\n' "{{LME_DATA}}" >&2; exit 1; }
    uv run python benchmarks/longmemeval_bench.py "{{LME_DATA}}" --limit 20

# Run every standalone benchmark.
[group('benchmark')]
all: longmemeval locomo convomem membench
