# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-08-04 - Streaming sort to single AWK process in execute_history
**Learning:** Sequential `while read` loops in Bash combined with temporary files (`mktemp`) and subshell calls (`cut`, `basename`, `grep`) inside history formatting create heavy process overhead. Pre-extracting metadata (like FULL backup timestamps) via pure Bash globbing and streaming `sort -r` directly into a single AWK process delivers an 18x+ speedup. To maintain portability across standard POSIX AWK (`mawk`, BSD `awk`), avoid `nextfile` (a GNU extension) and use `exit` to end early when limits are reached, and use `split()` return value for array lengths instead of `length(array)`.
**Action:** Pass filter options and pre-computed lookup tables into AWK via `-v` and handle all sorting, filtering, and record limits in AWK in a single $O(N)$ pass.
