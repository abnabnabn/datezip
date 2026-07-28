# Bolt's Performance Journal

Critical performance learnings and metrics to make datezip lightning fast.

## 2026-07-28 - [Sequential File Querying Bottleneck in status command]
**Learning:** Querying file modification times sequentially inside a Bash loop (e.g., using `date -r` or `stat`) is a major performance bottleneck, as it spawns thousands of subshell processes. This can turn an O(N) operation for 10,000 files into a minutes-long wait.
**Action:** Batch file paths using `xargs stat` to query filesystem times in bulk, and perform the difference comparison in a single O(N) `awk` invocation with associative arrays. To remain compatible with both GNU and BSD `stat` and avoid `strftime` syntax errors/crashes in BSD `awk` versions (which lack `strftime`), format BSD `stat` output natively (`stat -f %Sm -t %Y%m%d.%H%M%S`) and parse GNU `stat` output (`stat -c %y`) via standard string manipulation/substring extraction in `awk`.
