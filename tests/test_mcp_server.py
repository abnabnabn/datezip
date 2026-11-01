import unittest
from unittest.mock import patch
import sys
import types
import os
import importlib.util

# Mock the mcp package dependencies before importing mcp/server.py
mock_mcp = types.ModuleType("mcp")
mock_server = types.ModuleType("mcp.server")
mock_fastmcp = types.ModuleType("mcp.server.fastmcp")

class MockFastMCP:
    def __init__(self, *args, **kwargs):
        pass
    def tool(self):
        return lambda fn: fn
    def run(self, *args, **kwargs):
        pass

mock_fastmcp.FastMCP = MockFastMCP
mock_server.fastmcp = mock_fastmcp
mock_mcp.server = mock_server

sys.modules["mcp"] = mock_mcp
sys.modules["mcp.server"] = mock_server
sys.modules["mcp.server.fastmcp"] = mock_fastmcp

# Dynamically import mcp/server.py
server_path = os.path.join(os.path.dirname(__file__), "..", "mcp", "server.py")
spec = importlib.util.spec_from_file_location("server", server_path)
server_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server_mod)


class TestMCPServerSecurity(unittest.IsolatedAsyncioTestCase):
    @patch.object(server_mod, "run_datezip")
    async def test_get_historical_content_rejects_absolute_path(self, mock_run):
        # Even if datezip returns 0 (e.g. zip ignores missing files)
        mock_run.return_value = (0, "Extracting...", "")

        # An attacker attempts to read /etc/hosts or /etc/passwd
        result = await server_mod.get_historical_content("20240101_120000", "/etc/hosts")
        self.assertTrue(
            result.startswith("Error:"),
            f"Expected error for absolute path, but got: {result}"
        )
        self.assertNotIn("localhost", result)

    @patch.object(server_mod, "run_datezip")
    async def test_get_historical_content_rejects_path_traversal(self, mock_run):
        mock_run.return_value = (0, "Extracting...", "")

        # An attacker attempts to traverse out using ../
        traversal_path = "../" * 10 + "etc/hosts"
        result = await server_mod.get_historical_content("20240101_120000", traversal_path)
        self.assertTrue(
            result.startswith("Error:"),
            f"Expected error for path traversal, but got: {result}"
        )
        self.assertNotIn("localhost", result)


if __name__ == "__main__":
    unittest.main()
