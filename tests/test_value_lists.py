import unittest

from server.app import value_list_names


class ValueListNameTests(unittest.TestCase):
    def test_query_fields_collect_visible_value_lists_without_duplicates(self):
        document = {
            "groups": [
                {
                    "hidden": False,
                    "fields": [
                        {"hidden": False, "valueList": True, "valueListName": "QueryFactory"},
                        {"hidden": False, "valueList": True, "valueListName": "queryfactory"},
                        {"hidden": False, "valueList": False, "valueListName": "NotUsed"},
                    ],
                },
                {
                    "hidden": False,
                    "fields": [
                        {"hidden": False, "valueList": True, "valueListName": "QueryWorkshop"},
                    ],
                },
            ]
        }

        self.assertEqual(value_list_names(document), ["QueryFactory", "QueryWorkshop"])

    def test_hidden_groups_fields_and_empty_names_are_ignored(self):
        document = {
            "groups": [
                {
                    "hidden": True,
                    "fields": [{"hidden": False, "valueList": True, "valueListName": "HiddenGroup"}],
                },
                {
                    "hidden": False,
                    "fields": [
                        {"hidden": True, "valueList": True, "valueListName": "HiddenField"},
                        {"hidden": False, "valueList": True, "valueListName": "  "},
                    ],
                },
            ]
        }

        self.assertEqual(value_list_names(document), [])


if __name__ == "__main__":
    unittest.main()
