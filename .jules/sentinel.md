# Sentinel Security Journal

This is the journal of Sentinel, where critical security learnings specific to the codebase are documented.

## 2026-08-03 - [Option Injection via User Paths and Filename Pattern Injection in History and Status]
**Vulnerability:** Option and argument injection when executing system utility commands (e.g., `mkdir`, `ln`, `cp`, `chmod`, `rm`) with user-supplied filenames or directory paths starting with hyphens. In addition, regex injection via unescaped filenames passed directly to pattern-matching utilities like `grep`.
**Learning:** System commands parse arguments sequentially, interpreting any string prefixed with `-` as a command flag/option. Furthermore, string matching using regular-expression search engines (such as `grep`) can fail, throw syntax errors, or generate false positives when the search key (e.g., a filename) contains active regex characters like `.`, `*`, `[`, or `]`.
**Prevention:**
1. Always validate that user-provided filepath or name parameters do not start with a hyphen (`-`) during argument parsing.
2. Ensure standard system commands cleanly terminate option parsing using double dashes (`--`).
3. Replace regex-based string lookups with exact matching in static parsing tools like `awk` (using `==` exact equality comparison on raw variables) to guarantee clean, safe parameter evaluation.

## 2026-07-20 - [Shell Arithmetic Evaluation and Command Injection in retention/restoration flags]
**Vulnerability:** Shell arithmetic injection via `--keep-full` and `--keep-days` options, and missing input validation on `--restore-index`, `--restore-time`, and `--restore-type`. Unsanitized user inputs could lead to arbitrary command execution when evaluated inside bash double-parentheses constructs `$(( ... ))` or comparison/conditional constructs.
**Learning:** Bash's arithmetic expansion `$(( expression ))` evaluates parameter and string values inside the expression dynamically, meaning index references like `arr[$(command)]` or expression formats are evaluated as subshells/commands. This can allow command execution even if the variable containing the string is not directly executed in a standard command.
**Prevention:** Always strictly validate all user-supplied numeric arguments and string parameters using regex matches (e.g., `[[ ! "$VAR" =~ ^[0-9]+$ ]]`) at argument parsing time before allowing them to be utilized anywhere in the script, particularly in arithmetic expansions or command evaluations.
