#!/bin/bash

# --- Constants ---
readonly BACKUP_DIR_NAME="backups"
readonly CONFIG_FILE_NAME=".datezip"
readonly DATE_FORMAT="%Y%m%d_%H%M%S"

# --- Global Variables (Set by Argument Parsing) ---
FORCE_TYPE=""
RESTORE_MODE=false
ACTION_CLEANUP=false
EXPLICIT_BACKUP=false
FORCE_GIT_ROOT=false
FORCE_LOCAL=false
TARGET_DIR="$PWD"

KEEP_FULL=10
KEEP_DAYS=14

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

A utility for recursive directory backups with .gitignore support, incremental logic, and retention management.

Options:
  -h, --help      Show this help message and exit
  --backup        Explicitly trigger a backup (default behavior)
  --full          Force a full backup (bypasses daily incremental logic)
  --inc           Force an incremental backup (only files changed since last backup)
  --restore       Enter interactive restore mode
  --cleanup       Remove obsolete incremental backups and prune old full backups
  --keep-full N   Number of full backups to keep during cleanup (default: 10)
  --keep-days N   Number of days to retain full backups during cleanup (default: 14)
  --local         Force operation on the current directory, ignoring Git root detection
  --git-root      Force operation on the Git project root (if within a git repo)

Behavior:
  - Default: The first backup of each day is FULL; subsequent backups are INC.
  - Storage: Backups are stored in a './$BACKUP_DIR_NAME' directory.
  - Filtering: 
    - Recursively discovers and respects all .gitignore files found in the tree.
    - Automatically excludes the backups directory, .git folders, and the config file.
  - Cleanup: Deletes INC backups situated between FULL backups. Retains FULL backups 
    if they are within the last N days OR among the N most recent FULL backups (whichever is greater).
  - Restore: Supports single-file restoration or full chain reconstruction for increments.
EOF
}

parse_args() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -h|--help) show_help; exit 0 ;;
            --backup) EXPLICIT_BACKUP=true ;;
            --full) FORCE_TYPE="FULL" ;;
            --inc) FORCE_TYPE="INC" ;;
            --restore) RESTORE_MODE=true ;;
            --cleanup) ACTION_CLEANUP=true ;;
            --keep-full)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    KEEP_FULL="$2"
                    shift
                else
                    echo "Error: --keep-full requires a numeric argument." >&2
                    exit 1
                fi
                ;;
            --keep-days)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    KEEP_DAYS="$2"
                    shift
                else
                    echo "Error: --keep-days requires a numeric argument." >&2
                    exit 1
                fi
                ;;
            --local) FORCE_LOCAL=true ;;
            --git-root) FORCE_GIT_ROOT=true ;;
            *) echo "Error: Unknown parameter: $1" >&2; show_help; exit 1 ;;
        esac
        shift
    done
}

get_git_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

resolve_target_directory() {
    if [[ "$FORCE_LOCAL" == true ]]; then
        return 0
    fi

    local git_root
    if ! git_root=$(get_git_root); then
        return 0
    fi

    if [[ "$git_root" == "$TARGET_DIR" && "$FORCE_GIT_ROOT" == false ]]; then
        return 0
    fi

    local config_path="$git_root/$CONFIG_FILE_NAME"
    local use_root=""

    if [[ "$FORCE_GIT_ROOT" == true ]]; then
        use_root="root"
    elif [[ -f "$config_path" ]]; then
        use_root=$(cat "$config_path")
    fi

    if [[ -z "$use_root" ]]; then
        echo "Detected Git project root at: $git_root"
        read -r -p "Operate on [S]ubdir or [T]op level of Git project? (s/t): " choice
        if [[ "$choice" =~ ^[Tt]$ ]]; then
            use_root="root"
        else
            use_root="subdir"
        fi
        echo "$use_root" > "$config_path"
    fi

    if [[ "$use_root" == "root" ]]; then
        TARGET_DIR="$git_root"
    fi
}

get_zip_excludes() {
    local excludes=("$BACKUP_DIR_NAME/*" "$CONFIG_FILE_NAME" ".git/*" "*/.git/*")

    while IFS= read -r -d '' ignore_file; do
        local rel_dir
        rel_dir=$(dirname "${ignore_file#./}")
        [[ "$rel_dir" == "." ]] && rel_dir=""

        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ "$line" =~ ^#.*$ ]] && continue
            [[ -z "$line" ]] && continue
            
            local pattern="${line%/}"
            
            if [[ -n "$rel_dir" ]]; then
                if [[ "$pattern" == /* ]]; then
                    excludes+=("${rel_dir}${pattern}")
                else
                    excludes+=("${rel_dir}/${pattern}" "${rel_dir}/**/${pattern}")
                fi
            else
                if [[ "$pattern" == /* ]]; then
                    excludes+=("${pattern#/}")
                else
                    excludes+=("$pattern" "**/$pattern")
                fi
            fi
        done < "$ignore_file"
    done < <(find . -name ".gitignore" -print0)

    for ex in "${excludes[@]}"; do
        echo "$ex"
    done | sort -u
}

get_latest_backup() {
    shopt -s nullglob
    local backups=("$BACKUP_DIR_NAME"/datezip_*.zip)
    shopt -u nullglob

    if [[ ${#backups[@]} -eq 0 ]]; then
        return 1
    fi

    printf "%s\n" "${backups[@]}" | sort | tail -n 1
}

execute_backup() {
    mkdir -p "$BACKUP_DIR_NAME"

    local last_backup=""
    local b_type="FULL"
    local today
    today=$(date +"%Y%m%d")

    if last_backup=$(get_latest_backup); then
        local ts_part
        ts_part=$(basename "$last_backup" | cut -d'_' -f2)
        
        if [[ "$ts_part" == "$today" ]]; then
            b_type="INC"
        fi
    fi

    [[ -n "$FORCE_TYPE" ]] && b_type="$FORCE_TYPE"

    local filename="datezip_$(date +"$DATE_FORMAT")_${b_type}.zip"
    local dest_path="$BACKUP_DIR_NAME/$filename"

    echo "Starting $b_type backup to $filename..."

    local exclude_file
    exclude_file=$(mktemp)
    get_zip_excludes > "$exclude_file"

    local status=0

    if [[ "$b_type" == "INC" && -n "$last_backup" ]]; then
        local manifest_file
        manifest_file=$(mktemp)
        
        find . -type f -newer "$last_backup" > "$manifest_file"
        
        if [[ ! -s "$manifest_file" ]]; then
            echo "No changes detected since last backup."
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
        if [[ -f "$dest_path" ]]; then
            echo "Backup complete: $filename"
        else
            echo "No files were eligible for backup."
        fi
    else
        echo "Error: Backup failed with status $status."
        rm -f "$dest_path"
        exit 1
    fi
}

execute_cleanup() {
    if [[ ! -d "$BACKUP_DIR_NAME" ]]; then
        echo "No backups directory found to clean up."
        return 0
    fi

    echo "Starting cleanup process..."
    shopt -s nullglob
    local full_backups=("$BACKUP_DIR_NAME"/datezip_*_FULL.zip)
    local inc_backups=("$BACKUP_DIR_NAME"/datezip_*_INC.zip)
    shopt -u nullglob

    if [[ ${#full_backups[@]} -gt 0 ]]; then
        mapfile -t full_backups < <(printf "%s\n" "${full_backups[@]}" | sort)
    fi
    if [[ ${#inc_backups[@]} -gt 0 ]]; then
        mapfile -t inc_backups < <(printf "%s\n" "${inc_backups[@]}" | sort)
    fi

    local latest_full=""
    if [[ ${#full_backups[@]} -gt 0 ]]; then
        latest_full="${full_backups[-1]}"
    fi

    # 1. Delete intermediate increments (older than the latest FULL backup)
    if [[ -n "$latest_full" ]]; then
        for inc in "${inc_backups[@]}"; do
            if [[ "$inc" < "$latest_full" ]]; then
                echo "Deleting obsolete incremental backup: $(basename "$inc")"
                rm -f "$inc"
            fi
        done
    fi

    # 2. Prune old FULL backups ensuring KEEP_FULL and KEEP_DAYS constraints
    local num_full=${#full_backups[@]}
    local cutoff_idx=$(( num_full - KEEP_FULL ))

    if [[ $cutoff_idx -gt 0 ]]; then
        for (( i=0; i<cutoff_idx; i++ )); do
            local f="${full_backups[$i]}"
            
            # Use find to cleanly determine if the file's modified time exceeds KEEP_DAYS
            local is_older
            is_older=$(find "$f" -mtime +"$KEEP_DAYS" 2>/dev/null)
            
            if [[ -n "$is_older" ]]; then
                echo "Deleting old full backup: $(basename "$f")"
                rm -f "$f"
            else
                echo "Retaining historical full backup (within $KEEP_DAYS days): $(basename "$f")"
            fi
        done
    fi
    echo "Cleanup complete."
}

execute_restore() {
    if [[ ! -d "$BACKUP_DIR_NAME" ]]; then
        echo "Error: No backups directory found."
        exit 1
    fi

    shopt -s nullglob
    local backups=("$BACKUP_DIR_NAME"/datezip_*.zip)
    shopt -u nullglob

    if [[ ${#backups[@]} -eq 0 ]]; then
        echo "Error: No backup files found."
        exit 1
    fi

    mapfile -t backups < <(printf "%s\n" "${backups[@]}" | sort)

    echo -e "\nAvailable backups:"
    for i in "${!backups[@]}"; do
        echo "[$i] $(basename "${backups[$i]}")"
    done

    local choice
    read -r -p "Select backup index to restore: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ -z "${backups[$choice]}" ]]; then
        echo "Error: Invalid selection."
        exit 1
    fi

    local selected_zip="${backups[$choice]}"

    if [[ "$selected_zip" == *"_INC.zip" ]]; then
        local mode
        read -r -p "Incremental backup detected. Restore [E]verything (Full + Chain) or [J]ust this increment? (e/j): " mode
        if [[ "$mode" =~ ^[Ee]$ ]]; then
            local start_idx=0
            for ((i=choice; i>=0; i--)); do
                if [[ "${backups[$i]}" == *"_FULL.zip" ]]; then
                    start_idx=$i
                    break
                fi
            done
            
            echo "Restoring chain starting from $(basename "${backups[$start_idx]}")"
            for ((i=start_idx; i<=choice; i++)); do
                echo "Extracting $(basename "${backups[$i]}")"
                unzip -o -q "${backups[$i]}" -d .
            done
            echo "Chain restore complete."
            return
        fi
    fi

    echo "Extracting $(basename "$selected_zip")..."
    unzip -o -q "$selected_zip" -d .
    echo "Restore complete."
}

main() {
    parse_args "$@"
    resolve_target_directory
    
    cd "$TARGET_DIR" || { echo "Error: Cannot change to directory $TARGET_DIR"; exit 1; }

    if [[ "$RESTORE_MODE" == true ]]; then
        execute_restore
        return
    fi

    local should_backup=true
    if [[ "$ACTION_CLEANUP" == true && "$EXPLICIT_BACKUP" == false && -z "$FORCE_TYPE" ]]; then
        should_backup=false
    fi

    if [[ "$should_backup" == true ]]; then
        execute_backup
    fi

    if [[ "$ACTION_CLEANUP" == true ]]; then
        execute_cleanup
    fi
}

main "$@"
