# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-10-14 - Streaming pipeline in execute_history
**Learning:** Sequential `while read` Bash loops that spawn per-item subshells (e.g. `ls | grep` or temporary files) incur massive process fork overhead when rendering history for large numbers of backup entries. Pre-extracting FULL backup timestamps via pure Bash globbing (`${f##*/}`) and piping `sort -r` directly into an `awk` renderer reduced `execute_history` execution time from >2.2s to ~0.07s (>30x-70x speedup). Note that using `return` inside top-level AWK `END` blocks raises a syntax error; `exit` should be used instead.
**Action:** Stream log/history processing directly through single `awk` & `sort` pipelines instead of reading line-by-line in Bash.
