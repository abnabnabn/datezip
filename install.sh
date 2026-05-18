#!/bin/bash

# --- Configuration ---
SOURCE_FILE="datezip.sh"
DEFAULT_DIR="/usr/local/bin"
LEGACY_PATH="/usr/bin/datezip"
DEPENDENCIES=("zip" "unzip" "find" "sort" "awk" "sed" "comm")

# --- Functions ---
log() {
    printf "%b\n" "$1"
}

error_exit() {
    printf "Error: %b\n" "$1" >&2
    exit 1
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") [options] <target_directory>
       $(basename "$0") [options] --default

Installs the datezip utility.

Options:
  -s, --symlink       Install as a symlink to the current directory (for developers)
  --default           Installs to the default location ($DEFAULT_DIR)
  -h, --help          Show this help message

Arguments:
  <target_directory>  The directory to install the binary to (e.g., ~/.local/bin)
EOF
    exit 1
}

check_dependencies() {
    log "Checking system dependencies..."
    for cmd in "${DEPENDENCIES[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error_exit "Required command '$cmd' is not installed. Please install it before proceeding."
        fi
    done
}

# --- Main Execution ---

USE_SYMLINK=false
TARGET_DIR=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --default) TARGET_DIR="$DEFAULT_DIR" ;;
        --symlink|-s) USE_SYMLINK=true ;;
        -h|--help) show_usage ;;
        *) 
            if [[ -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$1"
            else
                error_exit "Unknown argument: $1"
            fi
            ;;
    esac
    shift
done

if [[ -z "$TARGET_DIR" ]]; then
    show_usage
fi

TARGET_PATH="$TARGET_DIR/datezip"

# 1. Ensure dependencies are met
check_dependencies

# 2. Verify source file existence
if [[ ! -f "$SOURCE_FILE" ]]; then
    error_exit "Source file '$SOURCE_FILE' not found in current directory."
fi

# 3. Determine if sudo is required
SUDO_CMD=""
if [[ -d "$TARGET_DIR" && ! -w "$TARGET_DIR" ]]; then
    SUDO_CMD="sudo"
    log "Elevated permissions required for $TARGET_DIR. Using sudo..."
elif [[ ! -d "$TARGET_DIR" ]]; then
    PARENT_DIR=$(dirname "$TARGET_DIR")
    if [[ ! -w "$PARENT_DIR" ]]; then
        SUDO_CMD="sudo"
        log "Elevated permissions required to create $TARGET_DIR. Using sudo..."
    fi
fi

# 4. Perform installation
if [[ "$USE_SYMLINK" == true ]]; then
    log "Installing $SOURCE_FILE as symlink to $TARGET_PATH..."
else
    log "Installing $SOURCE_FILE to $TARGET_PATH..."
fi

# Ensure the target directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    $SUDO_CMD mkdir -p "$TARGET_DIR" || error_exit "Failed to create directory $TARGET_DIR"
fi

INSTALL_SUCCESS=false
if [[ "$USE_SYMLINK" == true ]]; then
    # Use absolute path for symlink to ensure it remains valid
    ABS_SOURCE="$(pwd)/$SOURCE_FILE"
    chmod +x "$SOURCE_FILE"
    if $SUDO_CMD ln -sf "$ABS_SOURCE" "$TARGET_PATH"; then
        INSTALL_SUCCESS=true
    fi
else
    # Use -f to force overwrite without prompting
    if $SUDO_CMD cp -f "$SOURCE_FILE" "$TARGET_PATH"; then
        $SUDO_CMD chmod +x "$TARGET_PATH"
        INSTALL_SUCCESS=true
    fi
fi

if [[ "$INSTALL_SUCCESS" == true ]]; then
    # 5. Clean up legacy path if it exists
    if [[ -f "$LEGACY_PATH" ]]; then
        log "Removing legacy binary at $LEGACY_PATH..."
        if [[ -w "$(dirname "$LEGACY_PATH")" ]]; then
            rm -f "$LEGACY_PATH"
        else
            sudo rm -f "$LEGACY_PATH"
        fi
    fi

    log "Successfully installed datezip to $TARGET_PATH"
    log "\nNOTE: If your shell reports 'No such file or directory', run: hash -d datezip"
    
    # Warn if the directory isn't in PATH
    if [[ ":$PATH:" != *":$TARGET_DIR:"* ]]; then
        log "\nWARNING: The installation directory ($TARGET_DIR) is not in your \$PATH."
        log "You may need to add it to your ~/.bashrc or ~/.zshrc file."
    fi
else
    if [[ "$USE_SYMLINK" == true ]]; then
        error_exit "Failed to create symlink at $TARGET_PATH. Check permissions."
    else
        error_exit "Failed to copy file to $TARGET_PATH. Check permissions."
    fi
fi
