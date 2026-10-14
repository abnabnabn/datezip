#!/usr/bin/env bats

setup() {
    # Isolate environment from local computer settings
    export LC_ALL=C
    export LANG=C
    export TZ=UTC
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CONFIG_GLOBAL=/dev/null
    umask 022

    # Resolve absolute canonical paths BEFORE changing working directory
    INSTALL_SCRIPT_SRC="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/install.sh"
    DATEZIP_SCRIPT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/datezip.sh"

    # Create an isolated temporary workspace for the installation
    TEST_WORKSPACE=$(mktemp -d 2>/dev/null || mktemp -d -t 'datezip')
    INSTALL_DIR="$TEST_WORKSPACE/bin"
    mkdir -p "$INSTALL_DIR"

    # Copy scripts to the workspace
    cp "$INSTALL_SCRIPT_SRC" "$TEST_WORKSPACE/install.sh"
    cp "$DATEZIP_SCRIPT" "$TEST_WORKSPACE/datezip.sh"
    INSTALL_SCRIPT="$TEST_WORKSPACE/install.sh"
    chmod +x "$INSTALL_SCRIPT"

    cd "$TEST_WORKSPACE" || exit 1
}

teardown() {
    # Step out of workspace before removing it to avoid directory lock on Windows/MSYS
    cd "$BATS_TEST_DIRNAME" 2>/dev/null || cd /
    rm -rf "$TEST_WORKSPACE"
}

@test "install to custom directory" {
    run "$INSTALL_SCRIPT" "$INSTALL_DIR"
    [ "$status" -eq 0 ]
    [ -f "$INSTALL_DIR/datezip" ]
    [ -x "$INSTALL_DIR/datezip" ]
    [ ! -L "$INSTALL_DIR/datezip" ]
}

@test "install as symlink" {
    run "$INSTALL_SCRIPT" --symlink "$INSTALL_DIR"
    [ "$status" -eq 0 ]
    [ -L "$INSTALL_DIR/datezip" ]
    
    # Verify the symlink points to the correct source file
    LINK_TARGET=$(readlink "$INSTALL_DIR/datezip")
    [ "$LINK_TARGET" == "$TEST_WORKSPACE/datezip.sh" ]
}

@test "install as symlink using short flag -s" {
    run "$INSTALL_SCRIPT" -s "$INSTALL_DIR"
    [ "$status" -eq 0 ]
    [ -L "$INSTALL_DIR/datezip" ]
    
    LINK_TARGET=$(readlink "$INSTALL_DIR/datezip")
    [ "$LINK_TARGET" == "$TEST_WORKSPACE/datezip.sh" ]
}

@test "show usage if no arguments provided" {
    run "$INSTALL_SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "show help message" {
    run "$INSTALL_SCRIPT" --help
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"--symlink"* ]]
}

@test "check dependencies (mocking success)" {
    # This just ensures the script runs through dependency checks
    run "$INSTALL_SCRIPT" "$INSTALL_DIR"
    [[ "$output" == *"Checking system dependencies..."* ]]
}

@test "remove legacy binary" {
    # Mock legacy path directory
    LEGACY_DIR="$TEST_WORKSPACE/usr/bin"
    mkdir -p "$LEGACY_DIR"
    touch "$LEGACY_DIR/datezip"
    
    # Let's patch install.sh for this specific test workspace to point to our fake legacy dir
    # Using a portable sed approach that works on both GNU and BSD
    sed "s|LEGACY_PATH=\"/usr/bin/datezip\"|LEGACY_PATH=\"$LEGACY_DIR/datezip\"|" "$INSTALL_SCRIPT" > "$INSTALL_SCRIPT.tmp"
    mv "$INSTALL_SCRIPT.tmp" "$INSTALL_SCRIPT"
    chmod +x "$INSTALL_SCRIPT"

    
    [ -f "$LEGACY_DIR/datezip" ]
    
    run "$INSTALL_SCRIPT" "$INSTALL_DIR"
    [ "$status" -eq 0 ]
    [ ! -f "$LEGACY_DIR/datezip" ]
    [[ "$output" == *"Removing legacy binary at $LEGACY_DIR/datezip..."* ]]
}

@test "install rejects target directory starting with a hyphen" {
    run "$INSTALL_SCRIPT" "-bad_target_dir"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Target directory cannot start with a hyphen"* ]]
}

@test "install creates target directory if it does not exist" {
    NESTED_DIR="$TEST_WORKSPACE/deep/nested/bin"
    run "$INSTALL_SCRIPT" "$NESTED_DIR"
    [ "$status" -eq 0 ]
    [ -d "$NESTED_DIR" ]
    [ -x "$NESTED_DIR/datezip" ]
}

@test "install fails if datezip.sh is missing" {
    rm -f "$TEST_WORKSPACE/datezip.sh"
    run "$INSTALL_SCRIPT" "$INSTALL_DIR"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Source file 'datezip.sh' not found in current directory."* ]]
}

@test "install rejects unknown arguments" {
    run "$INSTALL_SCRIPT" "$INSTALL_DIR" "--extra-arg"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Error: Unknown argument: --extra-arg"* ]]
}

