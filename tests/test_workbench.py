import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from server import app

CATALOG = {
    "ORDER": "1",
    "STAGE": "test",
    "LABEL": "'基板 MES 测试'",
    "HOST": "192.168.0.21",
    "MACHINE": "MTCS0021",
    "DB": "JIBAN",
    "TOOLS": "jiban-mes-test-query,jiban-mes-test-procedure",
}


class WorkbenchEnvironmentTests(unittest.TestCase):
    def test_secret_defines_the_connected_endpoint_and_account(self):
        with tempfile.TemporaryDirectory() as folder:
            secrets = Path(folder)
            (secrets / "jiban-mes-test.env").write_text(
                "DB_HOST=10.1.2.3\nDB_PORT=1444\nDB_USER=AIAssistant\nDB_PASSWORD=P@ssw0rd-test\n",
                encoding="utf-8",
            )
            with patch.object(app, "SECRETS", secrets):
                env = app.environment("jiban-mes-test", CATALOG)

        # 和 open_database() 一样，secrets 优先于目录里的 HOST。
        self.assertEqual(env["host"], "10.1.2.3")
        self.assertEqual(env["port"], 1444)
        self.assertEqual(env["account"], "AIAssistant")
        self.assertNotIn("P@ssw0rd-test", json.dumps(env, ensure_ascii=False))

    def test_catalog_host_and_default_port_when_secret_is_missing(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(app, "SECRETS", Path(folder)):
            env = app.environment("jiban-mes-test", CATALOG)

        self.assertEqual(env["host"], "192.168.0.21")
        self.assertEqual(env["port"], 1433)
        self.assertEqual(env["account"], "")

    def test_invalid_secret_port_falls_back_to_default(self):
        with tempfile.TemporaryDirectory() as folder:
            secrets = Path(folder)
            (secrets / "jiban-mes-test.env").write_text("DB_PORT=not-a-number\n", encoding="utf-8")
            with patch.object(app, "SECRETS", secrets):
                env = app.environment("jiban-mes-test", CATALOG)

        self.assertEqual(env["host"], "192.168.0.21")
        self.assertEqual(env["port"], 1433)
        self.assertEqual(env["account"], "")

    def test_workbench_returns_account_without_password(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            catalog = root / "catalog"
            secrets = root / "secrets"
            catalog.mkdir()
            secrets.mkdir()
            (catalog / "jiban-mes-test").write_text(
                "\n".join(f"{key}={value}" for key, value in CATALOG.items()) + "\n",
                encoding="utf-8",
            )
            (secrets / "jiban-mes-test.env").write_text(
                "DB_HOST=10.1.2.3\nDB_PORT=1444\nDB_USER=AIAssistant\nDB_PASSWORD=P@ssw0rd-test\n",
                encoding="utf-8",
            )
            with patch.object(app, "CATALOG", catalog), patch.object(app, "SECRETS", secrets):
                board = app.workbench()

        self.assertEqual(board["counts"], {"all": 1, "test": 1, "prod": 0})
        environment = board["test"][0]
        self.assertEqual(environment["account"], "AIAssistant")
        self.assertEqual(environment["port"], 1444)
        self.assertNotIn("P@ssw0rd-test", json.dumps(board, ensure_ascii=False))


if __name__ == "__main__":
    unittest.main()
