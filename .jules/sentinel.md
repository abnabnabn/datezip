# Sentinel Security Journal

This is the journal of Sentinel, where critical security learnings specific to the codebase are documented.

## 2026-07-20 - [Shell Arithmetic Evaluation and Command Injection in retention/restoration flags]
**Vulnerability:** Shell arithmetic injection via `--keep-full` and `--keep-days` options, and missing input validation on `--restore-index`, `--restore-time`, and `--restore-type`. Unsanitized user inputs could lead to arbitrary command execution when evaluated inside bash double-parentheses constructs `$(( ... ))` or comparison/conditional constructs.
**Learning:** Bash's arithmetic expansion `$(( expression ))` evaluates parameter and string values inside the expression dynamically, meaning index references like `arr[$(command)]` or expression formats are evaluated as subshells/commands. This can allow command execution even if the variable containing the string is not directly executed in a standard command.
**Prevention:** Always strictly validate all user-supplied numeric arguments and string parameters using regex matches (e.g., `[[ ! "$VAR" =~ ^[0-9]+$ ]]`) at argument parsing time before allowing them to be utilized anywhere in the script, particularly in arithmetic expansions or command evaluations.

## 2026-07-21 - [Option/Argument Injection and Regex Vulnerabilities via Filenames/Paths]
**Vulnerability:** Option/argument injection through unconstrained path/filename parameters (such as target install directories, `--dest`, or `--files` items) starting with a hyphen (`-`), and regex injection/denial-of-service in `grep` through unescaped filename parameters.
**Learning:** Shell utilities (like `mkdir`, `cp`, `ln`, `chmod`, `rm`, `unzip`, `grep`) can treat user-controlled filenames as options if they start with a hyphen. While most standard system commands can use `--` to cleanly terminate option parsing, some utilities (like `unzip`) do not support `--`.
**Prevention:** 1) Reject user-provided filenames, directories, or paths that start with a hyphen (`-`) at parsing time. 2) Utilize `--` standard option termination delimiters in commands that support it. 3) Replace unescaped regex searches on user-controlled inputs with fixed-string comparisons using `awk`.
