# Bolt Performance Journal

This is the journal of Bolt, where critical performance learnings specific to the codebase are documented.

## 2026-07-24 - [Batched O(N) Metadata Retrieval and Comparison in execute_status]
**Learning:** Sequential querying of file metadata inside loops in bash/shell scripts is an extremely slow anti-pattern due to the high process-spawning overhead of repeatedly invoking subshells like `grep`, `cut`, `date`, or `stat`. By using `xargs stat` with null-delimited arguments, we can fetch all file metadata in a single batched process. Combining this with a single O(N) `awk` evaluation using associative arrays completely eliminates the sequential bottleneck while maintaining cross-platform compatibility (GNU vs BSD stat).
**Action:** Always batch metadata queries via `xargs stat` (ensuring compatibility across GNU and BSD `stat` formats and avoiding `strftime` inside `awk` due to macOS/BSD One True Awk limitations), and compare values in a single high-efficiency `awk` run instead of multi-step bash loops.
