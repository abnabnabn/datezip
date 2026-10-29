import unittest
from unittest.mock import patch, AsyncMock
import os
import shutil
import tempfile
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent / "mcp"))
import server
from server import get_historical_content

class TestMCPServer(unittest.IsolatedAsyncioTestCase):

    @patch("server.run_datezip", new_callable=AsyncMock)
    async def test_get_historical_content_path_traversal(self, mock_run):
        mock_run.return_value = (0, "Success", "")

        # Test relative path traversal escaping temporary directory
        res = await get_historical_content("20240216_120000", "../../etc/passwd")
        self.assertIn("path traversal attempt detected", res)

    @patch("server.run_datezip", new_callable=AsyncMock)
    async def test_get_historical_content_absolute_path_confined(self, mock_run):
        mock_run.return_value = (0, "Success", "")

        # Absolute paths should be converted to relative path inside temp directory
        # and not read system files directly
        res = await get_historical_content("20240216_120000", "/etc/passwd")
        self.assertNotIn("root:", res)
        self.assertIn("not found in archive", res)

    @patch("server.run_datezip", new_callable=AsyncMock)
    async def test_get_historical_content_valid_file(self, mock_run):
        async def fake_run_datezip(*args):
            # Find the --dest parameter in args
            dest_idx = args.index("--dest") + 1
            dest_dir = args[dest_idx]
            target = os.path.join(dest_dir, "src", "main.py")
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "w") as f:
                f.write("print('hello world')")
            return (0, "Restored", "")

        mock_run.side_effect = fake_run_datezip
        res = await get_historical_content("20240216_120000", "src/main.py")
        self.assertEqual(res, "print('hello world')")

if __name__ == "__main__":
    unittest.main()
