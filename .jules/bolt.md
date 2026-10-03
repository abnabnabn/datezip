# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-10-03 - Streamlining history filtering and formatting in execute_history
**Learning:** Sequential Bash `while read` loops combined with per-entry subshells (e.g. `ls | grep` inside loops) and multiple intermediate temporary disk files cause severe performance degradation on large history files. Streaming data directly through `awk` and `sort -r` pipelines while pre-extracting FULL backup timestamps via pure Bash globbing (`${f##*/}`) eliminates subshell forks and temporary I/O overhead, yielding a >14x speedup on 50,000 history records (reducing runtime from 3.86s to 0.26s).
**Action:** Avoid `while read` loops and subshells inside loops when processing large text data in Bash. Use pure parameter expansion and stream text directly through single `awk` pipelines.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.
