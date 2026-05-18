#!/bin/bash

# Check if bats is installed
if ! command -v bats >/dev/null 2>&1; then
    echo "Error: 'bats' (Bash Automated Testing System) is not installed."
    echo ""
    echo "To install bats, you can use one of the following commands:"
    echo "  macOS (Homebrew): brew install bats-core"
    echo "  Ubuntu/Debian:    sudo apt update && sudo apt install bats"
    echo "  Fedora:           sudo dnf install bats"
    echo "  Arch Linux:       sudo pacman -S bats"
    echo "  npm:              npm install -g bats"
    echo ""
    echo "For more information, visit: https://github.com/bats-core/bats-core"
    exit 1
fi

# Run all .bats tests in the tests directory
echo "Running all datezip tests..."
bats tests/*.bats
