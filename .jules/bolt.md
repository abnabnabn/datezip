# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-08-04 - Streaming AWK history filtering and pure Bash glob sorting
**Learning:** Sequential `while read` Bash loops and per-item subshells (e.g. `ls | grep` or `basename`/`cut`) create massive process fork overhead when processing thousands of records. In Bash, glob expansion results (`datezip_*.zip`) are already chronologically sorted, making `printf ... | sort | tail` redundant. Furthermore, piping `sort -r` directly into a single `awk` process for filtering, grouping, and formatting eliminates temporary files and Bash loop overhead, achieving a 28x+ speedup.
**Action:** Rely on Bash glob sorting, use pure parameter expansions (`${var##*/}`) for string manipulation, and stream data directly into `awk` for complex filtering and formatting.
