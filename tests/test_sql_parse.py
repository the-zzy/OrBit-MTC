import unittest
from unittest.mock import patch

from fastapi import HTTPException
from pydantic import ValidationError

from server.app import SQLParseRequest, check_sql_syntax, sql_parse


class FakeCursor:
    def __init__(self, fail=False):
        self.fail = fail
        self.statements = []

    def execute(self, statement):
        self.statements.append(statement)
        if self.fail and statement != "SET PARSEONLY ON":
            raise Exception(102, b"Incorrect syntax near 'SELCT'.")


class FakeConnection:
    def __init__(self, fail=False):
        self.fake_cursor = FakeCursor(fail)
        self.closed = False

    def cursor(self):
        return self.fake_cursor

    def close(self):
        self.closed = True


class SQLParseTests(unittest.TestCase):
    @patch("server.app.open_database")
    def test_parse_enables_parseonly_before_sql_and_closes_connection(self, open_database):
        connection = FakeConnection()
        open_database.return_value = connection
        sql = "CREATE PROCEDURE dbo.Example AS SELECT 1 AS Value"

        check_sql_syntax("jiban-mes-prod", sql)

        open_database.assert_called_once_with("jiban-mes-prod")
        self.assertEqual(connection.fake_cursor.statements, ["SET PARSEONLY ON", sql])
        self.assertTrue(connection.closed)

    @patch("server.app.open_database")
    def test_syntax_error_becomes_400_and_still_closes_connection(self, open_database):
        connection = FakeConnection(fail=True)
        open_database.return_value = connection

        with self.assertRaises(HTTPException) as raised:
            check_sql_syntax("jiban-mes-prod", "SELCT 1")

        self.assertEqual(raised.exception.status_code, 400)
        self.assertIn("Incorrect syntax", raised.exception.detail)
        self.assertEqual(connection.fake_cursor.statements, ["SET PARSEONLY ON", "SELCT 1"])
        self.assertTrue(connection.closed)

    def test_request_rejects_empty_sql_and_unsafe_source(self):
        with self.assertRaises(ValidationError):
            SQLParseRequest(source="jiban-mes-prod", code="")
        with self.assertRaises(ValidationError):
            SQLParseRequest(source="../secrets", code="SELECT 1")

    @patch("server.app.check_sql_syntax")
    def test_endpoint_rejects_whitespace_without_opening_database(self, check_syntax):
        with self.assertRaises(HTTPException) as raised:
            sql_parse(SQLParseRequest(source="jiban-mes-prod", code=" \n\t"))

        self.assertEqual(raised.exception.status_code, 400)
        check_syntax.assert_not_called()

    @patch("server.app.check_sql_syntax")
    def test_endpoint_returns_checked_source(self, check_syntax):
        result = sql_parse(SQLParseRequest(source="jiban-mes-prod", code="SELECT 1"))

        self.assertEqual(result, {"ok": True, "source": "jiban-mes-prod"})
        check_syntax.assert_called_once_with("jiban-mes-prod", "SELECT 1")


if __name__ == "__main__":
    unittest.main()
