# Sentinel Security Journal

This is the journal of Sentinel, where critical security learnings specific to the codebase are documented.

## 2026-07-20 - [Shell Arithmetic Evaluation and Command Injection in retention/restoration flags]
**Vulnerability:** Shell arithmetic injection via `--keep-full` and `--keep-days` options, and missing input validation on `--restore-index`, `--restore-time`, and `--restore-type`. Unsanitized user inputs could lead to arbitrary command execution when evaluated inside bash double-parentheses constructs `$(( ... ))` or comparison/conditional constructs.
**Learning:** Bash's arithmetic expansion `$(( expression ))` evaluates parameter and string values inside the expression dynamically, meaning index references like `arr[$(command)]` or expression formats are evaluated as subshells/commands. This can allow command execution even if the variable containing the string is not directly executed in a standard command.
**Prevention:** Always strictly validate all user-supplied numeric arguments and string parameters using regex matches (e.g., `[[ ! "$VAR" =~ ^[0-9]+$ ]]`) at argument parsing time before allowing them to be utilized anywhere in the script, particularly in arithmetic expansions or command evaluations.

## 2026-07-22 - [Option and Regex Injection via Filename Parameters]
**Vulnerability:** Filenames and directories starting with `-` (e.g., `-v`, `-x`) could trigger option injection when passed to commands like `unzip` (which does not support standard `--` option separators) or `mkdir`/`cp` in the installer. Additionally, filenames with regex metacharacters could cause matching errors or regex injection in `grep` when querying cached metadata.
**Learning:** Even when using standard array-based executions in Bash, option injection can occur if downstream commands (like `unzip`) do not support `--` to delimit option parsing, allowing parameters to be parsed as options. Furthermore, using `grep` with unescaped filenames creates severe regex injection vectors.
**Prevention:** Strictly validate that all supplied paths and filenames do not start with `-` at parameter parsing time. Use precise fixed-string matching (e.g. `awk -v fname="$f" '$1 == fname'`) instead of unescaped regex matches for filename-based metadata queries.
