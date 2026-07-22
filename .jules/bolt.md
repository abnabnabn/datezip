# Bolt's Journal - Critical Learnings Only

## 2026-07-22 - [O(1) Batch Metadata Processing in datezip --status]
**Learning:** Sequential execution of `grep` and `date`/`stat` inside loops causes severe process spawning overhead, slowing operations from O(N) to O(N * process_overhead). This can be optimized to O(1) process overhead by using `xargs stat` with platform-specific formatting and processing the output with an O(N) single-pass `awk` using associative arrays.
**Action:** Always batch filesystem metadata retrieval using `xargs stat` when processing lists of files, and parse the outputs inside a unified `awk` script to minimize process spawns.
