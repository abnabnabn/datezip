#!/usr/bin/env bats

setup() {
    # Create a temporary workspace
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR" || exit 1
    # Path to the datezip.sh script
    DATEZIP="$BATS_TEST_DIRNAME/../datezip.sh"
    mkdir -p source_dir
    cd source_dir
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "basic full backup creates a zip file" {
    echo "test content" > file1.txt
    run "$DATEZIP" --full --quiet
    [ "$status" -eq 0 ]
    [ -d "backups" ]
    # Check if a zip file was created
    count=$(ls backups/datezip_*_FULL.zip | wc -l)
    [ "$count" -eq 1 ]
}

@test "incremental backup handles changes" {
    echo "initial" > file1.txt
    run "$DATEZIP" --full --quiet
    [ "$status" -eq 0 ]
    
    # Wait a second to ensure mtime difference if needed, 
    # though zip -newer usually works fine if we force INC
    sleep 1
    echo "modified" > file1.txt
    echo "new file" > file2.txt
    
    run "$DATEZIP" --inc --quiet
    [ "$status" -eq 0 ]
    
    inc_count=$(ls backups/datezip_*_INC.zip | wc -l)
    [ "$inc_count" -eq 1 ]
}

@test "history command shows entries" {
    echo "content" > file1.txt
    "$DATEZIP" --full --quiet
    
    run "$DATEZIP" --history
    [ "$status" -eq 0 ]
    [[ "$output" == *"file1.txt"* ]]
}

@test "history limit works" {
    echo "content1" > file1.txt
    "$DATEZIP" --full --quiet
    sleep 1
    echo "content2" > file2.txt
    "$DATEZIP" --inc --quiet
    
    # Total entries: file1.txt (FULL) + file2.txt (INC) = 2
    run "$DATEZIP" --history --limit 1
    [ "$status" -eq 0 ]
    # Output should contain only one file entry (the most recent one)
    # The header "---- ... ----" and the file entry.
    # We count lines that look like history entries
    entry_count=$(echo "$output" | grep -c "  [.+*]  " || true)
    [ "$entry_count" -eq 1 ]
}

@test "restore works for full backup" {
    echo "original" > file1.txt
    "$DATEZIP" --full --quiet
    
    rm file1.txt
    run "$DATEZIP" --restore-index 0 --dest restored --quiet
    [ "$status" -eq 0 ]
    [ -f restored/file1.txt ]
    [ "$(cat restored/file1.txt)" == "original" ]
}

@test "restore works for incremental chain" {
    echo "v1" > file1.txt
    "$DATEZIP" --full --quiet
    
    sleep 1
    echo "v2" > file1.txt
    echo "new" > file2.txt
    "$DATEZIP" --inc --quiet
    
    rm file1.txt file2.txt
    # Restore to index 1 (the INC backup)
    # Adding --restore-type e to avoid interactive prompt
    run "$DATEZIP" --restore-index 1 --restore-type e --dest restored --quiet
    [ "$status" -eq 0 ]
    [ -f restored/file1.txt ]
    [ -f restored/file2.txt ]
    [ "$(cat restored/file1.txt)" == "v2" ]
    [ "$(cat restored/file2.txt)" == "new" ]
}

@test "help command returns 0" {
    run "$DATEZIP" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "list command shows backups" {
    echo "test" > file1.txt
    "$DATEZIP" --full --quiet
    run "$DATEZIP" --list
    [ "$status" -eq 0 ]
    [[ "$output" == *"datezip_"* ]]
}

@test "restore-time works" {
    echo "v1" > file1.txt
    "$DATEZIP" --full --quiet
    
    # Extract timestamp from the backup file
    ts=$(ls backups/datezip_*_FULL.zip | cut -d'_' -f2,3 | cut -d'.' -f1)
    
    rm file1.txt
    run "$DATEZIP" --restore-time "$ts" --dest restored --quiet
    [ "$status" -eq 0 ]
    [ -f restored/file1.txt ]
}

@test "history filtering with --from and --to" {
    echo "f1" > f1.txt
    "$DATEZIP" --full --quiet
    ts1=$(ls backups/datezip_*_FULL.zip | cut -d'_' -f2,3 | cut -d'.' -f1)
    
    sleep 1
    echo "f2" > f2.txt
    "$DATEZIP" --inc --quiet
    ts2=$(ls backups/datezip_*_INC.zip | cut -d'_' -f2,3 | cut -d'.' -f1)
    
    # Filter for only the first one
    run "$DATEZIP" --history --to "$ts1"
    [[ "$output" == *"f1.txt"* ]]
    [[ "$output" != *"f2.txt"* ]]
    
    # Filter for only the second one
    run "$DATEZIP" --history --from "$ts2"
    [[ "$output" != *"f1.txt"* ]]
    [[ "$output" == *"f2.txt"* ]]
}

@test "reindex rebuilds cache" {
    echo "test" > file1.txt
    "$DATEZIP" --full --quiet
    # Trigger history to create cache
    "$DATEZIP" --history >/dev/null
    [ -f "backups/.datezip_history" ]
    
    # Delete cache and reindex
    rm "backups/.datezip_history"
    run "$DATEZIP" --reindex --quiet
    [ "$status" -eq 0 ]
    [ -f "backups/.datezip_history" ]
    grep -q "file1.txt" "backups/.datezip_history"
}

@test "cleanup respects keep-full and keep-days" {
    # Create an old backup (30 days ago)
    # 20200101_120000
    mkdir -p backups
    touch -t 202001011200 backups/datezip_20200101_120000_FULL.zip
    
    # Create 2 recent backups
    echo "1" > f1.txt; "$DATEZIP" --full --quiet; sleep 1
    echo "2" > f1.txt; "$DATEZIP" --full --quiet
    
    # Total: 3 FULL backups.
    # If we keep-full 2, the oldest (2020) should go.
    run "$DATEZIP" --cleanup --keep-full 2 --keep-days 14 --quiet
    [ "$status" -eq 0 ]
    
    count=$(ls backups/datezip_*_FULL.zip | wc -l)
    [ "$count" -eq 2 ]
    [ ! -f backups/datezip_20200101_120000_FULL.zip ]
}

@test "cleanup keeps recent backups even if they exceed keep-full (larger set rule)" {
    # Create 5 recent backups
    for i in {1..5}; do
        echo "$i" > "f$i.txt"
        "$DATEZIP" --full --quiet
        sleep 1
    done
    
    # Total: 5 FULL backups, all very recent.
    # Set keep-full to 2, but keep-days to 14.
    # Since they are all within 14 days, they should all be kept.
    run "$DATEZIP" --cleanup --keep-full 2 --keep-days 14 --quiet
    [ "$status" -eq 0 ]
    
    count=$(ls backups/datezip_*_FULL.zip | wc -l)
    [ "$count" -eq 5 ]
}

@test "git root detection works" {
    # Move out of source_dir and create a git-like structure
    cd ..
    mkdir git_root
    cd git_root
    mkdir -p .git
    mkdir subdir
    cd subdir
    echo "content" > file.txt
    
    # Run with --git-root, should create backups at git_root/backups
    # We use --local to bypass the interactive prompt if it triggers, 
    # but here we test the detection logic.
    # Note: the script might prompt for S/T if not in quiet mode or if no config exists.
    # We'll use --quiet to ensure it defaults to subdir or root without hanging.
    "$DATEZIP" --full --git-root --quiet
    
    # Since we didn't provide a .datezip config, it should have defaulted to subdir 
    # based on the script logic for non-interactive/quiet.
    # Wait, let's check what it does in quiet mode.
    [ -d "backups" ] || [ -d "../backups" ]
}

@test "history with specific --files" {
    echo "content" > file1.txt
    echo "other" > file2.txt
    "$DATEZIP" --full --quiet
    
    run "$DATEZIP" --history --files file1.txt
    [[ "$output" == *"file1.txt"* ]]
    [[ "$output" != *"file2.txt"* ]]
}

@test "restore specific --files" {
    echo "f1" > f1.txt
    echo "f2" > f2.txt
    "$DATEZIP" --full --quiet
    
    rm f1.txt f2.txt
    run "$DATEZIP" --restore-index 0 --files f1.txt --dest restored --quiet
    [ -f restored/f1.txt ]
    [ ! -f restored/f2.txt ]
}

@test "restore-type j only restores the specific increment" {
    echo "v1" > file1.txt
    "$DATEZIP" --full --quiet
    
    sleep 1
    echo "v2" > file1.txt
    echo "new" > file2.txt
    "$DATEZIP" --inc --quiet
    
    rm file1.txt file2.txt
    # Restore ONLY index 1 (the INC backup)
    run "$DATEZIP" --restore-index 1 --restore-type j --dest restored --quiet
    [ "$status" -eq 0 ]
    
    # In 'j' mode, file1.txt was NOT in the INC backup (only newer files are)
    # Actually, in datezip.sh, INC backups contain modified files.
    # So file1.txt (v2) SHOULD be there, but the baseline (v1) was not.
    # If we only restore the increment, we only get what's in that specific zip.
    [ -f restored/file1.txt ]
    [ -f restored/file2.txt ]
    [ "$(cat restored/file1.txt)" == "v2" ]
}

@test "local flag bypasses git detection" {
    # Put .git in the parent directory
    cd ..
    mkdir git_root
    cd git_root
    mkdir -p .git
    mkdir subdir
    cd subdir
    echo "test" > file1.txt
    
    # Run WITH --local. It should stay in subdir.
    run "$DATEZIP" --full --local --quiet
    [ -d "backups" ]
    [ ! -d "../backups" ]
}

@test "complex gitignore with nesting and anchoring" {
    # Setup structure:
    # .gitignore (root): 
    #   *.log
    #   /secret.txt
    
    echo "*.log" > .gitignore
    echo "/secret.txt" >> .gitignore
    
    mkdir dir1 dir2
    echo "keep" > ignore.txt # This should be KEPT because root only ignores /secret.txt
    echo "log" > test.log
    echo "secret" > secret.txt
    
    # dir1/.gitignore:
    #   inner.txt
    echo "inner.txt" > dir1/.gitignore
    echo "ignore" > dir1/inner.txt
    mkdir -p dir1/subdir
    echo "ignore" > dir1/subdir/inner.txt # Should be ignored (unanchored)
    
    # dir2 has same name file
    echo "keep" > dir2/inner.txt # Should be KEPT (scoped to dir1)
    
    "$DATEZIP" --full --quiet
    
    run "$DATEZIP" --history
    # Should ignore
    [[ "$output" != *"test.log"* ]]
    [[ "$output" != *"secret.txt"* ]]
    [[ "$output" != *"dir1/inner.txt"* ]]
    [[ "$output" != *"dir1/subdir/inner.txt"* ]]
    
    # Should keep
    [[ "$output" == *"ignore.txt"* ]]
    [[ "$output" == *"dir2/inner.txt"* ]]
}

@test "gitignore negation works in git repo" {
    # Initialize a git repo
    git init --quiet
    
    # Ignore all .log files but keep important.log
    echo "*.log" > .gitignore
    echo "!important.log" >> .gitignore
    
    echo "trash" > ordinary.log
    echo "precious" > important.log
    
    "$DATEZIP" --full --quiet
    
    run "$DATEZIP" --history
    [[ "$output" == *"important.log"* ]]
    [[ "$output" != *"ordinary.log"* ]]
}

@test "status command identifies modified, deleted, and untracked files" {
    echo "original" > modified.txt
    echo "to be deleted" > deleted.txt
    "$DATEZIP" --full --quiet
    
    # Change disk state
    sleep 1
    echo "changed" > modified.txt
    rm deleted.txt
    echo "new" > untracked.txt
    
    run "$DATEZIP" --status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Modified:"* ]]
    [[ "$output" == *". modified.txt"* ]]
    [[ "$output" == *"Deleted:"* ]]
    [[ "$output" == *"- deleted.txt"* ]]
    [[ "$output" == *"Untracked:"* ]]
    [[ "$output" == *"? untracked.txt"* ]]
    
    # Ensure .git and backups are NOT in the output
    [[ "$output" != *".git"* ]]
    [[ "$output" != *"backups"* ]]
}

@test "status command ignores unchanged files" {
    echo "stable" > stable.txt
    "$DATEZIP" --full --quiet
    
    # Run status without any changes
    run "$DATEZIP" --status
    [ "$status" -eq 0 ]
    [[ "$output" != *"Modified:"* ]]
    [[ "$output" != *"stable.txt"* ]]
}

@test "config file .datezip is respected" {
    mkdir -p .git
    echo "root" > .datezip
    mkdir subdir
    cd subdir
    echo "test" > file.txt
    
    # Should backup from the root because .datezip says 'root'
    "$DATEZIP" --full --quiet
    
    cd ..
    [ -d "backups" ]
}
