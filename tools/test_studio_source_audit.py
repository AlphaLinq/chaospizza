"""Run with python3 -m unittest discover -s tools -p 'test_studio_source_audit.py'."""
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

import studio_source_audit as audit


def inventory(*scripts):
    return dict(schema=1, algorithm=audit.ALGORITHM, roots=audit.ROOTS, scripts=list(scripts))


def script(name="One", source="return 1", class_name="ModuleScript"):
    value, length = audit.digest(source)
    return dict(path=["ReplicatedStorage", "Shared", name], className=class_name,
                hash=value, length=length)


class SourceAuditTests(unittest.TestCase):
    def test_build_decodes_both_source_encodings_and_utf8(self):
        root = ET.Element("roblox")
        service = ET.SubElement(root, "Item", {"class": "ReplicatedStorage"})
        properties = ET.SubElement(service, "Properties")
        ET.SubElement(properties, "string", {"name": "Name"}).text = "ReplicatedStorage"
        folder = ET.SubElement(service, "Item", {"class": "Folder"})
        properties = ET.SubElement(folder, "Properties")
        ET.SubElement(properties, "string", {"name": "Name"}).text = "Shared"
        for name, encoding, source in [("One", "string", 'return "árvíz 🍕 <>&"'),
                                        ("Two", "ProtectedString", "")]:
            item = ET.SubElement(folder, "Item", {"class": "ModuleScript"})
            properties = ET.SubElement(item, "Properties")
            ET.SubElement(properties, "string", {"name": "Name"}).text = name
            ET.SubElement(properties, encoding, {"name": "Source"}).text = source
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "build.rbxlx"
            ET.ElementTree(root).write(path, encoding="utf-8")
            result = audit.manifest(path)
        self.assertEqual(result["scripts"], [script(source='return "árvíz 🍕 <>&"'), script("Two", "")])
        self.assertGreater(result["scripts"][0]["length"], len('return "árvíz 🍕 <>&"'))
        self.assertEqual(audit.digest("abc"), (193485963, 3))

    def test_exact_inventory_passes_without_exposing_sources(self):
        expected = inventory(script())
        report = audit.compare(expected, copy.deepcopy(expected))
        self.assertTrue(report["ok"])
        self.assertEqual(report["matched"], 1)
        self.assertNotIn("return 1", str(report))

    def test_duplicate_correct_first_script_still_fails(self):
        expected = inventory(script())
        for second in [script(), script(source="return 2")]:
            report = audit.compare(expected, inventory(script(), second))
            self.assertFalse(report["ok"])
            self.assertEqual(report["matched"], 0)
            self.assertEqual(report["duplicates"][0]["instances"], 2)

    def test_missing_changed_extra_and_class_change(self):
        expected = inventory(script("One"), script("Two"), script("Three"))
        actual = inventory(script("Two", "return 2"), script("Three", class_name="Script"), script("Extra"))
        report = audit.compare(expected, actual)
        self.assertFalse(report["ok"])
        self.assertEqual([x["path"][-1] for x in report["missing"]], ["One"])
        self.assertEqual([x["path"][-1] for x in report["changed"]], ["Three", "Two"])
        self.assertEqual([x["path"][-1] for x in report["extra"]], ["Extra"])

    def test_path_segments_distinguish_dots_and_report_is_stable(self):
        first = script("A.B")
        second = script("B")
        second["path"].insert(-1, "A")
        expected = inventory(first)
        a = audit.compare(expected, inventory(first, second, script("Z")))
        b = audit.compare(expected, inventory(script("Z"), second, first))
        self.assertEqual(a, b)
        self.assertEqual(a["matched"], 1)
        self.assertEqual(len(a["extra"]), 2)

    def test_invalid_metadata_and_ambiguous_expected_build_are_rejected(self):
        for value in [dict(schema=9), inventory(dict(script(), hash=-1)),
                      inventory(dict(script(), source="must never enter a metadata report")),
                      inventory(dict(script(), length=True)), inventory(dict(script(), path="One"))]:
            with self.assertRaises(ValueError):
                audit.compare(inventory(script()), value)
        with self.assertRaises(ValueError):
            audit.compare(inventory(script(), script()), inventory(script()))

    def test_prepare_cannot_overwrite_the_build(self):
        with tempfile.TemporaryDirectory() as directory:
            build = Path(directory) / "build.rbxlx"
            build.write_text("keep this build")
            with patch("sys.argv", ["audit", "prepare", str(build), "--manifest", str(build),
                                    "--script", str(Path(directory) / "audit.luau")]), \
                    patch("builtins.print"):
                self.assertEqual(audit.main(), 2)
            self.assertEqual(build.read_text(), "keep this build")

    def test_cli_exit_codes_follow_audit_status(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            expected = Path(directory) / "expected.json"
            actual = Path(directory) / "actual.json"
            expected.write_text(json.dumps(inventory(script())))
            for rows, code in [(inventory(script()), 0), (inventory(), 1), (dict(schema=9), 2)]:
                actual.write_text(json.dumps(rows))
                with patch("sys.argv", ["audit", "compare", str(expected), str(actual)]), \
                        patch("builtins.print"):
                    self.assertEqual(audit.main(), code)


if __name__ == "__main__":
    unittest.main()
