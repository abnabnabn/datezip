# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-09-19 - Stream-processing history filtering & formatting in execute_history
**Learning:** Reading history files line-by-line in Bash `while read` loops combined with temporary files and repeated subshell execution (`ls` + `grep` per timestamp entry) causes massive bottlenecking in CLI tools. Moving the entire processing pipeline to `sort -r | awk` while pre-extracting FULL backup timestamps safely via native Bash parameter expansion (`${fn#datezip_}` and `${fn%_FULL.zip}`) yields a ~15x+ speedup. Note: Avoid `nextfile` in AWK scripts for portability across AWK flavors (like `mawk`), and use `exit` when stopping record consumption early on a single stream.
**Action:** Pipe sorting and filtering directly into AWK, handle early exit using portable `exit` statements, and pre-compute metadata sets in Bash before invoking AWK.
