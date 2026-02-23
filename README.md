# datezip

`datezip` is a portable Bash utility designed for automated, recursive directory backups. It bridges the gap between simple "copy-paste" backups and complex enterprise solutions by providing native `.gitignore` support, intelligent incremental logic, targeted restorations, and a robust retention policy.

## Features

* **Git-Aware Traversal**: Automatically detects Git repositories and offers to operate from the project root.
* **Hierarchical Exclusions**: Recursively discovers and respects all `.gitignore` files within the directory tree, even if the directory is not a formal Git repository.
* **Daily Incremental Logic**: Defaults to a `FULL` backup for the first run of the day and `INC` (incremental) for subsequent runs, capturing only files modified since the last backup.
* **Chain Restoration**: Intelligently reconstructs project state by finding the preceding `FULL` backup and applying subsequent increments in sequence.
* **Granular Recovery**: Restore specific files from an archive rather than extracting the entire backup tree.
* **Automation-Friendly**: Supports fully non-interactive operations, quiet mode execution, and precise timestamp targeting for CI/CD or cron integrations.
* **Retention Management**: Automated cleanup based on a "whichever is greater" policy for backup count and age.

## Architecture

### Backup Workflow

```mermaid
graph TD
    A[Start datezip] --> B{Action?}
    B -->|Backup| C[Resolve Target Directory]
    C --> D[Identify Latest Backup]
    D --> E{Daily Status?}
    E -->|First Today| F[Set Mode: FULL]
    E -->|Subsequent| G[Set Mode: INC]
    F --> H[Scan .gitignore Patterns]
    G --> H
    H --> I[Execute Zip]
    I --> J[End]
```

### Restoration Chain

```mermaid
graph LR
    subgraph BackupStorage["Backup Storage"]
        F1[Full_01]
        I1[Inc_01]
        I2[Inc_02]
        F2[Full_02]
        I3[Inc_03]
    end
    
    UserSelect((Select I3)) --> Logic{Mode?}
    Logic -->|Just this| I3
    Logic -->|Everything| F2 --> I3
```

## Requirements

* **Bash**: 3.2+ (Natively compatible with macOS and standard Linux distributions)
* **Zip/Unzip**: Standard compression utilities
* **Find & Sort**: POSIX compliant utilities for file discovery and chronological sorting

## Installation

An installation script is provided to verify system dependencies and install the utility globally.

```bash
# Ensure the install script is executable
chmod +x install.sh

# Run the installer (requires sudo for /usr/bin access)
./install.sh
```

## Usage

### Basic Commands

| **Command** | **Description** | 
| ----- | ----- | 
| `datezip` | Performs a backup (Full if first of the day, otherwise Incremental) | 
| `datezip --full` | Forces a full backup regardless of date | 
| `datezip --list` | Lists all available backups and their corresponding indices | 
| `datezip --restore` | Starts interactive restoration mode | 
| `datezip --cleanup` | Removes obsolete increments and prunes old full backups | 
| `datezip -q` | Quiet mode; suppresses informational output (ideal for cron) | 

### Advanced & Non-Interactive Options

* `--local`: Skips Git root detection and operates strictly on the current working directory.
* `--git-root`: Forces the script to operate from the Git project root.
* `--keep-full N`: Number of full backups to keep (Default: 10).
* `--keep-days N`: Number of days to retain backups (Default: 14).
* `--restore-index N`: Non-interactively restores the backup at the specified index.
* `--restore-time TS`: Non-interactively restores to the state at or immediately prior to timestamp `YYYYMMDD_HHMMSS`.
* `--restore-type e|j`: When restoring an increment, specify whether to restore (e)verything in the chain or (j)ust the increment.
* `--files LIST`: A comma-separated list of specific files to extract from the targeted backup.

## Configuration

When running inside a Git repository, `datezip` saves your preference (Root vs. Subdir) in a hidden `.datezip` file at the project root.

```
# .datezip content example
root
```

## How It Works

### File Filtering

The script performs a recursive search for all `.gitignore` files. It translates Git-style patterns into `zip` exclusion arguments.

1. Patterns starting with `/` are anchored to the specific directory containing that `.gitignore`.
2. Other patterns match globally within that subdirectory.
3. Internal defaults always exclude `.git/`, `backups/`, and `.datezip`.

### Incremental Logic

Incremental backups are identified by the `_INC.zip` suffix. The script uses the `find -newer` command against the most recent backup file to identify changed assets, ensuring high performance without needing a file-hash database.

### Cleanup Logic

The cleanup process follows two rules:

1. **Orphan Removal**: Deletes any `INC` backup that is chronologically older than the latest `FULL` backup (since they are redundant for current state restoration).
2. **Retention Policy**: Keeps the most recent N full backups **OR** all full backups within the last M days, whichever resulting set is larger.

## License

MIT
