# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-09-18 - Eliminating subshell process forks in backup iteration loops
**Learning:** Glob expansion of `datezip_YYYYMMDD_HHMMSS_*.zip` in Bash already returns filenames in sorted lexicographical (and thus chronological) order. Piping arrays through subshell loops `< <(printf ... | sort)` or spawning external processes (`basename`, `cut`, `ls`, `grep`) inside loops creates substantial process fork overhead that degrades CLI responsiveness when handling large backup sets.
**Action:** Use native Bash glob sorting directly (`local sorted=("$BACKUP_DIR_NAME"/datezip_*.zip)`) and pure parameter expansion (`${f##*/}`, `${f#...}`, `${f%...}`) instead of subshell utilities inside loops.

## 2026-10-12 - Streamlining history log processing via direct sort and awk
**Learning:** Iterating line-by-line over history logs using sequential `while read` Bash loops and multiple temporary files creates severe performance bottlenecks (taking >1.8s for 20,000 records) and is prone to state bleed bugs (e.g. unreset variables across iterations). Furthermore, checking filesystem existence (`[[ -f ... ]]`) per record inside Bash loops causes unnecessary repeated syscalls. Pre-extracting metadata with Bash globs and streaming `sort -r` directly into a single portable `awk` process reduces runtime to ~0.1s (>15x speedup) and eliminates disk temporary file creation completely.
**Action:** In CLI history tools, avoid intermediate `mktemp` files and Bash `while read` loops. Pre-extract batch metadata into strings via glob expansion, pipe sort outputs directly into `awk`, and manage state grouping, filtering, contiguous array storage, and limit-based early termination within `awk`.
