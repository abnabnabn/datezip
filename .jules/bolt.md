# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-09-18 - Single pipeline execute_history with pre-extracted FULL timestamps
**Learning:** Sequential `while read` Bash loops that filter, sort, write to temporary files, and check backup types via per-line subshells (`ls | grep`) are extremely slow on large history caches (>3.8s for 50k lines). Pre-extracting FULL backup timestamps into a space-separated variable using pure Bash string expansion (`${f##*/}`) and piping `sort -r` directly into a single `awk` process handles filtering (`--from`, `--to`, `--limit`, `--files`), hashtable backup-type matching, and output formatting in one fast O(N) pass, reducing runtime from 3.88s to ~0.15s (>25x speedup).
**Action:** Replace multi-stage temp file creation and `while read` loops with direct stream sorting piped into `awk` with pre-populated maps.
