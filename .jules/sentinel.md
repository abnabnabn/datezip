# Sentinel Security Journal

This is the journal of Sentinel, where critical security learnings specific to the codebase are documented.

## 2026-07-20 - [Shell Arithmetic Evaluation and Command Injection in retention/restoration flags]
**Vulnerability:** Shell arithmetic injection via `--keep-full` and `--keep-days` options, and missing input validation on `--restore-index`, `--restore-time`, and `--restore-type`. Unsanitized user inputs could lead to arbitrary command execution when evaluated inside bash double-parentheses constructs `$(( ... ))` or comparison/conditional constructs.
**Learning:** Bash's arithmetic expansion `$(( expression ))` evaluates parameter and string values inside the expression dynamically, meaning index references like `arr[$(command)]` or expression formats are evaluated as subshells/commands. This can allow command execution even if the variable containing the string is not directly executed in a standard command.
**Prevention:** Always strictly validate all user-supplied numeric arguments and string parameters using regex matches (e.g., `[[ ! "$VAR" =~ ^[0-9]+$ ]]`) at argument parsing time before allowing them to be utilized anywhere in the script, particularly in arithmetic expansions or command evaluations.
## 2026-07-21 - [Option/Argument Injection and Regex Injection in File Operations]
**Vulnerability:** Option/argument injection via user-supplied paths/files starting with a hyphen, and potential regex injection inside loop lookup logic in `execute_status`.
**Learning:** Utilities like `mkdir`, `cp`, `ln`, `chmod`, and `rm` can have their option-parsing hijacked if target file paths or directories start with a hyphen (`-`). Similarly, using `grep` with unescaped variable input interprets regex control characters inside filenames, leading to incorrect matches.
**Prevention:** Explicitly validate user-supplied paths and files to ensure they do not start with a hyphen (`-`) and append `--` to separate options from positional arguments in system utility calls. For status file matching, use exact hash lookups (via `awk`) rather than sequential regex grep.

## 2026-07-22 - [Option Injection in Multi-Value Parameter Lists]
**Vulnerability:** Option injection via comma-separated item list in `--files` parameter. Validating only the parameter string header (`$RESTORE_FILES =~ ^-`) allowed subsequent comma-separated items (e.g. `valid.txt,-o`) to bypass check and pass options directly to `unzip`.
**Learning:** Checking only the start of a multi-value list parameter fails to validate inner items. Commands like `unzip` do not support the standard `--` option parser terminator and will parse any argument starting with `-` as CLI options.
**Prevention:** Always split multi-value parameter lists (e.g., comma-separated values) and validate each individual element for leading hyphens before passing them downstream.
