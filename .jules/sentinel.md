# Sentinel Journal

## 2025-02-17 - Shell Arithmetic and Input Validation Injection in datezip
**Vulnerability:** Shell arithmetic expansion in Bash can evaluate command substitutions nested inside unvalidated numeric arguments (such as `--keep-full` or `--restore-index`) when used in expressions like `$(( num_f - KEEP_FULL ))` or `${sorted[$choice]}`.
**Learning:** Bash automatically evaluates arithmetic expressions and array indices. If user-controlled strings contain nested command substitutions like `1 + $(id)`, Bash parses and runs the command substitution before performing the math or indexing.
**Prevention:** Always validate numeric configurations or indices using strict regular expressions like `[[ ! "$VAR" =~ ^[0-9]+$ ]]` immediately upon parsing.
