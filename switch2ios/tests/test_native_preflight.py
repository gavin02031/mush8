"""Synthetic test data only. No copyrighted Nintendo content required."""
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import native_preflight as preflight

PROFILE = {"name": "Super Mario Odyssey", "title_id": "0100000000010000"}

def make_nso(file, build_id=None, magic=b"NSO0"):
    b = bytearray(0x200)
    b[:4] = magic
    b[0x40:0x54] = build_id or bytes.fromhex("11" * 20)
    for i in range(3):
        struct.pack_into("<III", b, 0x10 + i * 0x10, 0x100 + 0x20*i, 0x20*i, 0x10)
    struct.pack_into("<I", b, 0x3c, 32)
    file.write_bytes(b)

class TestPreflight(unittest.TestCase):
    def test_odyssey_unknown_sdk(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t)
            (p / "ExeFS").mkdir()
            make_nso(p / "ExeFS/main")
            make_nso(p / "ExeFS/sdk")
            r = preflight.analyze(p, PROFILE)
            self.assertEqual(r["module_order_suggested"], ["main", "sdk"])
            self.assertFalse(r["matches_mush8_sdk_table"])
            self.assertFalse(r["playable"])
            self.assertNotIn(t, json.dumps(r))
    def test_known_mk8_layout(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t)
            make_nso(p / "main")
            make_nso(p / "sdk", bytes.fromhex("ba520906609c503227871a314a94fb5f6ccbe444"))
            make_nso(p / "subsdk0")
            r = preflight.analyze(p, PROFILE)
            self.assertTrue(r["matches_mush8_fixed_module_set"])
            self.assertTrue(r["matches_mush8_sdk_table"])
            self.assertEqual(r["module_order_suggested"], ["main", "subsdk0", "sdk"])
    def test_rejects_corrupt_nso(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t)
            make_nso(p / "main", magic=b"NOPE")
            make_nso(p / "sdk")
            r = preflight.analyze(p, PROFILE)
            self.assertEqual(r["missing_required"], ["main"])
            self.assertFalse(r["modules"][0]["valid"])
    def test_rejects_out_of_bounds_segment(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t) / "main"
            make_nso(p)
            b = bytearray(p.read_bytes())
            struct.pack_into("<I", b, 0x10, 0x1000)
            p.write_bytes(b)
            with self.assertRaises(ValueError):
                preflight.nso_metadata(p)

if __name__ == "__main__":
    unittest.main()
