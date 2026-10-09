# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Streaming and single-pass AWK processing in execute_history
**Learning:** Sequential `while read` Bash loops and disk temporary files (`mktemp`) cause massive overhead when processing tens of thousands of history lines. Pre-extracting metadata (such as FULL backup timestamps) using Bash globbing and pure string parameter expansion (`${f##*/}`) and piping `sort -r` directly into a single O(N) `awk` script eliminates process spawns (`ls`, `grep`), disk writes, and loop iterations, yielding a >17x speedup (~4.01s down to ~0.23s on 50k items).
**Action:** Stream sorted inputs directly into `awk` for filtering, grouping, and output formatting instead of writing temporary cache files and looping in Bash.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.
