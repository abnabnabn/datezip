# Bolt Performance Journal

This is the journal of Bolt, where critical performance learnings specific to the codebase are documented.

## 2026-07-27 - [Batching Metadata Queries in Bash Loops]
**Learning:** Querying file metadata via `stat` or `date` inside a sequential `while` loop in Bash is extremely expensive due to massive fork-exec process spawning overhead (e.g., taking nearly 4 seconds for 500 files). By batching file path queries using `tr '\n' '\0' | xargs -0 stat` and processing the results in a single `awk` process with associative arrays, the operation scales linearly/near-constantly, resulting in a 34.7x speedup (~97% runtime reduction).
**Action:** For any recursive file checking or processing in shell scripts, always avoid loops that query metadata file-by-file. Batch metadata collection via `xargs` and compare using associative arrays in `awk`. Avoid using `strftime` inside `awk` blocks to prevent compile-time crashes in BSD/macOS `awk`.
