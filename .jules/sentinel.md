# Sentinel Security Journal

This is the journal of Sentinel, where critical security learnings specific to the codebase are documented.

## 2026-07-20 - [Shell Arithmetic Evaluation and Command Injection in retention/restoration flags]
**Vulnerability:** Shell arithmetic injection via `--keep-full` and `--keep-days` options, and missing input validation on `--restore-index`, `--restore-time`, and `--restore-type`. Unsanitized user inputs could lead to arbitrary command execution when evaluated inside bash double-parentheses constructs `$(( ... ))` or comparison/conditional constructs.
**Learning:** Bash's arithmetic expansion `$(( expression ))` evaluates parameter and string values inside the expression dynamically, meaning index references like `arr[$(command)]` or expression formats are evaluated as subshells/commands. This can allow command execution even if the variable containing the string is not directly executed in a standard command.
**Prevention:** Always strictly validate all user-supplied numeric arguments and string parameters using regex matches (e.g., `[[ ! "$VAR" =~ ^[0-9]+$ ]]`) at argument parsing time before allowing them to be utilized anywhere in the script, particularly in arithmetic expansions or command evaluations.

## 2026-07-21 - [Option Injection and Regex Injection in Path/File Actions]
**Vulnerability:** Option injection via hyphen-prefixed paths/files passed directly to commands like `mkdir`, `cp`, `ln`, and `chmod`, and regex injection in history queries using `grep` with unescaped filename variables.
**Learning:** Standard system utilities interpret any argument starting with a hyphen `-` as an option flag unless separated by a `--` option terminator. Filenames containing special characters (like `*`, `.`, `[`) can alter the behavior of `grep` if unescaped and parsed as regexes.
**Prevention:** Always reject user-provided filename or directory inputs that start with a hyphen `-`. For system utility calls, insert a `--` option terminator before passing variables. Use exact fixed-string comparisons (e.g., `awk` with field matching) instead of `grep` with variable-interpolated regexes.
