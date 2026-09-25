# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Pure Bash Globbing and Parameter Expansion vs Subshell Pipelines in Loops
**Learning:** Relying on external command pipelines (`printf | sort`, `basename`, `cut`, `ls | grep`) inside Bash loops introduces severe subshell process-fork overhead. In Bash, globbing expansions (`datezip_*.zip`) are already sorted in ASCII/chronological order. Replacing external tools in loops with pure Bash parameter expansion (`${zip##*/}`, `${fname#datezip_}`, `${ts_tmp%_*}`) and direct array indexing (`${backups[-1]}`) dramatically reduces execution time (e.g. `--list` speedup >31x from 0.573s to 0.018s for 200 items).
**Action:** Always prefer native Bash array indexing, globbing, and parameter expansion over spawning external process subshells (`basename`, `cut`, `sort`) in loops.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.
