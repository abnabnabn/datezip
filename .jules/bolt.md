# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-09-18 - Eliminating subshell process forks in backup iteration loops
**Learning:** Glob expansion of `datezip_YYYYMMDD_HHMMSS_*.zip` in Bash already returns filenames in sorted lexicographical (and thus chronological) order. Piping arrays through subshell loops `< <(printf ... | sort)` or spawning external processes (`basename`, `cut`, `ls`, `grep`) inside loops creates substantial process fork overhead that degrades CLI responsiveness when handling large backup sets.
**Action:** Use native Bash glob sorting directly (`local sorted=("$BACKUP_DIR_NAME"/datezip_*.zip)`) and pure parameter expansion (`${f##*/}`, `${f#...}`, `${f%...}`) instead of subshell utilities inside loops.

## 2026-10-15 - Streamlining execute_history into a single AWK pipeline
**Learning:** Iterating line-by-line over history logs using Bash `while read` loops while creating/removing temporary files (`mktemp`) and executing per-timestamp `[[ -f ... ]]` disk checks creates severe process fork overhead (taking >4 seconds for 50,000 entries). Pre-extracting FULL backup timestamps into memory using Bash globbing and pure parameter expansion, then streaming `sort -r` directly into a single POSIX-compliant `awk` process for filtering, grouping, and output formatting achieves a >10x speedup (~0.38s vs ~3.98s).
**Action:** For history line processing, pass pre-extracted metadata variables to `awk` (`-v full_ts_str="..."`) and buffer/format records in `awk`'s `END` block rather than looping in Bash.
