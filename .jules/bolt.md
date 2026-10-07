# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-08-05 - Stream-processing history filtering with AWK pipeline
**Learning:** In Bash CLI tools, reading large text streams via `while read` loops combined with temporary files (`mktemp`) and spawning subshells per line (e.g., `ls` + `grep` to check backup types) introduces severe overhead (>3.8s for 50k lines). Piping `sort -r` directly into a single `awk` process with pre-computed map parameters reduces total processing time to <0.16s (>23x speedup).
**Action:** Extract pre-computed lookup strings (e.g. FULL backup timestamps) using pure Bash expansion (`${f##*/}`) before `awk` invocation, pass them as AWK variables via `-v`, and perform string splitting (`split()`), filtering, grouping, and limits entirely within AWK.
