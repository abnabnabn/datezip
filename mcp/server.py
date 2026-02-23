import asyncio
import re
import os
import shutil
import tempfile
from typing import List, Optional, Dict, Any
from mcp.server.fastmcp import FastMCP

# Initialize FastMCP server with a strong system prompt for the agent
mcp = FastMCP(
    "datezip",
    description="A local time-machine and state management utility. Use these tools to safely snapshot the workspace before risky operations, audit past changes, and recover lost code."
)

async def run_datezip(*args: str) -> tuple[int, str, str]:
    """Helper to execute the datezip bash command asynchronously."""
    process = await asyncio.create_subprocess_exec(
        "datezip", *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout, stderr = await process.communicate()
    return process.returncode, stdout.decode().strip(), stderr.decode().strip()

@mcp.tool()
async def create_backup(mode: str = "auto") -> str:
    """
    CRITICAL: Call this tool to snapshot the project state BEFORE you perform massive refactors, 
    risky file deletions, or experimental code changes.
    
    Args:
        mode: 
          - "auto" (DEFAULT): Uses smart incremental logic. Highly recommended.
          - "full": Forces a massive full backup. Use ONLY if explicitly requested by the user or 
                    if a major architectural milestone was just reached.
          - "inc": Forces a small incremental update.
    """
    args = []
    if mode == "full":
        args.append("--full")
    elif mode == "inc":
        args.append("--inc")
    code, stdout, stderr = await run_datezip(*args)
    if code != 0:
        return f"Backup failed:\n{stderr or stdout}"
    return f"Backup successful:\n{stdout}"

@mcp.tool()
async def list_backups() -> List[Dict[str, Any]]:
    """
    Use this to get a high-level overview of all available backup archives on disk.
    Returns the timestamp and type (FULL/INC) of each backup.
    """
    code, stdout, stderr = await run_datezip("--list")
    if code != 0:
        raise RuntimeError(f"Failed to list backups: {stderr}")
    backups = []
    # Parse the output and drop the index to force timestamp-based navigation
    pattern = re.compile(r"^\[\d+\]\s+(datezip_([0-9]{8}_[0-9]{6})_(FULL|INC)\.zip)")
    for line in stdout.splitlines():
        match = pattern.match(line.strip())
        if match:
            backups.append({
                "filename": match.group(1),
                "timestamp": match.group(2),
                "type": match.group(3)
            })
    return backups

@mcp.tool()
async def get_history(
    files: Optional[List[str]] = None,
    from_ts: Optional[str] = None,
    to_ts: Optional[str] = None
) -> List[Dict[str, str]]:
    """
    REQUIRED FIRST STEP for any forensic analysis or restoration.
    Use this to find the exact 'timestamp' required by the `get_historical_content` and `restore_state` tools.
    
    Args:
        files: Limit the history search to specific filenames (e.g., ["src/main.py"]). HIGHLY RECOMMENDED for focused debugging.
        from_ts: Start timestamp format YYYYMMDD_HHMMSS (e.g., "20240216_000000").
        to_ts: End timestamp format YYYYMMDD_HHMMSS.
        
    Returns:
        A list of changes. Status '+' means the file was created/first seen, '.' means it was modified.
    """
    args = ["--history"]
    if files:
        args.extend(["--files", ",".join(files)])
    if from_ts:
        args.extend(["--from", from_ts])
    if to_ts:
        args.extend(["--to", to_ts])
    code, stdout, stderr = await run_datezip(*args)
    if code != 0:
        raise RuntimeError(f"Failed to get history: {stderr}")
    history = []
    pattern = re.compile(r"^([0-9]{8}_[0-9]{6})\s+([\+\.])\s+(.+)$")
    for line in stdout.splitlines():
        match = pattern.match(line.strip())
        if match:
            history.append({
                "timestamp": match.group(1),
                "status": "new" if match.group(2) == "+" else "modified",
                "file": match.group(3)
            })
    return history

@mcp.tool()
async def get_historical_content(timestamp: str, filename: str) -> str:
    """
    SAFE READ OPERATION. Use this to read the contents of a file from the past into your context WITHOUT overwriting the user's current workspace.
    
    Perfect for answering "what changed?", diffing code, or recovering a specific deleted function.
    
    Args:
        timestamp: The EXACT timestamp retrieved from `get_history` (e.g., "20240216_143000").
        filename: The specific file to read (e.g., "src/main.py").
    """
    tmp_dir = tempfile.mkdtemp()
    try:
        args = ["--restore-time", timestamp, "--files", filename, "--dest", tmp_dir, "--restore-type", "e"]
        code, stdout, stderr = await run_datezip(*args)
        if code != 0:
            return f"Error retrieving historical content: {stderr or stdout}"
        
        target_path = os.path.join(tmp_dir, filename)
        if os.path.exists(target_path):
            with open(target_path, 'r') as f:
                return f.read()
        else:
            return f"Error: File '{filename}' not found in archive at timestamp {timestamp}."
    finally:
        shutil.rmtree(tmp_dir)

@mcp.tool()
async def restore_state(
    timestamp: str,
    files: Optional[List[str]] = None,
    restore_type: str = "e"
) -> str:
    """
    DANGER: DESTRUCTIVE OPERATION. This will overwrite files in the user's active workspace with older versions.
    Unless the user explicitly asks to "revert" or "restore", prefer using `get_historical_content` to just read the old code.
    
    Args:
        timestamp: Target timestamp from `get_history` (e.g., "20240216_143000").
        files: Specific files to overwrite. If omitted, it restores the ENTIRE PROJECT. Always try to provide specific files!
        restore_type: 'e' (everything/chain overlay - default/recommended) or 'j' (just the specific increment).
    """
    args = ["--restore-time", timestamp, "--restore-type", restore_type]
    if files:
        args.extend(["--files", ",".join(files)])
    code, stdout, stderr = await run_datezip(*args)
    if code != 0:
        return f"Restore failed:\n{stderr or stdout}"
    return f"Restore successful:\n{stdout}"

@mcp.tool()
async def cleanup_backups(keep_full: int = 10, keep_days: int = 14) -> str:
    """
    Prunes old backup archives to free up disk space. 
    Only use this if the user explicitly complains about disk space or asks to clean up backups.
    """
    args = ["--cleanup", "--keep-full", str(keep_full), "--keep-days", str(keep_days)]
    code, stdout, stderr = await run_datezip(*args)
    if code != 0:
        return f"Cleanup failed:\n{stderr or stdout}"
    return f"Cleanup successful:\n{stdout}"

if __name__ == "__main__":
    mcp.run(transport="stdio")
