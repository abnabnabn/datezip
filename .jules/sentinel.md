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
**Vulnerability:** Option injection in `--files` parameter when passing comma-separated file lists (e.g., `file.txt,-option`). Checking only the start of the full parameter string allowed individual list items starting with hyphens to pass validation and be passed as flags to downstream tools like `unzip`.
**Learning:** Checking parameter strings for leading hyphens at the top level is insufficient for multi-value inputs (like CSV arguments). Each element must be split and checked individually.
**Prevention:** Split multi-value arguments on delimiters during option parsing, trim leading whitespace, and iterate through every individual value to verify none start with `-`.

## 2026-07-23 - [Path Traversal and Arbitrary File Read in MCP Historical Content Tool]
**Vulnerability:** Arbitrary file read via path traversal in `get_historical_content` in `mcp/server.py`. Passing an absolute path (e.g., `/etc/passwd`) or relative traversal (`../../`) caused `os.path.join(tmp_dir, filename)` to resolve directly to host filesystem files outside `tmp_dir`, leaking sensitive host files when opened.
**Learning:** In Python, `os.path.join(base_dir, user_path)` returns `user_path` directly when `user_path` is absolute, completely discarding `base_dir`. Furthermore, relative path traversals (`../`) resolve to parent directories if not strictly canonicalized.
**Prevention:** Check and reject absolute paths with `os.path.isabs(filename)`, canonicalize paths with `os.path.realpath`, verify target paths remain within the intended directory (`target_path == real_base or target_path.startswith(real_base + os.sep)`), and ensure only regular files are read (`os.path.isfile`).
