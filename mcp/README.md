# datezip MCP Server

This directory contains the Model Context Protocol (MCP) server for `datezip`. It exposes `datezip`'s versioning, backup, and forensic capabilities as structured tools to AI agents and LLMs.

By integrating this server, your AI agent gains a "local time machine"—allowing it to autonomously snapshot states before complex refactors, audit when specific logic regressions were introduced, and safely roll back files if tests fail.

## Prerequisites

1. Ensure the core `datezip` bash utility is installed and accessible in your system's `$PATH` (e.g., installed via the root `install.sh`).

2. Python 3.10 or higher.

3. Install the required Python dependencies:

```bash
cd mcp
pip install -r requirements.txt
```

## Available Tools

The server exposes the following tools to the LLM:

* **`create_backup`**: Takes a snapshot of the workspace. Accepts `auto` (default), `full`, or `inc`. Agents are instructed to use `auto` to prevent unnecessary full archives unless a major milestone is reached.

* **`list_backups`**: Returns a JSON array of all available ZIP archives, their indices, and timestamps.

* **`get_history`**: Returns a structured JSON audit trail. Can be filtered by `files`, `from_ts`, and `to_ts`.

* **`get_historical_content`**: Retrieves the content of a file from a specific point in time without modifying the workspace. Useful for diffing or summarizing changes since a previous version.

* **`restore_state`**: Automates point-in-time recovery. Accepts a `timestamp` or `index`, and an optional list of `files`.

* **`cleanup_backups`**: Prunes redundant increments based on retention variables.

## Usage Configuration

Because `datezip` relies on evaluating the current working directory (or detecting the Git root), the MCP server should be executed within the context of the workspace you are modifying.

### Standard MCP Configuration (Claude Desktop, Cline, Roo Code)

Add the following to your client's MCP configuration JSON file:

```json
{
  "mcpServers": {
    "datezip": {
      "command": "python",
      "args": ["/absolute/path/to/datezip/mcp/server.py"]
    }
  }
}
```

## Appendix A: Integration with Amazon Q in Visual Studio Code

Amazon Q Developer now supports the Model Context Protocol directly within VS Code, allowing the Q agent to utilize local tools.

### Step 1: Locate the Configuration File

Amazon Q reads its MCP server definitions from a specific configuration file in your home directory:

* **macOS / Linux**: `~/.config/amazon-q/mcp.json`
* **Windows**: `%USERPROFILE%\.config\amazon-q\mcp.json`

*(If the directory or file does not exist, create it).*

### Step 2: Add the datezip Server

Edit `mcp.json` to include the `datezip` server. Ensure you use the absolute path to the Python interpreter (if using a virtual environment) and the absolute path to `server.py`.

```json
{
  "mcpServers": {
    "datezip": {
      "command": "/usr/bin/python3", 
      "args": [
        "/absolute/path/to/your/clone/of/datezip/mcp/server.py"
      ],
      "env": {
        "PATH": "/usr/local/bin:/usr/bin:/bin"
      }
    }
  }
}
```

*Note: Supplying the `env.PATH` ensures the Python script can successfully locate the `datezip` bash executable.*

### Step 3: Reload Window

1. Open the VS Code Command Palette (`Cmd+Shift+P` or `Ctrl+Shift+P`).
2. Execute `Developer: Reload Window`.
3. Open the Amazon Q chat interface. Click the attachment/tools icon (often shaped like a plug or paperclip) to verify that `datezip` tools are connected and available for the agent to use.

### Example Prompts for Amazon Q

Once connected, you can use prompts like:

* *"I'm going to do a massive refactor of the API routes. Please create a backup first."*
* *"The tests are failing. Can you check the `datezip` history for `src/auth.py` and restore it to the version from yesterday?"*
* *"What has changed in the auth logic since the last full backup?"*
