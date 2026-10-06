# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-08-05 - Stream pipeline and pre-extracted FULL backup timestamps in execute_history
**Learning:** In Bash history processing, sequential `while read` loops combined with per-timestamp `ls` and `grep` process forks inside subshells introduce substantial process fork overhead and disk IO latency. Pre-extracting FULL backup timestamps via pure Bash globbing and parameter expansion (`${f##*/}`), combined with streaming `sort -r` directly into a single `awk` process for grouping, limit checking, and formatting, yields a >18x speedup (4.67s down to 0.25s for 50,000 history entries).
**Action:** Replace `while read` loop file filtering and per-timestamp subshells with pure Bash string manipulations and stream processing through `awk` pipelines.
