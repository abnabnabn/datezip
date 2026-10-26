import unittest
from unittest.mock import patch, AsyncMock
import os
import importlib.util

# Load mcp/server.py as a module directly
server_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'mcp', 'server.py'))
spec = importlib.util.spec_from_file_location("mcp_server", server_path)
mcp_server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mcp_server)

get_historical_content = mcp_server.get_historical_content

class TestMcpServerSecurity(unittest.IsolatedAsyncioTestCase):
    @patch.object(mcp_server, 'run_datezip', new_callable=AsyncMock)
    async def test_get_historical_content_path_traversal_absolute(self, mock_run_datezip):
        mock_run_datezip.return_value = (0, "Success", "")
        # Test absolute path attempt (e.g. /etc/passwd)
        res = await get_historical_content("20240101_000000", "/etc/passwd")
        self.assertIn("Invalid filename path traversal detected", res)

    @patch.object(mcp_server, 'run_datezip', new_callable=AsyncMock)
    async def test_get_historical_content_path_traversal_relative(self, mock_run_datezip):
        mock_run_datezip.return_value = (0, "Success", "")
        # Test relative path traversal attempt (e.g. ../../etc/passwd)
        res = await get_historical_content("20240101_000000", "../../etc/passwd")
        self.assertIn("Invalid filename path traversal detected", res)

if __name__ == "__main__":
    unittest.main()
