# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Streaming history processing via sort and awk in execute_history
**Learning:** Processing history log lines using line-by-line Bash `while read` loops and invoking `ls`/`grep` subshells per timestamp creates extreme overhead (scaling linearly with lines * subshells). Pre-extracting FULL backup timestamps via pure Bash globbing (`${f##*/}`) and piping `sort -r` directly into a single `awk` process for filtering, grouping, and formatting eliminated temporary `mktemp` files and subshells, yielding a >31x speedup (2.05s -> 0.065s for 20,000 entries).
**Action:** Avoid line-by-line `while read` loops in Bash when parsing larger structured text files. Extract metadata set markers in pure Bash upfront and stream text through `sort` + single `awk` pass for filtering and formatting.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.
