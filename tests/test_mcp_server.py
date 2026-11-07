import os
import unittest
import importlib.util
from unittest.mock import patch, AsyncMock

# Avoid package naming conflict with third-party mcp package
server_path = os.path.join(os.path.dirname(__file__), "..", "mcp", "server.py")
spec = importlib.util.spec_from_file_location("datezip_mcp_server", server_path)
server_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server_mod)


class TestMcpServerSecurity(unittest.IsolatedAsyncioTestCase):
    @patch.object(server_mod, "run_datezip", new_callable=AsyncMock)
    async def test_get_historical_content_rejects_absolute_path(self, mock_run):
        # /etc/hosts exists on unix systems
        result = await server_mod.get_historical_content("20240216_143000", "/etc/hosts")
        # Should not execute datezip or leak host /etc/hosts
        mock_run.assert_not_called()
        self.assertIn("Error: Invalid or unsafe filename '/etc/hosts'", result)

    @patch.object(server_mod, "run_datezip", new_callable=AsyncMock)
    async def test_get_historical_content_rejects_path_traversal(self, mock_run):
        result = await server_mod.get_historical_content("20240216_143000", "../../etc/passwd")
        mock_run.assert_not_called()
        self.assertIn("Error: Invalid or unsafe filename '../../etc/passwd'", result)

    @patch.object(server_mod, "run_datezip", new_callable=AsyncMock)
    async def test_get_historical_content_safe_file_not_found(self, mock_run):
        mock_run.return_value = (0, "Success", "")
        result = await server_mod.get_historical_content("20240216_143000", "safe_file.py")
        mock_run.assert_called_once()
        self.assertIn("File 'safe_file.py' not found in archive", result)


if __name__ == "__main__":
    unittest.main()
