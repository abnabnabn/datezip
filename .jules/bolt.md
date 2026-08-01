# Bolt Performance Journal

This is the journal of Bolt, where critical performance learnings specific to the codebase are documented.

## 2026-08-01 - [Subprocess Spawning in Bash Loops and O(N) Batch Processing]
**Learning:** Spawning subprocesses like `grep`, `date`, or `stat` sequentially inside a loop in Bash introduces a huge overhead. For directories with hundreds or thousands of files, this can make execution take minutes instead of seconds. Batching file metadata queries via `xargs stat` and doing the comparison in a single O(N) `awk` pass reduces execution time by over 95%. To ensure cross-platform compatibility without breaking or syntax errors in BSD `awk`, string formatting should be done directly in BSD `stat` and parsed from GNU `stat` via string manipulation instead of utilizing `strftime` inside `awk`.
**Action:** Always batch query filesystem metadata using `xargs` and perform lookup/comparison inside a single `awk` process using associative arrays, symmetrically stripping prefixes like `./` for robust comparison.
