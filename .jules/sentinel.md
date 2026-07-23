# Sentinel Security Journal

This is the journal of Sentinel, where critical security learnings specific to the codebase are documented.

## 2026-07-20 - [Shell Arithmetic Evaluation and Command Injection in retention/restoration flags]
**Vulnerability:** Shell arithmetic injection via `--keep-full` and `--keep-days` options, and missing input validation on `--restore-index`, `--restore-time`, and `--restore-type`. Unsanitized user inputs could lead to arbitrary command execution when evaluated inside bash double-parentheses constructs `$(( ... ))` or comparison/conditional constructs.
**Learning:** Bash's arithmetic expansion `$(( expression ))` evaluates parameter and string values inside the expression dynamically, meaning index references like `arr[$(command)]` or expression formats are evaluated as subshells/commands. This can allow command execution even if the variable containing the string is not directly executed in a standard command.
**Prevention:** Always strictly validate all user-supplied numeric arguments and string parameters using regex matches (e.g., `[[ ! "$VAR" =~ ^[0-9]+$ ]]`) at argument parsing time before allowing them to be utilized anywhere in the script, particularly in arithmetic expansions or command evaluations.

## 2026-07-21 - [Option/Argument Injection in Paths and Regex Filename Injection]
**Vulnerability:** Potential option/argument injection through unvalidated user-provided directory/file paths (like `--dest`, `--files`, and installation directories) when passed to utility commands like `mkdir`, `chmod`, `ln`, or `cp`. Unsanitized filenames containing regex characters matching via `grep "^$f|"` also allowed matching unexpected files or crashing execution.
**Learning:** Shell utilities interpret leading hyphens as option options unless explicitly delimited with `--` or validated in code. Similarly, dynamic parameters in grep patterns are interpreted as regular expressions, creating incorrect state matches.
**Prevention:** Strictly validate that all untrusted file, directory, or list inputs do not begin with a hyphen (`-`). Ensure that all standard file utility command calls use `--` as an option terminator. Rephrase dynamic grep commands as fixed-string comparisons in awk using the `-v` parameter or direct equality comparisons.
