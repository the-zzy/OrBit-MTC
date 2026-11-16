import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi import HTTPException

from server import app


class FunctionIndexTests(unittest.TestCase):
    def test_bundled_indexes_are_readable(self):
        rows = app.read_function_index()

        self.assertEqual(set(rows), {"jiban", "zongzhuang", "tongxin", "guangyuan-mes", "guangyuan-wms"})
        self.assertTrue(all(isinstance(items, list) and items for items in rows.values()))

    def test_write_only_changes_the_selected_plant(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "jiban.js").write_text("export default []\n", encoding="utf-8")
            (root / "tongxin.js").write_text('export default [{"c":"KEEP"}]\n', encoding="utf-8")
            with patch.object(app, "FUNCTION_INDEX_DIR", root):
                app.write_function_rows("jiban", [{"c": "NEW"}])

                self.assertEqual(app.read_function_rows("jiban"), [{"c": "NEW"}])
                self.assertEqual(app.read_function_rows("tongxin"), [{"c": "KEEP"}])

    def test_invalid_or_unknown_plant_is_not_found(self):
        with self.assertRaises(HTTPException) as raised:
            app.read_function_rows("../secrets")
        self.assertEqual(raised.exception.status_code, 404)

        with self.assertRaises(HTTPException) as raised:
            app.read_function_rows("unknown")
        self.assertEqual(raised.exception.status_code, 404)
    def test_tagged_transactions_must_resolve_to_an_existing_object(self):
        txn_names, txn_descriptions = app.object_name_lookup(
            [
                {"MESTxnObjectName": "ImportExcelBatch", "MESTxnObjectDesc": "导入数据批量"},
                {"MESTxnObjectName": "DC MoreBarcodeCollect", "MESTxnObjectDesc": "多码合一采集"},
                {"MESTxnObjectName": "DC MoreBarcodeCollect Auto", "MESTxnObjectDesc": "多码合一采集"},
            ],
            "MESTxnObjectName", "MESTxnObjectDesc",
        )
        mobile_names, mobile_descriptions = app.object_name_lookup([], "MobileObjectName", "MobileObjectDesc")
        txn_parameters = app.txn_parameter_lookup([
            {"ParameterName": "[MESTXN:批量导入EXCEL][N]", "ParameterValue": "ImportExcelBatch"},
            {"ParameterName": "[MESTXN:多码合一采集][N]", "ParameterValue": "DC MoreBarcodeCollect"},
            {"ParameterName": "[MESTXN:多码][N]", "ParameterValue": "DC MoreBarcodeCollect"},
            {"ParameterName": "[MESTXN:多码][N]", "ParameterValue": "DC MoreBarcodeCollect Auto"},
        ])

        self.assertEqual(app.tagged_object_name(
            "PluginMESStaticTxn.dll", "[MESTXN:ImportExcelBatch]",
            txn_names, txn_descriptions, mobile_names, mobile_descriptions,
        ), "ImportExcelBatch")
        self.assertEqual(app.tagged_object_name(
            "PluginMESStaticTxn.dll", "[MESTXN:批量导入EXCEL][N]",
            txn_names, txn_descriptions, mobile_names, mobile_descriptions,
        ), "")
        self.assertEqual(app.tagged_object_name(
            "PluginMESStaticTxn.dll", "[MESTXN:批量导入EXCEL][N]",
            txn_names, txn_descriptions, mobile_names, mobile_descriptions, txn_parameters,
        ), "ImportExcelBatch")
        self.assertEqual(app.tagged_object_name(
            "PluginMESStaticTxn.dll", "[MESTXN:多码合一采集][N]",
            txn_names, txn_descriptions, mobile_names, mobile_descriptions, txn_parameters,
        ), "DC MoreBarcodeCollect")
        self.assertEqual(app.tagged_object_name(
            "PluginMESStaticTxn.dll", "[MESTXN:多码][N]",
            txn_names, txn_descriptions, mobile_names, mobile_descriptions, txn_parameters,
        ), "DC MoreBarcodeCollect / DC MoreBarcodeCollect Auto")
        self.assertIsNone(app.tagged_object_name(
            "Plugin Standard.dll", "", txn_names, txn_descriptions, mobile_names, mobile_descriptions,
        ))

    def test_mobile_sysparameter_mapping_expands_all_object_names(self):
        mobile_names, mobile_descriptions = app.object_name_lookup(
            [
                {"MobileObjectName": "MobileReceive", "MobileObjectDesc": "移动收货"},
                {"MobileObjectName": "MobileCheck", "MobileObjectDesc": "移动点检"},
            ],
            "MobileObjectName", "MobileObjectDesc",
        )
        parameters = app.txn_parameter_lookup([
            {"ParameterName": "[MOBILETXN:移动收货][N]", "ParameterValue": "MobileReceive"},
            {"ParameterName": "[MOBILETXN:移动收货][N]", "ParameterValue": "移动点检"},
        ])

        self.assertEqual(app.tagged_object_name(
            "PluginMESMobile.dll", "[MOBILETXN:移动收货][N]",
            {}, {}, mobile_names, mobile_descriptions, parameters,
        ), "MobileReceive / MobileCheck")


if __name__ == "__main__":
    unittest.main()
