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
Usage: $(basename "$0") <target_directory> | --default

Installs the datezip utility to the specified location.

Arguments:
  <target_directory>  The directory to install the binary to (e.g., ~/.local/bin)
  --default           Installs to the default location ($DEFAULT_DIR)
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

if [[ -z "$1" ]]; then
    show_usage
fi

TARGET_DIR="$1"
if [[ "$TARGET_DIR" == "--default" ]]; then
    TARGET_DIR="$DEFAULT_DIR"
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
log "Installing $SOURCE_FILE to $TARGET_PATH..."

# Ensure the target directory exists
if [[ ! -d "$TARGET_DIR" ]]; then
    $SUDO_CMD mkdir -p "$TARGET_DIR" || error_exit "Failed to create directory $TARGET_DIR"
fi

# Use -f to force overwrite without prompting
if $SUDO_CMD cp -f "$SOURCE_FILE" "$TARGET_PATH"; then
    $SUDO_CMD chmod +x "$TARGET_PATH"
    
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
    error_exit "Failed to copy file to $TARGET_PATH. Check permissions."
fi
