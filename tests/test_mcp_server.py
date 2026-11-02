import os
import sys
import unittest
from unittest.mock import patch

# Ensure mcp module is imported from repository root
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "mcp")))
import server


class TestMCPServerSecurity(unittest.IsolatedAsyncioTestCase):
    async def test_get_historical_content_rejects_absolute_path(self):
        result = await server.get_historical_content("20261102_120000", "/etc/passwd")
        self.assertIn("Error: Invalid or traversing file path", result)

    async def test_get_historical_content_rejects_relative_traversal(self):
        result = await server.get_historical_content("20261102_120000", "../../etc/passwd")
        self.assertIn("Error: Invalid or traversing file path", result)

    async def test_get_historical_content_rejects_current_dir(self):
        result = await server.get_historical_content("20261102_120000", ".")
        self.assertIn("Error: Invalid or traversing file path", result)

    @patch("server.run_datezip")
    async def test_get_historical_content_valid_file(self, mock_run_datezip):
        async def fake_run_datezip(*args):
            # args: --restore-time, ts, --files, filename, --dest, tmp_dir, --restore-type, e
            dest_idx = args.index("--dest")
            tmp_dir = args[dest_idx + 1]
            os.makedirs(os.path.join(tmp_dir, "src"), exist_ok=True)
            with open(os.path.join(tmp_dir, "src", "main.py"), "w") as f:
                f.write("print('safe historical content')")
            return 0, "Restore complete.", ""

        mock_run_datezip.side_effect = fake_run_datezip
        result = await server.get_historical_content("20261102_120000", "src/main.py")
        self.assertEqual(result, "print('safe historical content')")

    @patch("server.run_datezip")
    async def test_get_historical_content_rejects_symlink_escape(self, mock_run_datezip):
        async def fake_run_datezip(*args):
            dest_idx = args.index("--dest")
            tmp_dir = args[dest_idx + 1]
            # Simulate archive containing a symlink pointing to /etc/passwd
            os.symlink("/etc/passwd", os.path.join(tmp_dir, "evil.txt"))
            return 0, "Restore complete.", ""

        mock_run_datezip.side_effect = fake_run_datezip
        result = await server.get_historical_content("20261102_120000", "evil.txt")
        self.assertIn("Error: Invalid or traversing file path", result)


if __name__ == "__main__":
    unittest.main()
