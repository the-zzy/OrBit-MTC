import unittest
from datetime import datetime
from decimal import Decimal
from unittest.mock import Mock, patch

from db.mcp_server import (
    MesDatabase,
    create_server,
    json_value,
    transient_connect_error,
    validate_procedure,
    validate_query,
)


def database(source="jiban-mes-test", tools=("query", "procedure", "execute")):
    instance = MesDatabase.__new__(MesDatabase)
    instance.source = source
    instance.catalog = {"HOST": "db.example", "DB": "OrBit"}
    instance.secrets = {"DB_USER": "user", "DB_PASSWORD": "password"}
    instance.tools = set(tools)
    return instance


class FakeCursor:
    def __init__(self, rows=(), columns=("Value",)):
        self.rows = list(rows)
        self.columns = columns
        self.description = [(name,) for name in columns]
        self.statements = []

    def execute(self, statement, parameters=()):
        self.statements.append((statement, parameters))

    def fetchmany(self, count):
        return self.rows[:count]


class FakeConnection:
    def __init__(self, cursor=None):
        self.fake_cursor = cursor or FakeCursor()
        self.closed = False
        self.rolled_back = False

    def cursor(self):
        return self.fake_cursor

    def rollback(self):
        self.rolled_back = True

    def close(self):
        self.closed = True


class ValidationTests(unittest.TestCase):
    def test_query_accepts_select_and_cte(self):
        self.assertEqual(validate_query(" SELECT 1 "), "SELECT 1")
        self.assertTrue(validate_query("WITH q AS (SELECT 1 AS Value) SELECT * FROM q").startswith("WITH"))

    def test_query_rejects_writes_and_multiple_statements(self):
        for sql in (
            "DELETE FROM dbo.Test",
            "WITH q AS (SELECT 1 AS Value) DELETE FROM dbo.Test",
            "SELECT 1; SELECT 2",
            "SELECT * INTO dbo.Copy FROM dbo.Test",
            "EXEC dbo.DoSomething",
        ):
            with self.subTest(sql=sql), self.assertRaises(ValueError):
                validate_query(sql)

    def test_procedure_name_is_restricted(self):
        self.assertEqual(validate_procedure("Example"), "dbo.Example")
        self.assertEqual(validate_procedure("dbo.Example"), "dbo.Example")
        with self.assertRaises(ValueError):
            validate_procedure("dbo.Example; SELECT 1")

    def test_json_values_cover_database_types(self):
        self.assertEqual(json_value(Decimal("1.20")), "1.20")
        self.assertEqual(json_value(b"\x01"), "0x01")
        self.assertEqual(json_value(datetime(2026, 11, 17, 8, 30)), "2026-11-17T08:30:00")


class ConnectionTests(unittest.TestCase):
    @patch("db.mcp_server.time.sleep")
    @patch("db.mcp_server.pymssql.connect")
    def test_transient_connection_failure_retries_with_fresh_connection(self, connect, sleep):
        connection = FakeConnection()
        connect.side_effect = [TimeoutError("timed out"), connection]

        result = database().connect()

        self.assertIs(result, connection)
        self.assertEqual(connect.call_count, 2)
        sleep.assert_called_once_with(0.25)

    @patch("db.mcp_server.time.sleep")
    @patch("db.mcp_server.pymssql.connect")
    def test_permanent_connection_failure_is_not_retried(self, connect, sleep):
        connect.side_effect = Exception("Login failed for user")

        with self.assertRaises(RuntimeError) as raised:
            database("shuma-mes-prod").connect()

        self.assertIn("shuma-mes-prod", str(raised.exception))
        connect.assert_called_once()
        sleep.assert_not_called()

    def test_transient_error_recognizes_tds_network_message(self):
        self.assertTrue(transient_connect_error(Exception(20009, b"Unable to connect: server unavailable")))
        self.assertFalse(transient_connect_error(Exception(18456, b"Login failed for user")))

    def test_query_limits_rows_and_always_closes_connection(self):
        cursor = FakeCursor(rows=[{"Value": 1}, {"Value": 2}, {"Value": 3}])
        connection = FakeConnection(cursor)
        db = database()
        with patch.object(db, "connect", return_value=connection):
            result = db.query("SELECT Value FROM dbo.Test", 2)

        self.assertEqual(result["rowCount"], 2)
        self.assertTrue(result["truncated"])
        self.assertEqual(result["columns"], ["Value"])
        self.assertTrue(connection.rolled_back)
        self.assertTrue(connection.closed)

    def test_only_catalog_allowed_tools_are_registered(self):
        server = create_server(database(tools=("query",)))
        self.assertEqual(set(server._tool_manager._tools), {"query"})
        server = create_server(database(tools=("query", "procedure", "execute")))
        self.assertEqual(set(server._tool_manager._tools), {"query", "procedure", "execute"})


if __name__ == "__main__":
    unittest.main()
