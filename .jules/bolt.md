# Bolt Performance Journal

This is the journal of Bolt, where critical performance learnings specific to the codebase and shell optimizations are documented.

## 2026-07-23 - [Portability of Awk strftime and O(1) Batching of File Metadata]
**Learning:**
1. In Bash, querying file metadata (such as modification time) inside loops using per-file subshells like `stat` or `date` scales at $O(N)$ and is a major performance bottleneck. This can be optimized to $O(1)$ by batching paths through `xargs stat` and processing the results in memory in a single `awk` pass.
2. In `awk`, the `strftime` built-in is a GNU extension and is completely unsupported in BSD `awk` (One True Awk) on macOS. Since `awk` compiles/parses the entire script before execution, even if a call to `strftime` is gated behind a conditional block, it will crash with a compilation error at startup.
3. To achieve universal portability and peak performance on both GNU and BSD, format the timestamps directly using the OS-specific `stat` command (`stat -c "%y"` on GNU, and `stat -f "%Sm" -t "%Y%m%d.%H%M%S"` on BSD) and parse GNU's output using native, compile-safe `awk` string manipulation functions (`split`, `sub`).
**Action:** Always avoid `strftime` in `awk` scripts that may run on macOS. Use native `stat` formatting and light, clean string operations in `awk` for platform-agnostic, lightning-fast execution.
