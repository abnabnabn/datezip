# Bolt's Journal - Critical Learnings Only

## 2026-07-20 - [Subprocess Overhead in Loops]
**Learning:** In Shell/Bash scripting, executing commands (like `grep`, `cut`, `date`, `stat`) inside a `while` loop that iterates over thousands of files is extremely expensive due to subshell/process spawning overhead. For 1,000 files, spawning 3 subprocesses per file results in 3,000 subprocess creations, taking nearly ~9 seconds.
**Action:** Always batch process file attributes or utilize tools like `xargs` with `stat` to fetch all attributes in a single pass, then perform fast in-memory filtering and comparison with `awk`.
