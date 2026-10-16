# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-09-18 - Eliminating subshell process forks in backup iteration loops
**Learning:** Glob expansion of `datezip_YYYYMMDD_HHMMSS_*.zip` in Bash already returns filenames in sorted lexicographical (and thus chronological) order. Piping arrays through subshell loops `< <(printf ... | sort)` or spawning external processes (`basename`, `cut`, `ls`, `grep`) inside loops creates substantial process fork overhead that degrades CLI responsiveness when handling large backup sets.
**Action:** Use native Bash glob sorting directly (`local sorted=("$BACKUP_DIR_NAME"/datezip_*.zip)`) and pure parameter expansion (`${f##*/}`, `${f#...}`, `${f%...}`) instead of subshell utilities inside loops.

## 2026-10-16 - Streaming history filtering and formatting in a single AWK pipeline
**Learning:** Sequential `while read` Bash loops with temporary files (`mktemp`) and per-line filesystem checks (`[[ -f ... ]]`) degrade CLI responsiveness as history cache files grow (>10k lines). Pre-extracting FULL backup timestamps upfront via Bash globbing and piping `sort -r` directly into a single AWK process for filtering, limiting (`--limit`), grouping, and section header formatting achieved a >48x speedup (1.46s -> 0.03s on 20,000 entries). When implementing limits in AWK, track stored record counts (`stored_count`) separately from matched records to ensure contiguous array indexing and correct output in `END` blocks.
**Action:** Stream sorted history lines into AWK and pass parameter variables via `-v` to perform filtering, array indexing, and formatted output in a single pass.
