# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-09-18 - Single-pass AWK pipeline for execute_history
**Learning:** Sequential `while read` Bash loops reading large history files combined with subshell execution (`ls` | `grep`) on timestamp group boundaries create significant I/O and process fork overhead. Pre-extracting FULL backup timestamps using pure Bash parameter expansion (`${f##*/}`) and piping `sort -r` directly into a single `awk` process for filtering, grouping, and formatting yields a ~8x-15x speedup. To stop input processing portably in POSIX AWK without GNU/BSD extensions like `nextfile`, invoking `exit` in the pattern-action block immediately jumps to the `END` block.
**Action:** Pipe sorted data directly into AWK, process grouping in AWK associative memory arrays, and use `exit` to terminate early on limits.
