#!/bin/bash

# --- Configuration ---
SOURCE_FILE="datezip.sh"
TARGET_PATH="/usr/local/bin/datezip"
DEPENDENCIES=("zip" "unzip" "find" "sort")

# --- Functions ---
log() {
    printf "%b\n" "$1"
}

error_exit() {
    printf "Error: %b\n" "$1" >&2
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

# 1. Ensure dependencies are met
check_dependencies

# 2. Verify source file existence
if [[ ! -f "$SOURCE_FILE" ]]; then
    error_exit "Source file '$SOURCE_FILE' not found in current directory."
fi

# 3. Perform installation
log "Installing $SOURCE_FILE to $TARGET_PATH..."

# Ensure the target directory exists (relevant for some minimal Linux installs)
if [[ ! -d "/usr/local/bin" ]]; then
    sudo mkdir -p /usr/local/bin
fi

# Use -f to force overwrite without prompting
if sudo cp -f "$SOURCE_FILE" "$TARGET_PATH"; then
    sudo chmod +x "$TARGET_PATH"
    log "Successfully installed datezip to $TARGET_PATH"
else
    error_exit "Failed to copy file to $TARGET_PATH. Check permissions."
fi
