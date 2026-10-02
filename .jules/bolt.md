# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Stream history cache through awk in execute_history
**Learning:** Sequential `while read` Bash loops with subshell process spawning (`ls | grep`, `basename`, `cut`) inside history queries create massive process fork overhead when processing larger history files. Pre-extracting FULL backup timestamps via pure Bash globbing (`${f##*/}`, `${f#...}`) and piping `sort -r` directly into a single `awk` process for filtering, grouping, and formatting reduced runtime from >1.05s to ~0.06s (>15x-18x speedup) on 10,000 history items, while avoiding temporary disk cache files.
**Action:** Stream line-oriented history cache reads into `awk` with `-v` state variables rather than writing temporary files and reading them back with `while read` in Bash.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.
