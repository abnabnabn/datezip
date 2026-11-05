import unittest
import asyncio
import os
import sys
import importlib.util

# Load mcp/server.py directly to avoid colliding with installed mcp package
server_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "mcp", "server.py"))
spec = importlib.util.spec_from_file_location("mcp_server", server_path)
mcp_server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mcp_server)

get_historical_content = mcp_server.get_historical_content

class TestMcpSecurity(unittest.IsolatedAsyncioTestCase):
    async def test_get_historical_content_rejects_empty_and_hyphen_filename(self):
        res1 = await get_historical_content("20240101_120000", "")
        self.assertIn("Error: Invalid filename", res1)

        res2 = await get_historical_content("20240101_120000", "-badflag")
        self.assertIn("Error: Invalid filename", res2)

    async def test_get_historical_content_prevents_absolute_path_traversal(self):
        res = await get_historical_content("20240101_120000", "/etc/passwd")
        self.assertIn("Error: Path traversal detected in filename", res)

    async def test_get_historical_content_prevents_relative_path_traversal(self):
        res = await get_historical_content("20240101_120000", "../../etc/passwd")
        self.assertIn("Error: Path traversal detected in filename", res)

if __name__ == "__main__":
    unittest.main()
