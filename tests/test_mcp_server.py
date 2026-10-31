import asyncio
import importlib.util
import os
import sys
import types
import unittest
from unittest.mock import MagicMock, AsyncMock, patch

# Mock mcp fastmcp module before loading mcp/server.py
class MockFastMCP:
    def __init__(self, *args, **kwargs):
        pass
    def tool(self):
        def decorator(fn):
            return fn
        return decorator

fastmcp_module = types.ModuleType("mcp.server.fastmcp")
fastmcp_module.FastMCP = MockFastMCP

sys.modules.setdefault("mcp", types.ModuleType("mcp"))
sys.modules.setdefault("mcp.server", types.ModuleType("mcp.server"))
sys.modules["mcp.server.fastmcp"] = fastmcp_module

server_path = os.path.join(os.path.dirname(__file__), "..", "mcp", "server.py")
spec = importlib.util.spec_from_file_location("datezip_server", server_path)
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)


class TestMCPServerSecurity(unittest.TestCase):
    def test_get_historical_content_rejects_path_traversal_absolute(self):
        with patch.object(server, "run_datezip", new_callable=AsyncMock) as mock_run:
            mock_run.return_value = (0, "", "")
            result = asyncio.run(server.get_historical_content("20240101_000000", "/etc/passwd"))
            self.assertIn("Path traversal detected", result)

    def test_get_historical_content_rejects_path_traversal_relative(self):
        with patch.object(server, "run_datezip", new_callable=AsyncMock) as mock_run:
            mock_run.return_value = (0, "", "")
            result = asyncio.run(server.get_historical_content("20240101_000000", "../../etc/passwd"))
            self.assertIn("Path traversal detected", result)

    def test_get_historical_content_allows_safe_relative_path(self):
        with patch.object(server, "run_datezip", new_callable=AsyncMock) as mock_run:
            mock_run.return_value = (0, "", "")
            result = asyncio.run(server.get_historical_content("20240101_000000", "safe_file.txt"))
            self.assertNotIn("Path traversal detected", result)
            self.assertIn("File 'safe_file.txt' not found in archive", result)


if __name__ == "__main__":
    unittest.main()
