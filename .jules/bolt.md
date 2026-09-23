# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-08-04 - Optimizing execute_history via streaming awk
**Learning:** Processing history files in Bash by creating intermediate temporary files and iterating line-by-line in sequential `while read` loops with subshell calls (`ls | grep`) incurs massive process fork and disk I/O overhead. Pre-extracting FULL backup timestamps via pure Bash globbing (`${f##*/}`) and piping `sort -r` directly into a single `awk` process for filtering, grouping, and formatting yields a >35x speedup (>0.83s down to ~0.02s on 5000 records).
**Action:** Stream sorted log/history streams directly into `awk` instead of creating temporary file buffers or running sequential Bash loop transformations.
