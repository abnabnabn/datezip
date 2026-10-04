# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-10-04 - Consolidating ZIP archive inspection into a single AWK stream
**Learning:** Sequential per-file subshell invocations (`basename`, `cut`, per-file `awk`) inside loops processing backup archives create substantial process-fork overhead. By switching to pure Bash parameter expansion (`${filepath##*/}`) and piping all `unzip -Z -T` output into a single AWK stream with delimiter section markers (`===ZIP:${ts}===`), we reduced subshell creations by ~75% and achieved a ~2x speedup on history cache rebuilding. Furthermore, delimiter splitting via AWK regex field separators (`awk -F'[_.]'`) on full file paths can easily break if directory names contain dots or underscores; extracting the filename (`${b##*/}`) prior to string operations prevents subtle path-matching regressions.
**Action:** Always extract the base filename before splitting on delimiters, and stream multi-archive inspections into a single AWK script with custom section markers instead of invoking AWK per file.
