# Bolt Performance Journal

This is the performance journal of Bolt, where critical learnings and performance wins/metrics are documented.

## 2026-08-04 - Batching file metadata lookups in execute_status
**Learning:** Sequential file status queries in loops are extremely slow in Bash. Batching paths via `xargs stat` and doing lookups in an O(N) `awk` associative array delivers a huge speedup (>170x). To avoid crashing/unsupported function issues in BSD `awk` (such as One True Awk on macOS), `strftime` should not be used in `awk`. Instead, pre-format date/time via BSD `stat` formatting flags or parse the default GNU `stat` format in `awk` via string slicing. For BSD `stat`, use `%n` instead of `%N` to prevent symlink dereference decoration issues.
**Action:** Detect GNU vs BSD `stat` dynamically in Bash, run `xargs stat` with `--` to protect against parameter injection, and process the results in `awk` safely. Symmetrically strip `./` from paths to avoid matching discrepancies.

## 2026-08-05 - Streamlining execute_history via sort and awk single-pass streaming
**Learning:** Sequential `while read` loops in Bash coupled with repeated subshell invocations (e.g. `ls ... | grep ...`) and disk writes to multiple `mktemp` files cause significant process creation overhead and I/O latency when parsing large history files (~30x slowdown). Extracting backup metadata up front using pure Bash globbing and string manipulation (`${f##*/}`), then piping directly into a single O(N) `awk` script for filtering, grouping, and output formatting eliminates subshell overhead and speeds execution by >30x.
**Action:** Replace `while read` Bash loops that iterate over history lines with a direct `sort | awk` stream.
