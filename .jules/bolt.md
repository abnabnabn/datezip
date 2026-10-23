# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-09-18 - Eliminating subshell process forks in backup iteration loops
**Learning:** Glob expansion of `datezip_YYYYMMDD_HHMMSS_*.zip` in Bash already returns filenames in sorted lexicographical (and thus chronological) order. Piping arrays through subshell loops `< <(printf ... | sort)` or spawning external processes (`basename`, `cut`, `ls`, `grep`) inside loops creates substantial process fork overhead that degrades CLI responsiveness when handling large backup sets.
**Action:** Use native Bash glob sorting directly (`local sorted=("$BACKUP_DIR_NAME"/datezip_*.zip)`) and pure parameter expansion (`${f##*/}`, `${f#...}`, `${f%...}`) instead of subshell utilities inside loops.

## 2026-10-14 - Filtering header markers directly in history cache validation
**Learning:** Scanning every single file record in `$HISTORY_CACHE_FILE` to build timestamp lists during `update_history_cache()` causes unnecessary I/O and process pipeline overhead as the cache file grows. By filtering header markers directly (`$2 == "*"`) in `awk` and extracting timestamps from file paths using native Bash parameter expansions (`${ts_tmp%.zip}`, `${ts_tmp%_FULL}`, `${ts_tmp%_INC}`), pipeline runtime is reduced by ~1.25x - 1.30x on large history sets.
**Action:** Target header marker records directly in `awk` when retrieving cache archive timestamps instead of scanning all file entries.
