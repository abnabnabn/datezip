# Bolt Performance Journal

This is Bolt's journal for documenting CRITICAL performance-specific learnings from optimizing the 'datezip' codebase.

## 2026-08-02 - [Batched `stat` and associative array `awk` vs sequential Bash loop]
**Learning:** Querying metadata sequentially via `date -r` or `stat` inside a Bash loop introduces major process-spawning overhead (O(N) subprocesses), taking 43+ seconds for 5000 files. By batching file queries using `xargs -0 stat` with `--` and comparing the results in a single O(N) `awk` process with associative arrays, the overhead is reduced to a single subprocess invocation, achieving a 172x speedup (~0.25 seconds). Furthermore, stripping `./` symmetrically on paths prevents false negatives/positives caused by varying git and non-git traversal path formatting.
**Action:** Avoid querying individual file metadata in loops in shell scripts; always batch with `xargs` and compare using `awk` associative arrays, taking care to handle option injection via `--` and formatting differences across platforms.
