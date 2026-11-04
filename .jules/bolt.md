# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-09-18 - Eliminating subshell process forks in backup iteration loops
**Learning:** Glob expansion of `datezip_YYYYMMDD_HHMMSS_*.zip` in Bash already returns filenames in sorted lexicographical (and thus chronological) order. Piping arrays through subshell loops `< <(printf ... | sort)` or spawning external processes (`basename`, `cut`, `ls`, `grep`) inside loops creates substantial process fork overhead that degrades CLI responsiveness when handling large backup sets.
**Action:** Use native Bash glob sorting directly (`local sorted=("$BACKUP_DIR_NAME"/datezip_*.zip)`) and pure parameter expansion (`${f##*/}`, `${f#...}`, `${f%...}`) instead of subshell utilities inside loops.

## 2026-11-04 - Streaming history cache parsing and formatting through AWK
**Learning:** In `execute_history`, sequentially reading history entries in a Bash `while IFS='|' read` loop, dumping to temporary files, sorting, and then re-reading lines in another Bash `while` loop (with per-line filesystem check `[[ -f ... ]]` for full backup archives) causes serious I/O and process overhead on large history logs. Piping filtered output directly into `sort -r` and a single `awk` process with pre-indexed FULL backup timestamps reduces execution time by ~20x (e.g. from 1.35s down to 0.06s for 20,000 entries) while eliminating disk tempfiles. Note: in BSD/mawk, avoid `return` outside functions (use `exit`) and track stored record counts separately from match counts when buffering arrays for `--files`.
**Action:** Stream pipeline processing using `awk` and `sort -r`, pre-index archive types into an `awk` associative set from bash globs, and terminate cleanly with POSIX `exit`.
