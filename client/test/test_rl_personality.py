"""ラボの版拒否と報告集計。Godotの起動・育成・本採用ファイルの書き換えはしない。"""
import contextlib
import csv
import io
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "lab" / "rl"))
import train
import godot_env


class PersonalityReports(unittest.TestCase):
    def row(self, value, keep=(0.9, 0.5, None), learning=True):
        return {"learning": learning, "seat": True, "frame": {k: value for k in train.BEHAVIORS},
                "points": {k: value for k in train.POINTS}, "stick_share": value,
                "draft_share": value, "rear_share": value, "contact_share": value,
                "notch_changes": 4, "line_changes": 2, "keep_stamina": list(keep),
                "time": 10, "winner_time": 10, "boost_remaining_m": [25], "dash_uses": 1,
                "boost_uses": 1, "stamina_left": 0.2, "spurt_hits": 1, "opening_boosts": 0, "spurt_misses": 0}

    def test_group_boundaries_and_missing_checkpoints(self):
        rows = [self.row(0.6), self.row(0.2), self.row(-0.3), self.row(0.5)]
        summary = train.personality_summary(rows)
        self.assertEqual(summary["こだわり高・順位組の距離割合"], 0.6)
        self.assertEqual(summary["こだわり低・順位組の距離割合"], -0.05)
        self.assertEqual(summary["接触高・接触距離割合"], 0.55)
        self.assertEqual(summary["接触低・接触距離割合"], -0.3)
        self.assertEqual(summary["温存高・75%体力"], "")
        self.assertEqual(summary["温存高・75%体力標本数"], 0)
        self.assertEqual(summary["温存高・25%体力標本数"], 1)
        self.assertEqual(train.personality_summary([])["ノッチ変更回数"], "")

    def test_report_csv_and_terminal_exclude_opponents_and_keep_point_signs(self):
        settings = {"train": {"report_every_races": 2, "save_version_every_min": 3, "save_latest_every_min": 4},
                    "demo": {"reload_every_steps": 100}}
        with tempfile.TemporaryDirectory() as directory:
            callback = train.Progress(Path(directory), settings)
            callback.recent.extend([{"results": [self.row(0.6), self.row(-0.2), self.row(999, learning=False)]},
                                    {"results": [self.row(0.2)]}])
            callback.seen = 2
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                callback._write()
            with callback.csv_path.open(newline="") as f:
                reader = csv.DictReader(f)
                row = next(reader)
                self.assertEqual(reader.fieldnames, train.COLUMNS)
            for label in train.POINTS.values():
                self.assertAlmostEqual(float(row[label + "点"]), 0.2)
            self.assertAlmostEqual(float(row["合計点"]), 2.6)
            self.assertEqual(row["学ぶ席の走数"], "3")
            self.assertEqual(row["75%体力"], "")
            self.assertIn("マイペース", output.getvalue())
            self.assertIn("高い組", output.getvalue())
            self.assertIn("—", output.getvalue())
            self.assertEqual(len(train.COLUMNS), len(set(train.COLUMNS)))
            for old in ["性格の順位に合った割合", "風よけが性格に合った割合", "線で体力が目安より少ない割合", "残り25%の線の体力"]:
                self.assertNotIn(old, row)

    def test_csv_migration_uses_column_names_and_leaves_new_measurements_blank(self):
        settings = {"train": {"report_every_races": 2, "save_version_every_min": 3, "save_latest_every_min": 4},
                    "demo": {"reload_every_steps": 100}}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "progress.csv"
            path.write_text("日時,風よけが性格に合った割合,レース数\n過去,0.8,200\n")
            train.Progress(Path(directory), settings)
            with path.open(newline="") as f:
                rows = list(csv.DictReader(f))
            self.assertEqual(rows[0]["レース数"], "200")
            self.assertEqual(rows[0]["こだわり点"], "")
            self.assertNotIn("風よけが性格に合った割合", rows[0])

    def test_model_versions_are_explicit_and_missing_means_legacy(self):
        godot_env.require_model_version(SimpleNamespace(), 1)
        godot_env.require_model_version(SimpleNamespace(observation_version=2), 2)
        for model in [SimpleNamespace(), SimpleNamespace(observation_version=1), SimpleNamespace(observation_version=3)]:
            with self.assertRaisesRegex(ValueError, "観測の版"):
                godot_env.require_model_version(model, 2)

    def test_removed_override_fields_are_rejected(self):
        # 版の現値にも報酬の現値にも依存させない。
        from unittest.mock import patch
        base = {"observation_version": 17, "reward": {"style": {}}}
        with patch.object(godot_env, "load_settings", return_value=base):
            godot_env.validate_settings(base)
            for key in ("group", "stamina"):
                with self.assertRaises(ValueError):
                    godot_env.validate_settings({**base, "reward": {"style": {}, key: {}}})
            for key in ("place", "draft", "mid_from", "mid_to", "draft_at_least"):
                with self.assertRaises(ValueError):
                    godot_env.validate_settings({**base, "reward": {"style": {key: 1}}})


if __name__ == "__main__":
    unittest.main()
