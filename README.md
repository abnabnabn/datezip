# datezip

`datezip` is a portable Bash utility designed for automated, recursive directory backups. It bridges the gap between simple "copy-paste" backups and complex enterprise solutions by providing native `.gitignore` support, intelligent incremental logic, targeted restorations, history tracking, and a robust retention policy.

## Features

* **Git-Aware Traversal**: Automatically detects Git repositories and offers to operate from the project root.
* **Hierarchical Exclusions**: Recursively discovers and respects all `.gitignore` files within the directory tree.
* **Daily Incremental Logic**: Defaults to a `FULL` backup for the first run of the day and `INC` (incremental) for subsequent runs.
* **Forensic History**: Search and trace the lifecycle of specific files across your entire retention window using `--history`.
* **Self-Healing Cache**: A Just-In-Time (JIT) history cache that automatically syncs with the disk state (detecting manual deletions or backfills).
* **Chain Restoration**: Intelligently reconstructs project state by finding the preceding `FULL` backup and applying subsequent increments in sequence.
* **Granular Recovery**: Restore specific files from an archive rather than extracting the entire backup tree.
* **Automation-Friendly**: Supports non-interactive operations, quiet mode, and precise timestamp targeting.

## Command Line Reference

### Core Operations
| Parameter | Description |
| :--- | :--- |
| `--backup` | Explicitly triggers a backup. This is the default action if no primary action is specified. |
| `--full` | Forces a `FULL` backup, ignoring the daily rotation logic. |
| `--inc` | Forces an incremental (`INC`) backup. |
| `--cleanup` | Prunes old backups based on retention settings (`--keep-full`, `--keep-days`). |

### Inspection & History
| Parameter | Description |
| :--- | :--- |
| `--list` | Lists all available backup ZIPs in the `backups/` folder with their index and timestamp. |
| `--history` | Shows the file modification history. Groups by backup by default. |
| `--reindex` | Triggers a full rebuild of the `.datezip_history` cache by scanning all ZIP files. |

### Filtering & Windowing
| Parameter | Description |
| :--- | :--- |
| `--files LIST` | A comma-separated list of filenames. Used to filter history or target specific files during restoration. |
| `--from TS` | Filter history starting at timestamp `YYYYMMDD_HHMMSS`. |
| `--to TS` | Filter history ending at timestamp `YYYYMMDD_HHMMSS`. |

### Restoration
| Parameter | Description |
| :--- | :--- |
| `--restore` | Enters the interactive restoration menu. |
| `--restore-index N` | Non-interactively restores the backup archive at index `N`. |
| `--restore-time TS` | Non-interactively restores the state at or immediately prior to timestamp `TS`. |
| `--restore-type e\|j` | `e` (Everything): Restore the full chain (Full + Incs). `j` (Just): Restore only the selected archive. |

### Configuration & Global
| Parameter | Description |
| :--- | :--- |
| `-q`, `--quiet` | Suppresses all informational output. Errors are still sent to `stderr`. |
| `--local` | Skips Git root detection; operates strictly on the current working directory. |
| `--git-root` | Forces operation from the detected Git project root. |
| `--keep-full N` | Retain `N` full backups during cleanup (Default: 10). |
| `--keep-days N` | Retain backups for `N` days during cleanup (Default: 14). |

## Common Use Cases

### 1. Point-in-Time Recovery
**Scenario:** You modified several files an hour ago and realized you made a mistake. You want to revert the whole directory to the state it was in at 2 PM today.

1. Find the timestamp in the history:
   ```bash
   datezip --history --from 20240216_130000 --to 20240216_150000
   ```
2. Restore the state:
   ```bash
   datezip --restore-time 20240216_140000
   ```

### 2. Recovering a Deleted File
**Scenario:** A configuration file was deleted yesterday. You need to get it back without overwriting your current work.

1. Trace the history of the file:
   ```bash
   datezip --history --files config/settings.json
   ```
2. Restore just that file from the latest available version:
   ```bash
   datezip --restore-time 20240215_180000 --files config/settings.json
   ```

### 3. Auditing Changes to a Sensitive File
**Scenario:** You want to see every time `auth.php` was changed in the last 7 days to investigate a security concern.

```bash
datezip --history --files auth.php --from 20240209_000000
```
*The output will show every backup containing a change to that file, marked with `.` for updates and `+` for its first appearance.*

### 4. Automated Daily Backups (Cron)
**Scenario:** You want the project to back up silently every hour and clean up old files at midnight.

Add this to your `crontab -e`:
```cron
# Backup every hour
0 * * * * /usr/local/bin/datezip --quiet

# Cleanup once a day at midnight
0 0 * * * /usr/local/bin/datezip --cleanup --quiet
```

### 5. Manual Repository Re-Indexing
**Scenario:** You manually moved several old `datezip_*.zip` files from another machine into your `backups/` folder and want them to show up in the history.

```bash
datezip --reindex
```
*The JIT cache logic will detect the new files, but `--reindex` ensures the chronological order and New/Updated statuses are perfectly recalculated.*

## How It Works

### JIT History Caching
To avoid overhead during routine backups, `datezip` uses a **Just-In-Time (JIT)** history cache (`backups/.datezip_history`).
- The cache is only updated when you query `--history`.
- It uses the `comm` utility to compare the timestamps on disk vs. the timestamps in the cache.
- **Deletions**: If a ZIP is missing from disk, the cache is rebuilt.
- **Additions**: New ZIPs are appended to the cache instantly using `unzip -Z1` and `awk`.

### Restoration Chain Overlay
When restoring a specific time, `datezip` identifies the `FULL` backup that started the chain and every `INC` (incremental) backup leading to your target. It extracts files from these archives sequentially. This "overlay" approach ensures that even if a file wasn't changed in the very last increment, you get the version that was most recently captured.

### Cleanup Logic
`datezip --cleanup` maintains your storage by:
1. Deleting all incremental backups (`INC`) that are older than the most recent `FULL` backup.
2. Enforcing the retention policy: keeps the last 10 full backups **or** all backups from the last 14 days (whichever results in more backups).
3. Automatically triggering a history reindex if any files are deleted to ensure the audit trail remains accurate.

## License

MIT
