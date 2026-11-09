"""Scheduling fixtures must never overwrite the production configuration."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import perf_fixture


class PerfFixtureTests(unittest.TestCase):
    def test_single_fixture_has_one_config_and_cloned_timing(self):
        root = Path(perf_fixture.__file__).resolve().parents[1]
        production = root / "src/shared/Config/Tuning.luau"
        before = production.read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            with patch("sys.argv", ["fixture", directory]), contextlib.redirect_stdout(io.StringIO()):
                perf_fixture.main()
            project = json.loads((Path(directory) / "fixture.project.json").read_text())
            shared = project["tree"]["ReplicatedStorage"]["Shared"]
            self.assertNotIn("$path", shared)
            config = shared["Config"]
            self.assertNotIn("$path", config)
            self.assertEqual(config["PerfProductionTuning"]["$path"], str(production))
            self.assertEqual(config["Tuning"]["$path"], str((Path(directory) / "Tuning.luau").resolve()))
            self.assertIn("90, 90", (Path(directory) / "Tuning.luau").read_text())
            self.assertNotIn("PerfProductionEvents", config)
        self.assertEqual(production.read_bytes(), before)

    def test_combo_keeps_the_production_events_file_unchanged(self):
        root = Path(perf_fixture.__file__).resolve().parents[1]
        production = root / "src/shared/Config/Events.luau"
        before = production.read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            with patch("sys.argv", ["fixture", directory, "--combo", "bubbles-tornado"]), \
                    contextlib.redirect_stdout(io.StringIO()):
                perf_fixture.main()
            source = (Path(directory) / "Events.luau").read_text()
            self.assertIn('["BubbleStorm"] = true', source)
            self.assertIn('["Tornado"] = true', source)
            self.assertIn("copy.enabled = allowed[event.id] == true", source)
        self.assertEqual(production.read_bytes(), before)

    def test_repository_output_is_rejected_before_writing(self):
        root = Path(perf_fixture.__file__).resolve().parents[1]
        production = root / "src/shared/Config/Tuning.luau"
        before = production.read_bytes()
        with patch("sys.argv", ["fixture", str(production.parent)]), \
                contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as failure:
            perf_fixture.main()
        self.assertEqual(failure.exception.code, 2)
        self.assertEqual(production.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
