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
ACTION_LIST=false
ACTION_CLEANUP=false
ACTION_HISTORY=false
ACTION_REINDEX=false
HISTORY_FROM=""
HISTORY_TO=""
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
  --restore-type e|j   Non-interactive: (e)verything or (j)ust increment
  --files LIST         Comma-separated list of files to filter/restore
  --history            Show chronological file history
  --from TS            Filter history start (format: YYYYMMDD_HHMMSS)
  --to TS              Filter history end (format: YYYYMMDD_HHMMSS)
  --reindex            Rebuild the history cache from existing ZIP archives
  --list               List available backups and their indices
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
            --restore-index) RESTORE_INDEX="$2"; shift ;;
            --restore-time) RESTORE_TIME="$2"; shift ;;
            --restore-type) RESTORE_TYPE="$2"; shift ;;
            --files) RESTORE_FILES="$2"; shift ;;
            --history) ACTION_HISTORY=true ;;
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
            --cleanup) ACTION_CLEANUP=true ;;
            --keep-full) KEEP_FULL="$2"; shift ;;
            --keep-days) KEEP_DAYS="$2"; shift ;;
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
}

get_zip_excludes() {
    local excludes=("$BACKUP_DIR_NAME/*" "$CONFIG_FILE_NAME" ".git/*" "*/.git/*")
    while IFS= read -r -d '' ignore_file; do
        local rel_dir=$(dirname "${ignore_file#./}")
        [[ "$rel_dir" == "." ]] && rel_dir=""
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]] && continue
            local pattern="${line%/}"
            if [[ -n "$rel_dir" ]]; then
                [[ "$pattern" == /* ]] && excludes+=("${rel_dir}${pattern}") || excludes+=("${rel_dir}/${pattern}" "${rel_dir}/**/${pattern}")
            else
                [[ "$pattern" == /* ]] && excludes+=("${pattern#/}") || excludes+=("$pattern" "**/$pattern")
            fi
        done < "$ignore_file"
    done < <(find . -name ".gitignore" -print0)
    for ex in "${excludes[@]}"; do echo "$ex"; done | sort -u
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

    # Condition 1: Deletions (cache contains a timestamp not present on disk)
    local missing_from_disk=$(comm -13 <(echo "$actual_ts_list") <(echo "$cached_ts_list") | sed '/^$/d')
    if [[ -n "$missing_from_disk" ]]; then
        log "Notice: Orphaned history detected (archives were deleted). Reindexing..."
        execute_reindex
        return 0
    fi

    # Condition 2: New additions (disk contains a timestamp not present in cache)
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
                
                # Emit a marker line so comm always finds the TS, even if the archive had 0 modifications
                echo "${ts}|*|00000000.000000|__MARKER__"
                
                unzip -Z -T "$zip" 2>/dev/null | awk -v zts="$ts" '
                match($0, /[0-9]{8}\.[0-9]{6}/) {
                    mtime = substr($0, RSTART, RLENGTH)
                    rest = substr($0, RSTART + RLENGTH)
                    sub(/^ +/, "", rest)
                    file = rest
                    if (file ~ /\/$/) next
                    printf "%s|%s|%s\n", zts, mtime, file
                }'
            done | awk -v cache="$HISTORY_CACHE_FILE" '
            BEGIN {
                while ((getline line < cache) > 0) {
                    if (substr(line, 17, 1) == "*") continue
                    file = substr(line, 35)
                    mtime = substr(line, 19, 15)
                    seen[file] = mtime
                }
                close(cache)
            }
            {
                zts = substr($0, 1, 15)
                # Pass through markers directly
                if (substr($0, 17, 1) == "*") {
                    print $0 >> cache
                    next
                }
                
                mtime = substr($0, 17, 15)
                file = substr($0, 33)
                
                if (!(file in seen)) {
                    printf "%s|+|%s|%s\n", zts, mtime, file >> cache
                    seen[file] = mtime
                } else if (seen[file] != mtime) {
                    printf "%s|.|%s|%s\n", zts, mtime, file >> cache
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
            file = rest
            if (file ~ /\/$/) next
            printf "%s|%s|%s\n", zts, mtime, file
        }'
    done | awk '
    {
        zts = substr($0, 1, 15)
        if (substr($0, 17, 1) == "*") {
            print $0
            next
        }
        
        mtime = substr($0, 17, 15)
        file = substr($0, 33)
        
        if (!(file in seen)) {
            printf "%s|+|%s|%s\n", zts, mtime, file
            seen[file] = mtime
        } else if (seen[file] != mtime) {
            printf "%s|.|%s|%s\n", zts, mtime, file
            seen[file] = mtime
        }
    }' > "$HISTORY_CACHE_FILE"
    
    log "History cache rebuilt."
}

execute_history() {
    update_history_cache
    [[ ! -s "$HISTORY_CACHE_FILE" ]] && { echo "No history available."; return 0; }
    
    local tmp_cache=$(mktemp)
    
    # Apply Temporal Windowing & Strip out Markers
    while IFS= read -r line; do
        [[ "${line:16:1}" == "*" ]] && continue
        
        local ts="${line:0:15}"
        [[ -n "$HISTORY_FROM" && "$ts" < "$HISTORY_FROM" ]] && continue
        [[ -n "$HISTORY_TO" && "$ts" > "$HISTORY_TO" ]] && continue
        echo "$line" >> "$tmp_cache"
    done < "$HISTORY_CACHE_FILE"
    
    if [[ ! -s "$tmp_cache" ]]; then
        echo "No history found for the specified criteria."
        rm -f "$tmp_cache"
        return 0
    fi

    local sorted_cache=$(mktemp)
    sort -r -k1,1 "$tmp_cache" > "$sorted_cache"
    rm -f "$tmp_cache"

    if [[ -n "$RESTORE_FILES" ]]; then
        # View Route B: File-Specific History View
        IFS=',' read -ra target_files <<< "$RESTORE_FILES"
        for target in "${target_files[@]}"; do
            echo "---- $target ------"
            while IFS= read -r line; do
                local f_name="${line:34}"
                if [[ "$f_name" == "$target" ]]; then
                    echo "${line:0:15}  ${line:16:1}  ${line:34}"
                fi
            done < "$sorted_cache"
            echo ""
        done
    else
        # View Route A: Detailed Stat View (Default)
        local current_ts=""
        while IFS= read -r line; do
            local ts="${line:0:15}"
            if [[ "$ts" != "$current_ts" ]]; then
                [[ -n "$current_ts" ]] && echo ""
                local b_type="INC"
                if ls "$BACKUP_DIR_NAME"/datezip_${ts}_FULL.zip >/dev/null 2>&1; then
                    b_type="FULL"
                fi
                echo "---- ${ts} (${b_type}) --------"
                current_ts="$ts"
            fi
            echo "${line:0:15}  ${line:16:1}  ${line:34}"
        done < "$sorted_cache"
        echo ""
    fi
    
    echo "To restore: datezip --restore-time <Timestamp> --files <Filename>"
    rm -f "$sorted_cache"
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
    local exclude_file=$(mktemp)
    get_zip_excludes > "$exclude_file"
    local status=0
    
    if [[ "$b_type" == "INC" && -n "$last_backup" ]]; then
        local manifest_file=$(mktemp)
        find . -type f -newer "$last_backup" > "$manifest_file"
        if [[ ! -s "$manifest_file" ]]; then
            log "No changes detected."
            rm -f "$exclude_file" "$manifest_file"
            return
        fi
        zip "$dest_path" -@ -x@"${exclude_file}" -q < "$manifest_file"
        status=$?
        rm -f "$manifest_file"
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
            # Find the exact match, or the closest prior archive
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
    
    log "Restoring..."
    if [[ "$mode" =~ ^[Ee]$ ]]; then
        local start_idx=0
        for ((i=choice; i>=0; i--)); do [[ "${sorted[$i]}" == *"_FULL.zip" ]] && { start_idx=$i; break; }; done
        for ((i=start_idx; i<=choice; i++)); do
            log "Extracting $(basename "${sorted[$i]}")"
            local cmd=("unzip" "-o" "-q" "${sorted[$i]}")
            [[ ${#target_files[@]} -gt 0 ]] && cmd+=("${target_files[@]}")
            cmd+=("-d" ".")
            
            if [[ ${#target_files[@]} -gt 0 ]]; then
                "${cmd[@]}" >/dev/null 2>&1 || true
            else
                "${cmd[@]}" || true
            fi
        done
    else
        local cmd=("unzip" "-o" "-q" "$selected")
        [[ ${#target_files[@]} -gt 0 ]] && cmd+=("${target_files[@]}")
        cmd+=("-d" ".")
        
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
                rm -f "$inc"
            fi
        done
    fi
    
    local cutoff=$(( num_f - KEEP_FULL ))
    if [[ $cutoff -gt 0 ]]; then
        for (( i=0; i<cutoff; i++ )); do
            local f="${s_full[$i]}"
            if [[ -n $(find "$f" -mtime +"$KEEP_DAYS" 2>/dev/null) ]]; then 
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
    elif [[ -n "$RESTORE_INDEX" || -n "$RESTORE_TIME" || "$RESTORE_MODE" == true ]]; then execute_restore
    else
        local run_b=true
        [[ "$ACTION_CLEANUP" == true && "$EXPLICIT_BACKUP" == false && -z "$FORCE_TYPE" ]] && run_b=false
        [[ "$run_b" == true ]] && execute_backup
        [[ "$ACTION_CLEANUP" == true ]] && execute_cleanup
    fi
}

main "$@"
