#!/bin/bash

# --- Constants ---
readonly BACKUP_DIR_NAME="backups"
readonly CONFIG_FILE_NAME=".datezip"
readonly HISTORY_CACHE_FILE="$BACKUP_DIR_NAME/.datezip_history"
readonly DATE_FORMAT="%Y%m%d_%H%M%S"

# --- Global Variables (Set by Argument Parsing) ---
FORCE_TYPE=""
RESTORE_MODE=false
RESTORE_INDEX=""
RESTORE_TIME=""
RESTORE_TYPE=""
RESTORE_FILES=""
RESTORE_DEST="."
ACTION_LIST=false
ACTION_STATUS=false
ACTION_CLEANUP=false
ACTION_HISTORY=false
ACTION_REINDEX=false
HISTORY_FROM=""
HISTORY_TO=""
HISTORY_LIMIT=""
EXPLICIT_BACKUP=false
FORCE_GIT_ROOT=false
FORCE_LOCAL=false
QUIET_MODE=false
TARGET_DIR="$PWD"

KEEP_FULL=10
KEEP_DAYS=14

log() {
    if [[ "$QUIET_MODE" == false ]]; then
        printf "%b\n" "$1"
    fi
}

check_dependencies() {
    local deps=("zip" "unzip" "find" "sort" "awk" "sed" "comm")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: Required command '$cmd' is not installed or not in PATH." >&2
            exit 1
        fi
    done
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

A utility for recursive directory backups with .gitignore support and retention management.

Options:
  -h, --help           Show this help message and exit
  -q, --quiet          Suppress informational output
  --backup             Explicitly trigger a backup (default behavior)
  --full               Force a full backup
  --inc                Force an incremental backup
  --restore            Enter interactive restore mode
  --restore-index N    Non-interactive: restore backup at index N
  --restore-time TS    Non-interactive: restore to timestamp (YYYYMMDD_HHMMSS)
  --restore-type e|j   Non-interactive: (e)verything/chain or (j)ust the specific index
  --dest PATH          Destination directory for restore (default: .)
  --files LIST         Comma-separated list of files to filter/restore
  --history            Show chronological file history
  --limit N            Limit history output to N most recent entries
  --from TS            Filter history start (format: YYYYMMDD_HHMMSS)
  --to TS              Filter history end (format: YYYYMMDD_HHMMSS)
  --reindex            Rebuild the history cache from existing ZIP archives
  --list               List available backups and their indices
  --status             Show changes since the last backup
  --cleanup            Prune old backups
  --keep-full N        Number of full backups to keep (default: 10)
  --keep-days N        Number of days to retain full backups (default: 14)
  --local              Ignore Git root detection
  --git-root           Force operation on the Git project root
EOF
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            -q|--quiet) QUIET_MODE=true ;;
            --backup) EXPLICIT_BACKUP=true ;;
            --full) FORCE_TYPE="FULL" ;;
            --inc) FORCE_TYPE="INC" ;;
            --restore) RESTORE_MODE=true ;;
            --restore-index)
                RESTORE_INDEX="$2"; shift
                # Security: Validate index to prevent command/argument injection
                [[ ! "$RESTORE_INDEX" =~ ^[0-9]+$ ]] && { echo "Error: --restore-index requires a non-negative integer" >&2; exit 1; }
                ;;
            --restore-time)
                RESTORE_TIME="$2"; shift
                # Security: Validate timestamp format to prevent command injection/malicious patterns
                [[ ! "$RESTORE_TIME" =~ ^[0-9]{8}_[0-9]{6}$ ]] && { echo "Error: --restore-time requires YYYYMMDD_HHMMSS format" >&2; exit 1; }
                ;;
            --restore-type)
                RESTORE_TYPE="$2"; shift
                # Security: Strict validation of type values to prevent argument injection
                [[ ! "$RESTORE_TYPE" =~ ^[eEjJ]$ ]] && { echo "Error: --restore-type requires 'e' or 'j'" >&2; exit 1; }
                ;;
            --dest)
                RESTORE_DEST="$2"; shift
                [[ "$RESTORE_DEST" =~ ^- ]] && { echo "Error: --dest cannot start with a hyphen" >&2; exit 1; }
                ;;
            --files)
                RESTORE_FILES="$2"; shift
                [[ "$RESTORE_FILES" =~ ^- ]] && { echo "Error: --files cannot start with a hyphen" >&2; exit 1; }
                ;;
            --history) ACTION_HISTORY=true ;;
            --limit)
                HISTORY_LIMIT="$2"; shift
                [[ ! "$HISTORY_LIMIT" =~ ^[0-9]+$ ]] && { echo "Error: --limit requires a positive integer" >&2; exit 1; }
                ;;
            --reindex) ACTION_REINDEX=true ;;
            --from) 
                HISTORY_FROM="$2"; shift 
                [[ ! "$HISTORY_FROM" =~ ^[0-9]{8}_[0-9]{6}$ ]] && { echo "Error: --from requires YYYYMMDD_HHMMSS format" >&2; exit 1; }
                ;;
            --to) 
                HISTORY_TO="$2"; shift 
                [[ ! "$HISTORY_TO" =~ ^[0-9]{8}_[0-9]{6}$ ]] && { echo "Error: --to requires YYYYMMDD_HHMMSS format" >&2; exit 1; }
                ;;
            --list) ACTION_LIST=true ;;
            --status) ACTION_STATUS=true ;;
            --cleanup) ACTION_CLEANUP=true ;;
            --keep-full)
                KEEP_FULL="$2"; shift
                # Security: Validate input to prevent shell arithmetic injection / arbitrary command execution
                [[ ! "$KEEP_FULL" =~ ^[0-9]+$ ]] && { echo "Error: --keep-full requires a non-negative integer" >&2; exit 1; }
                ;;
            --keep-days)
                KEEP_DAYS="$2"; shift
                # Security: Validate input to prevent shell arithmetic injection / arbitrary command execution
                [[ ! "$KEEP_DAYS" =~ ^[0-9]+$ ]] && { echo "Error: --keep-days requires a non-negative integer" >&2; exit 1; }
                ;;
            --local) FORCE_LOCAL=true ;;
            --git-root) FORCE_GIT_ROOT=true ;;
            *) echo "Error: Unknown parameter: $1" >&2; exit 1 ;;
        esac
        shift
    done
}

get_git_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" ]]; then echo "$dir"; return 0; fi
        dir="$(dirname "$dir")"
    done
    return 1
}

resolve_target_directory() {
    if [[ "$FORCE_LOCAL" == true ]]; then return 0; fi
    local git_root
    if ! git_root=$(get_git_root); then return 0; fi
    if [[ "$git_root" == "$TARGET_DIR" && "$FORCE_GIT_ROOT" == false ]]; then return 0; fi

    local config_path="$git_root/$CONFIG_FILE_NAME"
    local use_root=""
    if [[ "$FORCE_GIT_ROOT" == true ]]; then use_root="root"
    elif [[ -f "$config_path" ]]; then use_root=$(cat "$config_path"); fi

    if [[ -z "$use_root" ]]; then
        log "Detected Git project root at: $git_root"
        if [[ -t 0 && "$QUIET_MODE" == false ]]; then
            read -r -p "Operate on [S]ubdir or [T]op level of Git project? (s/t): " choice
            [[ "$choice" =~ ^[Tt]$ ]] && use_root="root" || use_root="subdir"
            echo "$use_root" > "$config_path"
        else
            log "Defaulting to subdirectory operation."
            use_root="subdir"
        fi
    fi
    [[ "$use_root" == "root" ]] && TARGET_DIR="$git_root"
    return 0
}

get_zip_excludes() {
    local excludes=("$BACKUP_DIR_NAME/*" "$CONFIG_FILE_NAME" ".git/*" "*/.git/*")
    
    # Gold Standard: Use git if available for 100% accuracy
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        # Use git status to find all ignored files and directories
        # git status --ignored --porcelain=v1 prefix is '!! ' (3 chars) for ignored items
        while IFS= read -r line; do
            if [[ "$line" =~ ^"!!" ]]; then
                local path="${line:3}"
                [[ -z "$path" ]] && continue
                # Remove quotes if git added them (happens for special chars)
                path="${path#\"}"
                path="${path%\"}"
                if [[ "$path" == */ ]]; then
                    excludes+=("${path}*")
                else
                    excludes+=("$path" "${path}/*")
                fi
            fi
        done < <(git status --ignored --porcelain=v1)
    else
        # Fallback: Manual parsing of all discoverable .gitignore files
        # ONLY if we are not in a git repo (where git status is superior)
        while IFS= read -r -d '' ignore_file; do
            local rel_dir=$(dirname "${ignore_file#./}")
            [[ "$rel_dir" == "." ]] && rel_dir=""
            while IFS= read -r line || [[ -n "$line" ]]; do
                line="${line%$'\r'}"
                # Skip comments and empty lines
                [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]] && continue
                
                # Basic support for negation: we can't easily "un-exclude" in zip -x,
                # so we just skip negation lines in the manual parser.
                # (The git-based logic above handles negation perfectly).
                [[ "$line" =~ ^! ]] && continue 
                
                # Handle escaped characters (very basic support for \# and \!)
                line="${line//\\#/ #}"
                line="${line//\\!/!}"
                
                local pattern="${line%/}"
                
                # Standardize double-star to single-star for zip compatibility
                pattern="${pattern//\*\*\//}"
                pattern="${pattern//\/\*\*/}"
                
                local is_anchored=false
                [[ "$line" == */ ]] && is_anchored=true
                [[ "$pattern" == /* ]] && { is_anchored=true; pattern="${pattern#/}"; }
                [[ "$pattern" == */* ]] && is_anchored=true
                
                add_variants() {
                    local p="$1"
                    excludes+=("$p" "$p/*")
                }

                if [[ -n "$rel_dir" ]]; then
                    if [[ "$is_anchored" == true ]]; then
                        add_variants "${rel_dir}/${pattern}"
                    else
                        add_variants "${rel_dir}/${pattern}"
                        add_variants "${rel_dir}/*/${pattern}"
                    fi
                else
                    if [[ "$is_anchored" == true ]]; then
                        add_variants "${pattern}"
                    else
                        add_variants "${pattern}"
                        add_variants "*/${pattern}"
                    fi
                fi
            done < "$ignore_file"
        done < <(find . -name ".gitignore" -print0)
    fi
    for ex in "${excludes[@]}"; do printf "%s\n" "$ex"; done | sort -u
}

get_latest_backup() {
    shopt -s nullglob
    local backups=("$BACKUP_DIR_NAME"/datezip_*.zip)
    shopt -u nullglob
    [[ ${#backups[@]} -eq 0 ]] && return 1
    printf "%s\n" "${backups[@]}" | sort | tail -n 1
}

update_history_cache() {
    [[ ! -d "$BACKUP_DIR_NAME" ]] && return 0
    shopt -s nullglob
    local backups=("$BACKUP_DIR_NAME"/datezip_*.zip)
    shopt -u nullglob
    [[ ${#backups[@]} -eq 0 ]] && return 0

    if [[ ! -f "$HISTORY_CACHE_FILE" ]]; then
        execute_reindex
        return 0
    fi

    local actual_ts_list=$(printf "%s\n" "${backups[@]}" | awk -F'_' '{print $2"_"$3}' | awk -F'.' '{print $1}' | sort -u)
    local cached_ts_list=$(awk -F'|' '{print $1}' "$HISTORY_CACHE_FILE" | sort -u)

    if [[ -z "$cached_ts_list" ]]; then
        execute_reindex
        return 0
    fi

    local missing_from_disk=$(comm -13 <(echo "$actual_ts_list") <(echo "$cached_ts_list") | sed '/^$/d')
    if [[ -n "$missing_from_disk" ]]; then
        log "Notice: Orphaned history detected (archives were deleted). Reindexing..."
        execute_reindex
        return 0
    fi

    local missing_from_cache=$(comm -23 <(echo "$actual_ts_list") <(echo "$cached_ts_list") | sed '/^$/d')
    if [[ -n "$missing_from_cache" ]]; then
        local latest_cached=$(echo "$cached_ts_list" | tail -n 1)
        local oldest_new=$(echo "$missing_from_cache" | head -n 1)

        if [[ "$oldest_new" < "$latest_cached" ]]; then
            log "Notice: Out-of-order archives detected. Reindexing..."
            execute_reindex
            return 0
        fi

        local new_zips=()
        for ts in $missing_from_cache; do
            local zip_match=("$BACKUP_DIR_NAME"/datezip_${ts}_*.zip)
            [[ -f "${zip_match[0]}" ]] && new_zips+=("${zip_match[0]}")
        done

        if [[ ${#new_zips[@]} -gt 0 ]]; then
            log "Updating history cache with ${#new_zips[@]} new backup(s)..."
            for zip in "${new_zips[@]}"; do
                local ts=$(basename "$zip" | cut -d'_' -f2,3)
                echo "${ts}|*|00000000.000000|__MARKER__"
                unzip -Z -T "$zip" 2>/dev/null | awk -v zts="$ts" '
                match($0, /[0-9]{8}\.[0-9]{6}/) {
                    mtime = substr($0, RSTART, RLENGTH)
                    rest = substr($0, RSTART + RLENGTH)
                    sub(/^ +/, "", rest)
                    if (rest ~ /\/$/) next
                    printf "%s||%s|%s\n", zts, mtime, rest
                }'
            done | awk -F'|' -v OFS='|' -v cache="$HISTORY_CACHE_FILE" '
            BEGIN {
                while ((getline < cache) > 0) {
                    if ($2 == "*") continue
                    seen[$4] = $3
                }
                close(cache)
            }
            {
                if ($2 == "*") {
                    print $0 >> cache
                    next
                }
                zts = $1; mtime = $3; file = $4
                if (!(file in seen)) {
                    print zts, "+", mtime, file >> cache
                    seen[file] = mtime
                } else if (seen[file] != mtime) {
                    print zts, ".", mtime, file >> cache
                    seen[file] = mtime
                }
            }'
        fi
    fi
}

execute_reindex() {
    log "Rebuilding history cache..."
    mkdir -p "$BACKUP_DIR_NAME"
    rm -f "$HISTORY_CACHE_FILE"
    touch "$HISTORY_CACHE_FILE"
    
    shopt -s nullglob
    local backups=("$BACKUP_DIR_NAME"/datezip_*.zip)
    shopt -u nullglob
    [[ ${#backups[@]} -eq 0 ]] && return 0
    
    local sorted=()
    while IFS= read -r line; do sorted+=("$line"); done < <(printf "%s\n" "${backups[@]}" | sort)
    
    for zip in "${sorted[@]}"; do
        local ts=$(basename "$zip" | cut -d'_' -f2,3)
        echo "${ts}|*|00000000.000000|__MARKER__"
        unzip -Z -T "$zip" 2>/dev/null | awk -v zts="$ts" '
        match($0, /[0-9]{8}\.[0-9]{6}/) {
            mtime = substr($0, RSTART, RLENGTH)
            rest = substr($0, RSTART + RLENGTH)
            sub(/^ +/, "", rest)
            if (rest ~ /\/$/) next
            printf "%s||%s|%s\n", zts, mtime, rest
        }'
    done | awk -F'|' -v OFS='|' '
    {
        if ($2 == "*") {
            print $0
            next
        }
        zts = $1; mtime = $3; file = $4
        if (!(file in seen)) {
            print zts, "+", mtime, file
            seen[file] = mtime
        } else if (seen[file] != mtime) {
            print zts, ".", mtime, file
            seen[file] = mtime
        }
    }' > "$HISTORY_CACHE_FILE"
    
    log "History cache rebuilt."
}

execute_history() {
    update_history_cache
    [[ ! -s "$HISTORY_CACHE_FILE" ]] && { echo "No history available."; return 0; }
    
    # Pre-extract FULL backup timestamps safely (handling path names with underscores)
    local full_zips=""
    shopt -s nullglob
    local full_files=("$BACKUP_DIR_NAME"/datezip_*_FULL.zip)
    shopt -u nullglob
    for f in "${full_files[@]}"; do
        local fn=$(basename "$f")
        local ts="${fn#datezip_}"
        ts="${ts%_FULL.zip}"
        full_zips+="$ts "
    done

    # Performance optimization: Pipe sort -r directly into awk to process filtering,
    # group headers, and formatting in a single pass without Bash while-read loops or temporary files.
    sort -r -t'|' -k1,1 "$HISTORY_CACHE_FILE" | awk -F'|' -v h_from="$HISTORY_FROM" -v h_to="$HISTORY_TO" \
        -v h_limit="$HISTORY_LIMIT" -v r_files="$RESTORE_FILES" -v full_ts_list="$full_zips" '
    BEGIN {
        split(full_ts_list, farr, /[ \n\t]+/)
        for (i in farr) if (farr[i] != "") full_ts[farr[i]] = 1

        if (r_files != "") {
            has_targets = 1
        }
    }
    {
        if ($2 == "*") next
        if (h_from != "" && $1 < h_from) next
        if (h_to != "" && $1 > h_to) next

        count++
        ts_arr[count] = $1
        status_arr[count] = $2
        mtime_arr[count] = $3
        file_arr[count] = $4

        if (h_limit != "" && count >= h_limit) {
            exit
        }
    }
    END {
        if (count == 0) {
            print "No history found for the specified criteria."
        } else {
            if (has_targets) {
                n = split(r_files, targets_ord, ",")
                for (ti = 1; ti <= n; ti++) {
                    t = targets_ord[ti]
                    print "---- " t " ------"
                    for (i = 1; i <= count; i++) {
                        if (file_arr[i] == t) {
                            print ts_arr[i] "  " status_arr[i] "  " file_arr[i]
                        }
                    }
                    print ""
                }
            } else {
                current_ts = ""
                for (i = 1; i <= count; i++) {
                    ts = ts_arr[i]
                    if (ts != current_ts) {
                        if (current_ts != "") print ""
                        b_type = (ts in full_ts) ? "FULL" : "INC"
                        print "---- " ts " (" b_type ") --------"
                        current_ts = ts
                    }
                    print ts "  " status_arr[i] "  " file_arr[i]
                }
                print ""
            }
            print "To restore: datezip --restore-time <Timestamp> --files <Filename>"
        }
    }
    '
}

execute_status() {
    update_history_cache
    [[ ! -s "$HISTORY_CACHE_FILE" ]] && { echo "No history available. Run a backup first."; return 0; }
    
    # Delta from Baseline Model: Find the latest FULL backup timestamp
    # We grep for _FULL.zip in the backup directory and extract the timestamp
    local latest_full_ts=$(ls "$BACKUP_DIR_NAME"/datezip_*_FULL.zip 2>/dev/null | tail -n 1 | cut -d'_' -f2,3 | cut -d'.' -f1)
    
    if [[ -z "$latest_full_ts" ]]; then
        # Fallback to the very first entry if no FULL found (shouldn't happen)
        latest_full_ts=$(head -n 1 "$HISTORY_CACHE_FILE" | cut -d'|' -f1)
    fi
    
    log "Comparing against latest FULL backup: $latest_full_ts"
    
    local tmp_latest=$(mktemp 2>/dev/null || mktemp -t 'datezip')
    # Reconstruct state exactly as it was at that FULL backup by scanning history
    awk -F'|' -v target="$latest_full_ts" '
    $1 <= target {
        if ($2 == "*") next
        state[$4] = $2
        mtime[$4] = $3
    }
    END {
        for (f in state) {
            if (state[f] != "-") print f "|" mtime[f]
        }
    }' "$HISTORY_CACHE_FILE" | sort > "$tmp_latest"
    
    local tmp_disk=$(mktemp 2>/dev/null || mktemp -t 'datezip')
    
    # Gold Standard: Use git if available for 100% accuracy on what should be tracked
    if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git ls-files --cached --others --exclude-standard | sort > "$tmp_disk"
    else
        # Fallback: Use find and filter out standard excludes
        find . -type f \
            -not -path "*/.git/*" \
            -not -path "./$BACKUP_DIR_NAME/*" \
            | sed 's|^\./||' | sort > "$tmp_disk"
    fi
    
    echo "Changes since FULL backup ($latest_full_ts):"
    
    # Deleted: In FULL backup but not on disk
    local deleted=$(comm -23 <(cut -d'|' -f1 "$tmp_latest") "$tmp_disk")
    if [[ -n "$deleted" ]]; then
        echo "Deleted:"
        sed 's/^/  - /' <<< "$deleted"
    fi
    
    # Untracked: On disk but not in FULL backup
    local untracked=$(comm -13 <(cut -d'|' -f1 "$tmp_latest") "$tmp_disk")
    if [[ -n "$untracked" ]]; then
        echo "Untracked:"
        sed 's/^/  ? /' <<< "$untracked"
    fi
    
    # Modified: In both, check mtime.
    # Batch file metadata queries via xargs stat into tmp_stat, then compare
    # against cached mtimes using an O(N) awk in-memory hash table.
    local common=$(comm -12 <(cut -d'|' -f1 "$tmp_latest") "$tmp_disk")
    if [[ -n "$common" ]]; then
        local is_gnu=false
        if stat -c "%y" . >/dev/null 2>&1; then
            is_gnu=true
        fi

        local tmp_stat=$(mktemp 2>/dev/null || mktemp -t 'datezip')

        # Security: Terminate option flags with `--` to protect against argument injection.
        # Use %n for raw filename across both GNU and BSD stat.
        if [[ "$is_gnu" == true ]]; then
            tr '\n' '\0' <<< "$common" | xargs -0 stat -c "%y|%n" -- > "$tmp_stat" 2>/dev/null || true
        else
            tr '\n' '\0' <<< "$common" | xargs -0 stat -f "%Sm|%n" -t "%Y%m%d.%H%M%S" -- > "$tmp_stat" 2>/dev/null || true
        fi

        # Compare timestamps using awk safely (avoiding BSD-awk strftime runtime limitations).
        # Symmetrically strip leading `./` from filenames to ensure exact matching consistency.
        local modified_files=$(awk -F'|' -v is_gnu="$is_gnu" '
        FILENAME == ARGV[1] {
            f_clean = $1
            sub(/^\.\//, "", f_clean)
            cached_mtimes[f_clean] = $2
            next
        }
        {
            idx = index($0, "|")
            if (idx == 0) next
            raw_mtime = substr($0, 1, idx - 1)
            fname = substr($0, idx + 1)

            if (is_gnu == "true") {
                # Format "YYYY-MM-DD HH:MM:SS.NNNNNNNNN +ZZZZ" to "YYYYMMDD.HHMMSS"
                dt = substr(raw_mtime, 1, 10)
                gsub("-", "", dt)
                tm = substr(raw_mtime, 12, 8)
                gsub(":", "", tm)
                mtime = dt "." tm
            } else {
                mtime = raw_mtime
            }

            f_clean = fname
            sub(/^\.\//, "", f_clean)

            if (f_clean in cached_mtimes) {
                if (cached_mtimes[f_clean] != mtime) {
                    print fname
                }
            }
        }' "$tmp_latest" "$tmp_stat")

        if [[ -n "$modified_files" ]]; then
            echo "Modified:"
            sed 's/^/  . /' <<< "$modified_files"
        fi

        rm -f "$tmp_stat"
    fi
    
    rm -f "$tmp_latest" "$tmp_disk"
}

execute_backup() {
    mkdir -p "$BACKUP_DIR_NAME"
    local last_backup=""
    local b_type="FULL"
    local today=$(date +"%Y%m%d")
    if last_backup=$(get_latest_backup); then
        local ts_part=$(basename "$last_backup" | cut -d'_' -f2)
        [[ "$ts_part" == "$today" ]] && b_type="INC"
    fi
    [[ -n "$FORCE_TYPE" ]] && b_type="$FORCE_TYPE"
    local filename="datezip_$(date +"$DATE_FORMAT")_${b_type}.zip"
    local dest_path="$BACKUP_DIR_NAME/$filename"
    log "Starting $b_type backup to $filename..."
    local exclude_file=$(mktemp 2>/dev/null || mktemp -t 'datezip')
    get_zip_excludes > "$exclude_file"
    local status=0
    
    if [[ "$b_type" == "INC" && -n "$last_backup" ]]; then
        if [[ -z $(find . -type f -newer "$last_backup" -print 2>/dev/null | head -n 1) ]]; then
            log "No changes detected."
            rm -f "$exclude_file"
            return 0
        fi
        find . -type f -newer "$last_backup" -exec zip "$dest_path" -q -x@"${exclude_file}" {} +
        status=$?
    else
        zip -r "$dest_path" . -x@"${exclude_file}" -q
        status=$?
    fi
    rm -f "$exclude_file"
    
    if [[ $status -eq 0 || $status -eq 12 ]]; then
        log "Backup complete: $filename"
    else
        echo "Error: Backup failed." >&2
        rm -f "$dest_path"
        exit 1
    fi
}

execute_list() {
    [[ ! -d "$BACKUP_DIR_NAME" ]] && { echo "No backups found."; return 0; }
    shopt -s nullglob
    local backups=("$BACKUP_DIR_NAME"/datezip_*.zip)
    shopt -u nullglob
    [[ ${#backups[@]} -eq 0 ]] && { echo "No backups found."; return 0; }
    local sorted=()
    while IFS= read -r line; do sorted+=("$line"); done < <(printf "%s\n" "${backups[@]}" | sort)
    echo "Available backups:"
    for i in "${!sorted[@]}"; do echo "[$i] $(basename "${sorted[$i]}")"; done
}

execute_restore() {
    [[ ! -d "$BACKUP_DIR_NAME" ]] && { echo "Error: No backups found." >&2; exit 1; }
    shopt -s nullglob
    local backups=("$BACKUP_DIR_NAME"/datezip_*.zip)
    shopt -u nullglob
    [[ ${#backups[@]} -eq 0 ]] && { echo "Error: No backups found." >&2; exit 1; }
    local sorted=()
    while IFS= read -r line; do sorted+=("$line"); done < <(printf "%s\n" "${backups[@]}" | sort)
    
    local choice="$RESTORE_INDEX"
    if [[ -n "$RESTORE_TIME" ]]; then
        for ((i=${#sorted[@]}-1; i>=0; i--)); do
            local b_ts=$(basename "${sorted[$i]}" | cut -d'_' -f2,3)
            if [[ "$b_ts" < "$RESTORE_TIME" || "$b_ts" == "$RESTORE_TIME" ]]; then choice=$i; break; fi
        done
        [[ -z "$choice" ]] && { echo "Error: No backup before $RESTORE_TIME" >&2; exit 1; }
        RESTORE_TYPE=${RESTORE_TYPE:-e}
    elif [[ -z "$choice" ]]; then
        [[ "$QUIET_MODE" == true ]] && { echo "Error: --quiet requires --restore-index or --restore-time." >&2; exit 1; }
        execute_list && read -r -p "Select index: " choice
    fi
    
    [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ -z "${sorted[$choice]}" ]] && { echo "Error: Invalid selection." >&2; exit 1; }
    
    local selected="${sorted[$choice]}"
    local target_files=()
    [[ -n "$RESTORE_FILES" ]] && IFS=',' read -ra target_files <<< "$RESTORE_FILES"
    
    local mode="$RESTORE_TYPE"
    if [[ "$selected" == *"_INC.zip" && -z "$mode" ]]; then
        [[ "$QUIET_MODE" == true ]] && { echo "Error: --restore-type required for quiet incremental restore." >&2; exit 1; }
        read -r -p "Restore [E]verything or [J]ust increment? (e/j): " mode
    fi
    
    mkdir -p -- "$RESTORE_DEST"
    log "Restoring to $RESTORE_DEST..."
    if [[ "$mode" =~ ^[Ee]$ ]]; then
        local start_idx=0
        for ((i=choice; i>=0; i--)); do [[ "${sorted[$i]}" == *"_FULL.zip" ]] && { start_idx=$i; break; }; done
        for ((i=start_idx; i<=choice; i++)); do
            log "Extracting $(basename "${sorted[$i]}")"
            local cmd=("unzip" "-o" "-q" "${sorted[$i]}")
            [[ ${#target_files[@]} -gt 0 ]] && cmd+=("${target_files[@]}")
            cmd+=("-d" "$RESTORE_DEST")
            if [[ ${#target_files[@]} -gt 0 ]]; then
                "${cmd[@]}" >/dev/null 2>&1 || true
            else
                "${cmd[@]}" || true
            fi
        done
    else
        local cmd=("unzip" "-o" "-q" "$selected")
        [[ ${#target_files[@]} -gt 0 ]] && cmd+=("${target_files[@]}")
        cmd+=("-d" "$RESTORE_DEST")
        if [[ ${#target_files[@]} -gt 0 ]]; then
            "${cmd[@]}" >/dev/null 2>&1 || true
        else
            "${cmd[@]}" || true
        fi
    fi
    log "Restore complete."
}

execute_cleanup() {
    [[ ! -d "$BACKUP_DIR_NAME" ]] && return 0
    log "Cleaning up..."
    shopt -s nullglob
    local fulls=("$BACKUP_DIR_NAME"/datezip_*_FULL.zip)
    local incs=("$BACKUP_DIR_NAME"/datezip_*_INC.zip)
    shopt -u nullglob
    local s_full=()
    while IFS= read -r line; do s_full+=("$line"); done < <(printf "%s\n" "${fulls[@]}" | sort)
    local num_f=${#s_full[@]}
    if [[ $num_f -gt 0 ]]; then
        local latest="${s_full[$((num_f - 1))]}"
        for inc in "${incs[@]}"; do 
            if [[ "$inc" < "$latest" ]]; then 
                log "Deleting: $(basename "$inc")"
                rm -f -- "$inc"
            fi
        done
    fi
    local cutoff=$(( num_f - KEEP_FULL ))
    local cutoff_date=$(date -v-"${KEEP_DAYS}"d +"%Y%m%d_%H%M%S" 2>/dev/null || date -d "-${KEEP_DAYS} days" +"%Y%m%d_%H%M%S" 2>/dev/null)
    if [[ $cutoff -gt 0 ]]; then
        for (( i=0; i<cutoff; i++ )); do
            local f="${s_full[$i]}"
            local f_ts
            f_ts=$(basename "$f" | cut -d'_' -f2,3)
            # Prune ONLY if it's outside the KEEP_FULL window AND outside the KEEP_DAYS window
            # This implements the "whichever rule yields the larger retention set" logic.
            if [[ -n $(find "$f" -mtime +"$KEEP_DAYS" 2>/dev/null) ]] && [[ -z "$cutoff_date" || "$f_ts" < "$cutoff_date" ]]; then
                log "Deleting: $(basename "$f")"
                rm -f "$f"
            fi
        done
    fi
}

main() {
    check_dependencies && parse_args "$@" && resolve_target_directory
    cd "$TARGET_DIR" || exit 1
    if [[ "$ACTION_REINDEX" == true ]]; then execute_reindex
    elif [[ "$ACTION_HISTORY" == true ]]; then execute_history
    elif [[ "$ACTION_LIST" == true ]]; then execute_list
    elif [[ "$ACTION_STATUS" == true ]]; then execute_status
    elif [[ -n "$RESTORE_INDEX" || -n "$RESTORE_TIME" || "$RESTORE_MODE" == true ]]; then execute_restore
    else
        local run_b=true
        [[ "$ACTION_CLEANUP" == true && "$EXPLICIT_BACKUP" == false && -z "$FORCE_TYPE" ]] && run_b=false
        [[ "$run_b" == true ]] && execute_backup
        [[ "$ACTION_CLEANUP" == true ]] && execute_cleanup
    fi
    return 0
}
main "$@"
