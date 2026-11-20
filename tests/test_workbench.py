import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi.testclient import TestClient

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
                token = app._current_role.set(app.ROLE_ADMIN)
                try:
                    board = app.workbench()
                finally:
                    app._current_role.reset(token)

        self.assertEqual(board["counts"], {"all": 1, "test": 1, "prod": 0})
        environment = board["test"][0]
        self.assertEqual(environment["account"], "AIAssistant")
        self.assertEqual(environment["port"], 1444)
        self.assertNotIn("P@ssw0rd-test", json.dumps(board, ensure_ascii=False))


class SkillReadTests(unittest.TestCase):
    def test_backtick_directory_name_is_not_a_skill_edge(self):
        known = {"dev", "mes-db", "dev-kanban-echart"}
        text = "看板用 `dev` 类别。环境走技能 `mes-db`。\n"
        self.assertEqual(app.skill_reads(text, "dev-kanban-echart", known), ["mes-db"])

    def test_path_and_hyphenated_backticks_count_in_reading_order(self):
        known = {"dev-create-table", "dev-kanban-echart", "dev-api-interface"}
        text = "技能 `dev-kanban-echart`。见 [dev-create-table](/.AGENTS/skills/dev-create-table/SKILL.md)。\n"
        self.assertEqual(
            app.skill_reads(text, "dev-api-interface", known),
            ["dev-kanban-echart", "dev-create-table"],
        )

    def test_real_skills_keep_the_dispatch_edges(self):
        rows = {item["id"]: item["reads"] for item in app.skills()}
        self.assertIn("mes-db", rows["dev"])
        self.assertIn("dev-create-table", rows["dev"])
        self.assertIn("dev-frontend-design", rows["dev"])
        self.assertNotIn("ops", rows["dev"])
        self.assertIn("ops-mobile-txn-survey", rows["ops"])
        self.assertIn("sql-query-safety", rows["ops"])
        self.assertEqual(rows["mes-db"], ["mes-meta-query", "sql-query-safety"])
        self.assertEqual(rows["sql-query-safety"], ["mes-db"])
        self.assertEqual(rows["dev-api-interface"], ["dev-kanban-echart", "dev-create-table"])
        self.assertEqual(rows["dev-create-table"], ["mes-db"])
        self.assertIn("ops-query-metadata-survey", rows["dev-label-mrt"])
        self.assertIn("dev-create-table", rows["dev-label-mrt"])
        self.assertNotIn("dev-label-mrt", rows["dev-label-mrt"])
        self.assertNotIn("dev", rows["dev-kanban-echart"])
        self.assertIn("mes-db", rows["dev-kanban-echart"])
        self.assertIn("ops", rows["ops-metadata-survey"])
        self.assertEqual(rows["dev-frontend-design"], [])


def write_login_files(root: Path) -> tuple[Path, Path]:
    catalog = root / "catalog"
    secrets = root / "secrets"
    catalog.mkdir()
    secrets.mkdir()
    (catalog / "demo-mes-prod").write_text(
        "STAGE=prod\nLABEL='演示 MES 正式'\nDB=DEMO\n", encoding="utf-8"
    )
    (catalog / "demo-mes-test").write_text(
        "STAGE=test\nLABEL='演示 MES 测试'\nDB=DEMO\n", encoding="utf-8"
    )
    (secrets / "workbench-users.env").write_text(
        "root=rootpw:admin\nbob=bobpw:user\n", encoding="utf-8"
    )
    return catalog, secrets


class WorkbenchLoginTests(unittest.TestCase):
    def test_default_account_is_admin_when_nothing_is_configured(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(app, "SECRETS", Path(folder)):
            self.assertEqual(app.login_users(), {"admin": ("orbit", "admin")})

    def test_env_file_account_is_admin(self):
        with tempfile.TemporaryDirectory() as folder:
            secrets = Path(folder)
            (secrets / "workbench.env").write_text(
                "LOGIN_USER=alice\nLOGIN_PASSWORD=p@ss\n", encoding="utf-8"
            )
            with patch.object(app, "SECRETS", secrets):
                self.assertEqual(app.login_users(), {"alice": ("p@ss", "admin")})

    def test_users_file_mixes_admin_and_plain_users(self):
        with tempfile.TemporaryDirectory() as folder:
            secrets = Path(folder)
            (secrets / "workbench-users.env").write_text(
                "bob=pw:user\ncarol=pa:ss:admin\ndave=no-role\n", encoding="utf-8"
            )
            with patch.object(app, "SECRETS", secrets):
                self.assertEqual(
                    app.login_users(),
                    {"bob": ("pw", "user"), "carol": ("pa:ss", "admin"), "dave": ("no-role", "user")},
                )

    def test_api_needs_login_and_logout_closes_session(self):
        with tempfile.TemporaryDirectory() as folder, patch.object(app, "SECRETS", Path(folder)), patch.dict(
            app._sessions, clear=True
        ):
            client = TestClient(app.app)
            self.assertEqual(client.get("/api/workbench").status_code, 401)
            self.assertEqual(client.get("/api/health").status_code, 200)
            self.assertEqual(
                client.post("/api/login", json={"username": "admin", "password": "bad"}).status_code,
                401,
            )

            ok = client.post("/api/login", json={"username": "admin", "password": "orbit"})
            self.assertEqual(ok.status_code, 200)
            self.assertEqual(ok.json(), {"user": "admin", "role": "admin"})
            self.assertEqual(client.get("/api/session").json()["role"], "admin")

            client.post("/api/logout")
            self.assertFalse(client.get("/api/session").json()["authenticated"])
            self.assertEqual(client.get("/api/workbench").status_code, 401)

    def test_plain_user_only_gets_prod_environments(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict(app._sessions, clear=True):
            catalog, secrets = write_login_files(Path(folder))
            with patch.object(app, "CATALOG", catalog), patch.object(app, "SECRETS", secrets):
                user = TestClient(app.app)
                login = user.post("/api/login", json={"username": "bob", "password": "bobpw"})
                self.assertEqual(login.json()["role"], "user")
                board = user.get("/api/workbench").json()
                self.assertEqual(board["test"], [])
                self.assertEqual(board["counts"]["test"], 0)
                self.assertEqual([item["id"] for item in board["prod"]], ["demo-mes-prod"])

                admin = TestClient(app.app)
                admin.post("/api/login", json={"username": "root", "password": "rootpw"})
                admin_board = admin.get("/api/workbench").json()
                self.assertEqual([item["id"] for item in admin_board["test"]], ["demo-mes-test"])

    def test_plain_user_cannot_parse_sql_on_test_environment(self):
        with tempfile.TemporaryDirectory() as folder, patch.dict(app._sessions, clear=True):
            catalog, secrets = write_login_files(Path(folder))
            with patch.object(app, "CATALOG", catalog), patch.object(app, "SECRETS", secrets):
                client = TestClient(app.app)
                client.post("/api/login", json={"username": "bob", "password": "bobpw"})
                response = client.post(
                    "/api/sql/parse",
                    json={"source": "demo-mes-test", "code": "SELECT 1"},
                )
                self.assertEqual(response.status_code, 403)
                self.assertIn("管理员", response.json()["detail"])

    def test_test_source_is_read_from_catalog_stage(self):
        with tempfile.TemporaryDirectory() as folder:
            catalog, _ = write_login_files(Path(folder))
            with patch.object(app, "CATALOG", catalog):
                self.assertTrue(app.is_test_source("demo-mes-test"))
                self.assertFalse(app.is_test_source("demo-mes-prod"))
                self.assertFalse(app.is_test_source("missing-env"))


if __name__ == "__main__":
    unittest.main()
