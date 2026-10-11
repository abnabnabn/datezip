# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-08-05 - Streamlining execute_history with pure Bash globbing and AWK
**Learning:** In `execute_history`, running sequential `while read` loops in Bash and spawning subshells (`ls`/`grep`) for every timestamp in history creates significant process fork and shell iteration overhead on large history datasets (>2s for 20k entries). Pre-extracting FULL backup timestamps via Bash globbing (`datezip_*_FULL.zip`) and pure Bash parameter expansion (`${f##*/}`) eliminates subshell spawns. Piping the cache directly into an `awk` filter pass, `sort -r`, and an output formatting `awk` block avoids writing intermediate temp files and speeds up execution by >8.5x overall (>30x for core history processing).
**Action:** Use pure Bash globbing and parameter expansions for filename matching, and delegate line filtering and record grouping to portable `awk` pipelines instead of line-by-line Bash `while read` loops.
