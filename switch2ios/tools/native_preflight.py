#!/usr/bin/env python3
"""Offline header-only NSO compatibility audit, with optional local nxpatch rewrite."""
import argparse
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

VALID_NAME = re.compile(r"^(main|sdk|subsdk[0-9]+)$")
MUSH8_MODULES = {"main", "subsdk0", "sdk"}
# Mush8 crates/nxhost/src/nvn/mod.rs currently contains one supported SDK table.
MUSH8_NVN_IDS = {"ba520906609c503227871a314a94fb5f6ccbe444"}

def nso_metadata(path):
    with path.open("rb") as f:
        b = f.read(0x100)
    length = path.stat().st_size
    if len(b) != 0x100 or b[:4] != b"NSO0":
        raise ValueError("invalid NSO header")
    flags = struct.unpack_from("<I", b, 0x0c)[0]
    segs = []
    for i, name in enumerate(("text", "ro", "data")):
        foff, voff, size = struct.unpack_from("<III", b, 0x10 + i * 0x10)
        compressed = bool(flags & (1 << i))
        n = struct.unpack_from("<I", b, 0x60 + i * 4)[0] if compressed else size
        if foff > length or n > length - foff:
            raise ValueError(name + " segment outside file")
        segs.append({"name": name, "virtual_offset": voff, "unpacked_bytes": size,
                     "compressed": compressed})
    return {
        "build_id": b[0x40:0x54].hex(),
        "size_bytes": length,
        "bss_bytes": struct.unpack_from("<I", b, 0x3c)[0],
        "segments": segs
    }

def exefs_folder(folder):
    for candidate in (folder / "ExeFS", folder / "exefs", folder):
        if candidate.is_dir():
            return candidate
    raise ValueError("No ExeFS directory")

def analyze(folder, profile):
    root = exefs_folder(folder)
    modules = []
    for path in sorted(root.iterdir()):
        if path.is_file() and VALID_NAME.fullmatch(path.name):
            try:
                modules.append({"name": path.name, "valid": True, **nso_metadata(path)})
            except (ValueError, OSError) as exc:
                modules.append({"name": path.name, "valid": False, "error": str(exc)})
    valid = {m["name"]: m for m in modules if m["valid"]}
    missing = [n for n in ("main", "sdk") if n not in valid]
    sdk = valid.get("sdk", {}).get("build_id")
    order = (["main"] if "main" in valid else []) + sorted(
        n for n in valid if n.startswith("subsdk")) + (
        ["sdk"] if "sdk" in valid else [])
    return {
        "schema_version": 1, "game": profile["name"],
        "title_id_expected": profile["title_id"],
        "game_version": "not verified", "modules": modules,
        "module_order_suggested": order,
        "missing_required": missing,
        "matches_mush8_fixed_module_set": set(valid) == MUSH8_MODULES,
        "matches_mush8_sdk_table": sdk in MUSH8_NVN_IDS,
        "first_blocker": ("Required modules missing" if missing else
            "Unknown NVN SDK build" if sdk not in MUSH8_NVN_IDS else
            "Guest OS services and graphics untested"),
        "playable": False,
        "privacy": "No game payload, ROM path, extracted executable or console keys."
    }

def rewrite(patcher, root, out, report):
    if not patcher.is_file():
        raise ValueError("nxpatch not found")
    inputs = [root / m["name"] for m in report["modules"] if m["valid"]]
    if not inputs:
        raise ValueError("No valid modules to rewrite")
    out.mkdir(parents=True, exist_ok=True)
    cmd = [str(patcher.resolve()), "rewrite", "--out", str(out.resolve())] + [str(p.resolve()) for p in inputs]
    r = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    matches = re.findall(r"^(main|sdk|subsdk[0-9]+):\s+(\d+) patches", r.stdout, re.MULTILINE)
    return {"attempted": True, "success": r.returncode == 0,
            "exit_code": r.returncode, "patch_counts": {k: int(v) for k, v in matches},
            "note": "Patched binaries stay local, not in this report."}

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--exefs", required=True, type=Path)
    ap.add_argument("--profile", type=Path,
                    default=Path(__file__).resolve().parents[1] / "profiles" / "odyssey.json")
    ap.add_argument("--report", required=True, type=Path)
    ap.add_argument("--rewrite", action="store_true")
    ap.add_argument("--nxpatch", type=Path)
    ap.add_argument("--patched-out", type=Path)
    a = ap.parse_args(argv)
    try:
        profile = json.loads(a.profile.read_text(encoding="utf-8"))
        if not re.fullmatch(r"[A-Fa-f0-9]{16}", profile["title_id"]):
            raise ValueError("Invalid profile title ID")
        report = analyze(a.exefs, profile)
        if a.rewrite:
            if not (a.nxpatch and a.patched_out):
                raise ValueError("--rewrite needs --nxpatch and --patched-out")
            report["rewriter"] = rewrite(a.nxpatch, exefs_folder(a.exefs), a.patched_out, report)
        a.report.parent.mkdir(parents=True, exist_ok=True)
        a.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        print("Preflight JSON written; no game data or keys included")
        print("Modules:", ", ".join(report["module_order_suggested"]) or "none")
        print("Initial blocker:", report["first_blocker"])
        if report["missing_required"] or any(not m["valid"] for m in report["modules"]):
            return 3
        if a.rewrite and not report["rewriter"]["success"]:
            return 2
        return 0
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as e:
        print("Preflight failed: " + str(e), file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
