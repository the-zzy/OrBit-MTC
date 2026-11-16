import json
import tempfile
import unittest
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from unittest.mock import patch

from fastapi import HTTPException

from server import app


class StaticTxnTests(unittest.TestCase):
    def test_object_name_comes_from_plugin_parameter(self):
        plugin = {"PluginCommand": "PACK", "PluginParameter": "xxx[mestxn: PackScan ]yyy"}
        self.assertEqual(app.static_txn_object_name(plugin), "PackScan")

        with self.assertRaises(HTTPException) as raised:
            app.static_txn_object_name({"PluginCommand": "PACK", "PluginParameter": ""})
        self.assertEqual(raised.exception.status_code, 404)

    def test_sysparameter_mapping_precedes_direct_object_name(self):
        class Cursor:
            def execute(self, sql, params=()):
                self.parameter = params[0]

            def fetchall(self):
                return [{"ParameterValue": "ImportExcelBatch"}]

        plugin = {"PluginCommand": "BIME", "PluginParameter": "[MESTXN:批量导入EXCEL][N]"}
        self.assertEqual(app.static_txn_lookup_names(Cursor(), plugin), ["ImportExcelBatch"])

    def test_configuration_builds_only_style_value_lists_and_methods(self):
        sections = {
            "object": {
                "table": "MESTxnObject",
                "columns": [],
                "rows": [{"MESTxnObjectName": "PackScan", "MESTxnObjectDesc": "包装扫描", "ColumnCount": 3, "FieldWidth": 240, "FieldSpace": 12}],
            },
            "parameters": {
                "table": "MESTxnObjectParameter",
                "columns": [{"name": "ParameterName", "text": "参数"}],
                "rows": [
                    {
                        "TxnParameterName": "LotNo",
                        "ParameterDesc": "批次",
                        "DataType": "N",
                        "ParameterSequence": "2",
                        "IsMustInput": 1,
                        "IsValueListUsage": 1,
                        "ValueList": "LotValueList",
                    },
                    {
                        "TxnParameterName": "Qty",
                        "ParameterDesc": "数量",
                        "DataType": "I",
                        "ParameterSequence": "1",
                        "DefaultValue": 0,
                    },
                ],
            },
            "methods": {
                "table": "MESTxnObjectMethod",
                "columns": [{"name": "MethodName", "text": "方法"}],
                "rows": [{
                    "MESTxnObjectMethodName": "Submit",
                    "MethodDesc": "提交",
                    "SQLDoTxn": "PackScanSubmit",
                    "MethodSequence": "1",
                    "IsBeforeRunningConfirm": 1,
                    "PromptMessage": "确认提交？",
                }],
            },
            "specifications": {"table": "MESTxnObjectSpecification", "columns": [], "rows": []},
        }

        target = app.static_txn_object(sections, {})
        group = target["style"]["main"]["groups"][0]

        self.assertEqual(target["name"], "PackScan")
        self.assertEqual(target["text"], "包装扫描")
        self.assertEqual(target["style"]["tree"]["columns"], [])
        self.assertEqual(group["columns"], 3)
        self.assertEqual(group["fieldWidth"], 240)
        self.assertEqual(group["fieldSpace"], 12)
        self.assertFalse(group["custom"])
        self.assertEqual([field["name"] for field in group["fields"]], ["Qty", "LotNo"])
        self.assertEqual(group["fields"][0]["type"], "int")
        self.assertEqual(group["fields"][0]["default"], 0)
        self.assertTrue(group["fields"][1]["required"])
        self.assertEqual(app.value_list_names(target["style"]["main"]), ["LotValueList"])
        self.assertEqual(group["methods"][0]["sql"], "PackScanSubmit")
        self.assertTrue(group["methods"][0]["confirm"])
        self.assertEqual(group["methods"][0]["configColumns"], sections["methods"]["columns"])
        self.assertNotIn("specifications", target["style"]["main"])

    def test_custom_layout_reads_mes_ui_style(self):
        style = app.parse_ui_style(
            "[BackColor|White][LocationX|225][LocationY|29][SizeHeight|34][SizeWidth|200]"
        )

        self.assertEqual(style["BackColor"], "White")
        self.assertEqual(style["LocationX"], 225)
        self.assertEqual(style["LocationY"], 29)
        self.assertEqual(style["SizeHeight"], 34)
        self.assertEqual(style["SizeWidth"], 200)

    def test_actual_table_column_names_are_inferred(self):
        method = {"MESTxnObjectName": "PackScan", "MESTxnObjectMethodName": "Submit"}
        parameter = {"MESTxnObjectName": "PackScan", "TxnParameterName": "LotNo"}

        self.assertEqual(app.static_txn_item_name(method, "methods"), "Submit")
        self.assertEqual(app.static_txn_item_name(parameter, "parameters"), "LotNo")

    def test_snapshot_values_are_json_serializable(self):
        values = {
            "created": datetime(2026, 11, 16, 10, 30, 0),
            "quantity": Decimal("12.50"),
            "data": b"\x01\xff",
        }
        normalized = {key: app.snapshot_value(value) for key, value in values.items()}

        self.assertEqual(normalized["created"], "2026-11-16T10:30:00")
        self.assertEqual(normalized["quantity"], "12.50")
        self.assertEqual(normalized["data"], "0x01ff")
        json.dumps(normalized)

    def test_static_pull_writes_three_visible_views_and_analysis_snapshot(self):
        rows_by_table = {
            "MESTxnObject": [{
                "MESTxnObjectId": "MTO100000001",
                "MESTxnObjectName": "PackScan",
                "MESTxnObjectDesc": "包装扫描",
                "ColumnCount": 2,
            }],
            "MESTxnObjectParameter": [{
                "MESTxnObjectId": "MTO100000001",
                "TxnParameterName": "LotNo",
                "ParameterDesc": "批次",
                "DataType": "N",
                "ValueList": "LotValueList",
            }],
            "MESTxnObjectMethod": [{
                "MESTxnObjectId": "MTO100000001",
                "MESTxnObjectMethodName": "Submit",
                "MethodDesc": "提交",
                "SQLDoTxn": "PackScanSubmit",
            }],
            "MESTxnObjectSpecification": [{
                "MESTxnObjectId": "MTO100000001",
                "SpecificationName": "PackSpecification",
            }],
        }

        class Cursor:
            def __init__(self):
                self.rows = []
                self.description = []

            def execute(self, sql, params=()):
                self.rows = []
                self.description = []
                if sql.startswith("SELECT * FROM dbo."):
                    table = sql.split("dbo.", 1)[1].split(" ", 1)[0]
                    column = "MESTxnObjectId" if "RTRIM(MESTxnObjectId)" in sql else "MESTxnObjectName"
                    self.rows = [dict(row) for row in rows_by_table[table] if row.get(column) == params[0]]
                    columns = list(self.rows[0]) if self.rows else list(rows_by_table[table][0])
                    self.description = [(name,) for name in columns]
                elif "FROM sys.sql_modules" in sql:
                    procedure = params[0].removeprefix("dbo.")
                    self.rows = [{"definition": f"CREATE PROC {procedure} AS SELECT 1"}]

            def fetchall(self):
                return self.rows

        plugin = {
            "PluginCommand": "PACK",
            "PluginName": "包装扫描",
            "PluginDescription": "包装扫描事务",
            "PluginFileName": "PluginMESStaticTxn.dll",
            "PluginParameter": "[MESTXN:PackScan]",
            "MetadataId": "",
        }
        with tempfile.TemporaryDirectory() as folder, patch.object(app, "LIBRARY", Path(folder)):
            library = Path(folder) / "jiban" / "PACK"
            library.mkdir(parents=True)
            document = app.pull_static_txn(
                library,
                app.skeleton_pack("jiban", "PACK"),
                "jiban-mes-prod",
                "jiban",
                "PACK",
                Cursor(),
                plugin,
            )

            target = document["objects"][0]
            method = target["style"]["main"]["groups"][0]["methods"][0]
            self.assertEqual(method["definition"], "CREATE PROC PackScanSubmit AS SELECT 1")
            self.assertEqual(target["valueLists"][0]["sql"], "CREATE PROC LotValueList AS SELECT 1")
            self.assertEqual(document["txn"]["objects"][0]["sections"]["specifications"]["rows"][0]["SpecificationName"], "PackSpecification")
            self.assertNotIn("missing", document)
            self.assertTrue((library / "PackScanSubmit.sql").is_file())
            self.assertTrue((library / "LotValueList.sql").is_file())

    def test_missing_static_document_does_not_look_up_sysmetadata(self):
        class Cursor:
            def __init__(self):
                self.queries = []

            def execute(self, sql, params=()):
                self.queries.append(sql)

            def fetchall(self):
                return [{
                    "PluginCommand": "PACK",
                    "PluginName": "包装扫描",
                    "PluginDescription": "包装扫描事务",
                    "PluginFileName": "PluginMESStaticTxn.dll",
                    "PluginParameter": "[MESTXN:PackScan]",
                    "MetadataId": "",
                }]

        class Connection:
            def __init__(self):
                self.cursor_instance = Cursor()
                self.closed = False

            def cursor(self, as_dict=False):
                return self.cursor_instance

            def close(self):
                self.closed = True

        connection = Connection()
        with tempfile.TemporaryDirectory() as folder, patch.object(app, "LIBRARY", Path(folder)), patch.object(
            app, "open_database", return_value=connection
        ):
            document = app.function_pack("jiban", "PACK")

        self.assertEqual(document["kind"], "静态事务对象")
        self.assertEqual(document["objects"], [])
        self.assertTrue(connection.closed)
        self.assertEqual(len(connection.cursor_instance.queries), 1)
        self.assertIn("SysPlugIn", connection.cursor_instance.queries[0])


if __name__ == "__main__":
    unittest.main()
