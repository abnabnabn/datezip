# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-09-18 - Eliminating subshell process forks in backup iteration loops
**Learning:** Glob expansion of `datezip_YYYYMMDD_HHMMSS_*.zip` in Bash already returns filenames in sorted lexicographical (and thus chronological) order. Piping arrays through subshell loops `< <(printf ... | sort)` or spawning external processes (`basename`, `cut`, `ls`, `grep`) inside loops creates substantial process fork overhead that degrades CLI responsiveness when handling large backup sets.
**Action:** Use native Bash glob sorting directly (`local sorted=("$BACKUP_DIR_NAME"/datezip_*.zip)`) and pure parameter expansion (`${f##*/}`, `${f#...}`, `${f%...}`) instead of subshell utilities inside loops.

## 2026-10-31 - Streamlining history filtering and formatting into single awk pipeline
**Learning:** In `execute_history`, parsing history records line-by-line via Bash `while read` loops into temporary files and then re-reading them line-by-line in another Bash loop incurs high I/O overhead and string allocation cost in Bash. In contrast, pre-collecting FULL backup timestamps via pure Bash glob expansion and piping the filtered, sorted cache directly into a single formatting AWK program eliminates intermediate temporary files and executes in C-speed (>10x speedup). When accumulating records in AWK subject to an early limit, use `next` instead of `exit` to ensure the `END` block still executes and formats buffered records portably.
**Action:** Avoid intermediate scratch files and `while IFS= read` loops for data formatting in Bash; stream pipelines into AWK and pass reference sets as variables or split strings.
