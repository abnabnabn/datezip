# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-08-05 - Streamlining execute_history processing via sort | awk pipeline
**Learning:** Processing history files line-by-line using Bash `while read` loops, temporary files, and per-line subshell calls (`ls | grep`) causes high overhead (~2,048 ms for 20,000 entries). Pre-extracting FULL backup timestamps via pure Bash glob parameter expansion (`${f##*/}`) and piping `sort -r` directly into a single `awk` process for filtering, grouping, and formatting reduces execution time to ~113 ms (~18x-30x speedup).
**Action:** Replace `while read` loops and temp files in Bash stream operations with a single `awk` pass, using in-memory string matching (`index`) for fast status/timestamp lookups.
