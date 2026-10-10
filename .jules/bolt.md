# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-05 - Streamlining execute_history with a single AWK pipeline
**Learning:** Sequential `while read` Bash loops that read temporary files or execute `ls` / `grep` subshells per entry cause massive process fork overhead when processing history files. Streaming `sort -r` directly into a single AWK process (with FULL backup timestamps pre-extracted via pure Bash parameter expansion) reduces execution time from ~1.47s to ~0.03s (>48x speedup) on 10,000 history entries.
**Action:** When filtering and formatting tabular history data in Bash, pipe `sort` directly into `awk` and perform filtering (`--from`, `--to`, `--limit`), grouping, and lookup matching in AWK memory arrays.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.
