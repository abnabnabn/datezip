# Bolt Performance Journal

This is the performance-focused journal of Bolt, detailing critical performance learnings and optimizations within the datezip codebase.

## 2026-07-30 - [O(N) Batched File Metadata Query and awk Comparison]
**Learning:** Querying file metadata (like modification time `mtime`) sequentially in a loop inside Bash is a major bottleneck due to process spawning overhead (e.g. running `grep`, `cut`, and `date`/`stat` per file). Instead of executing N queries sequentially, batching the files via `xargs stat` and processing the results in a single `awk` pass using memory-based associative arrays reduces process creation overhead from O(N) to O(1) (running only ~5 processes instead of ~3000 for 1000 files).
**Action:** Avoid querying individual file properties sequentially inside shell loops. Batch them using tools like `xargs stat` (ensuring proper detection of GNU vs BSD variants, avoiding `strftime` in awk for BSD compatibility, and terminating options with `--` for argument injection protection), then perform comparisons using a single, memory-efficient `awk` step.
