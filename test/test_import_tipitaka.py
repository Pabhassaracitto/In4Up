"""Regression tests for cross-language source-key joins in import_tipitaka.py."""

import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

import import_tipitaka  # noqa: E402


class TipitakaImportJoinTest(unittest.TestCase):
    def test_translation_joins_normalized_table_and_numeric_source_key(self) -> None:
        with tempfile.TemporaryDirectory(prefix="tipitaka-import-test-") as temp:
            root = Path(temp)
            pali_path = root / "pali.sqlite"
            pali = sqlite3.connect(pali_path)
            pali.execute(
                """CREATE TABLE MN01M_MUL (
                     id INTEGER PRIMARY KEY,
                     reference TEXT NOT NULL,
                     pali_text TEXT NOT NULL
                   )"""
            )
            pali.execute(
                "INSERT INTO MN01M_MUL VALUES (?, ?, ?)",
                (1, "MN 1", "Evaṃ me sutaṃ."),
            )
            pali.commit()
            pali.close()

            translation_path = root / "vietnamese.sqlite"
            translation = sqlite3.connect(translation_path)
            translation.execute(
                """CREATE TABLE mn01m_mul (
                     id TEXT PRIMARY KEY,
                     reference TEXT NOT NULL,
                     text TEXT NOT NULL
                   )"""
            )
            translation.execute(
                "INSERT INTO mn01m_mul VALUES (?, ?, ?)",
                ("0001", "unmatched reference", "Nội dung tiếng Việt đã khớp."),
            )
            translation.commit()
            translation.close()

            target = sqlite3.connect(root / "target.sqlite")
            import_tipitaka.build_target_schema(target)
            _, key_map, reference_map = import_tipitaka.import_pali(
                target,
                pali_path,
            )
            changed = import_tipitaka.import_translation(
                target,
                translation_path,
                "vi",
                key_map,
                reference_map,
            )

            self.assertEqual(changed, 1)
            self.assertEqual(
                target.execute(
                    "SELECT pali_text, translation_vi FROM tipitaka_segments"
                ).fetchone(),
                ("Evaṃ me sutaṃ.", "Nội dung tiếng Việt đã khớp."),
            )
            self.assertEqual(
                import_tipitaka.source_join_key("MN01M_MUL", "001"),
                import_tipitaka.source_join_key("mn01m_mul", 1),
            )
            target.close()


if __name__ == "__main__":
    unittest.main()
