import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from server import app


class MobileTxnTests(unittest.TestCase):
    def test_pc_plugin_uses_sysparameter_for_one_to_many_objects(self):
        class Cursor:
            def execute(self, sql, params=()):
                self.parameter = params[0]

            def fetchall(self):
                return [{"ParameterValue": "MobileReceive"}, {"ParameterValue": "MobileCheck"}]

        plugin = {
            "PluginCommand": "MREC",
            "PluginParameter": "[MOBILETXN:移动收货][N]",
            "Channel": "PC",
        }
        cursor = Cursor()
        self.assertEqual(app.mobile_txn_lookup_names(cursor, plugin), ["MobileReceive", "MobileCheck"])
        self.assertEqual(cursor.parameter, plugin["PluginParameter"])

    def test_pc_plugin_falls_back_to_mobiletxn_tag(self):
        class Cursor:
            def execute(self, sql, params=()):
                pass

            def fetchall(self):
                return []

        plugin = {"PluginCommand": "MREC", "PluginParameter": "x[mobiletxn: MobileReceive ]y"}
        self.assertEqual(app.mobile_txn_lookup_names(Cursor(), plugin), ["MobileReceive"])

    def test_ordroid_plugin_uses_dedicated_one_to_many_configuration(self):
        class Cursor:
            def __init__(self):
                self.queries = []

            def execute(self, sql, params=()):
                self.queries.append((sql, params))
                if "INFORMATION_SCHEMA.COLUMNS" in sql:
                    self.rows = [
                        {"COLUMN_NAME": "OrDroidPluginId"},
                        {"COLUMN_NAME": "MobileObjectId"},
                        {"COLUMN_NAME": "Sequence"},
                    ]
                else:
                    self.rows = [{"ObjectName": "MobileReceive"}, {"ObjectName": "MobileCheck"}]

            def fetchall(self):
                return self.rows

        cursor = Cursor()
        plugin = {"OrDroidPluginId": "ODP100000001", "PluginCommand": "MREC", "Channel": "OrDroid"}
        self.assertEqual(app.ordroid_mobile_object_names(cursor, plugin), ["MobileReceive", "MobileCheck"])
        self.assertIn("JOIN dbo.MobileObject", cursor.queries[-1][0])
        self.assertIn("ORDER BY c.Sequence", cursor.queries[-1][0])
        self.assertEqual(cursor.queries[-1][1], ("ODP100000001",))

    def test_mobile_layout_is_fixed_and_keeps_fields_separate_from_methods(self):
        sections = {
            "object": {
                "table": "MobileObject",
                "columns": [],
                "rows": [{
                    "MobileObjectName": "MobileReceive",
                    "MobileObjectDesc": "移动收货",
                    "ColumnCount": 4,
                    "IsUserUI": 1,
                }],
            },
            "parameters": {
                "table": "MobileObjectParameter",
                "columns": [],
                "rows": [
                    {"MobileObjectParameterId": "MOP100000002", "MobileObjectParameterName": "LotNo", "ParameterSequence": "2"},
                    {"MobileObjectParameterId": "MOP100000001", "MobileObjectParameterName": "Qty", "ParameterSequence": "1"},
                ],
            },
            "methods": {
                "table": "MobileObjectMethod",
                "columns": [],
                "rows": [{"MobileObjectMethodId": "MOM100000001", "MobileObjectMethodName": "Submit", "SQLDoTxn": "MobileReceiveSubmit"}],
            },
            "specifications": {"table": "MobileObjectSpecification", "columns": [], "rows": []},
        }

        target = app.configured_txn_object(
            sections, {}, "MobileObjectName", "MobileObjectDesc", fixed_layout=True,
        )
        group = target["style"]["main"]["groups"][0]
        self.assertEqual(group["columns"], 4)
        self.assertFalse(group["custom"])
        self.assertEqual([field["name"] for field in group["fields"]], ["Qty", "LotNo"])
        self.assertEqual(group["fields"][0]["id"], "MOP100000001")
        self.assertEqual(group["methods"][0]["name"], "Submit")
        self.assertEqual(group["methods"][0]["id"], "MOM100000001")

    def test_mobile_pull_expands_objects_and_writes_methods_and_value_lists(self):
        objects = [
            {
                "MobileObjectId": "MOB100000001",
                "MobileObjectName": "MobileReceive",
                "MobileObjectDesc": "移动收货",
                "ColumnCount": 2,
                "IsUserUI": 1,
            },
            {
                "MobileObjectId": "MOB100000002",
                "MobileObjectName": "MobileCheck",
                "MobileObjectDesc": "移动点检",
                "ColumnCount": 3,
            },
        ]
        rows_by_table = {
            "MobileObject": objects,
            "MobileObjectParameter": [{
                "MobileObjectId": "MOB100000001",
                "MobileObjectParameterName": "LotNo",
                "ParameterDesc": "批次",
                "ValueList": "MobileLotValueList",
            }],
            "MobileObjectMethod": [{
                "MobileObjectId": "MOB100000001",
                "MobileObjectMethodName": "Submit",
                "MethodDesc": "提交",
                "SQLDoTxn": "MobileReceiveSubmit",
            }],
            "MobileObjectSpecification": [],
        }
        templates = {
            "MobileObject": objects[0],
            "MobileObjectParameter": rows_by_table["MobileObjectParameter"][0],
            "MobileObjectMethod": rows_by_table["MobileObjectMethod"][0],
            "MobileObjectSpecification": {"MobileObjectId": "", "SpecificationName": ""},
        }

        class Cursor:
            def __init__(self):
                self.rows = []
                self.description = []

            def execute(self, sql, params=()):
                self.rows = []
                self.description = []
                if "FROM dbo.SysParameter" in sql:
                    self.rows = [{"ParameterValue": "MobileReceive"}, {"ParameterValue": "MobileCheck"}]
                elif sql.startswith("SELECT * FROM dbo."):
                    table = sql.split("dbo.", 1)[1].split(" ", 1)[0]
                    if table == "MobileObject":
                        self.rows = [
                            dict(row) for row in rows_by_table[table]
                            if params[0] in {row["MobileObjectName"], row["MobileObjectDesc"]}
                        ]
                    else:
                        self.rows = [dict(row) for row in rows_by_table[table] if row["MobileObjectId"] == params[0]]
                    self.description = [(name,) for name in templates[table]]
                elif "FROM sys.sql_modules" in sql:
                    procedure = params[0].removeprefix("dbo.")
                    self.rows = [{"definition": f"CREATE PROC {procedure} AS SELECT 1"}]

            def fetchall(self):
                return self.rows

        plugin = {
            "PluginCommand": "MREC",
            "PluginName": "移动收货",
            "PluginDescription": "移动收货事务",
            "PluginFileName": "PluginMESMobile.dll",
            "PluginParameter": "[MOBILETXN:移动收货][N]",
            "MetadataId": "",
            "Channel": "PC",
        }
        with tempfile.TemporaryDirectory() as folder, patch.object(app, "LIBRARY", Path(folder)):
            library = Path(folder) / "jiban" / "MREC"
            library.mkdir(parents=True)
            document = app.pull_mobile_txn(
                library,
                app.skeleton_pack("jiban", "MREC"),
                "jiban-mes-prod",
                "jiban",
                "MREC",
                Cursor(),
                plugin,
            )

            self.assertEqual([item["name"] for item in document["objects"]], ["MobileReceive", "MobileCheck"])
            self.assertEqual(document["kind"], "移动事务对象")
            self.assertEqual(document["channel"], "PC")
            target = document["objects"][0]
            group = target["style"]["main"]["groups"][0]
            self.assertFalse(group["custom"])
            self.assertEqual(group["methods"][0]["definition"], "CREATE PROC MobileReceiveSubmit AS SELECT 1")
            self.assertEqual(target["valueLists"][0]["sql"], "CREATE PROC MobileLotValueList AS SELECT 1")
            self.assertEqual(len(document["mobile"]["objects"]), 2)
            self.assertTrue((library / "MobileReceiveSubmit.sql").is_file())
            self.assertTrue((library / "MobileLotValueList.sql").is_file())

    def test_missing_ordroid_document_does_not_look_up_pc_or_sysmetadata(self):
        class Cursor:
            def __init__(self):
                self.queries = []

            def execute(self, sql, params=()):
                self.queries.append(sql)

            def fetchall(self):
                return [{
                    "OrDroidPluginId": "ODP100000001",
                    "PluginCommand": "MREC",
                    "PluginName": "移动收货",
                    "PluginDescription": "移动收货",
                    "PluginFileName": "PluginOrDroid.dll",
                    "PluginParameter": "",
                    "MetadataId": "",
                }]

        class Connection:
            def __init__(self):
                self.cursor_instance = Cursor()

            def cursor(self, as_dict=False):
                return self.cursor_instance

            def close(self):
                pass

        with tempfile.TemporaryDirectory() as folder, patch.object(app, "LIBRARY", Path(folder)), patch.object(
            app, "open_database", return_value=Connection()
        ):
            document = app.function_pack("jiban", "MREC", "OrDroid")

        self.assertEqual(document["kind"], "移动事务对象")
        self.assertEqual(document["channel"], "OrDroid")
        self.assertEqual(document["application"], "OrDroid")
        self.assertEqual(document["objects"], [])


if __name__ == "__main__":
    unittest.main()
