#!/usr/bin/env python3
"""Small affected-suite checks by default; one broad pass for a completed batch."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN") or shutil.which("godot"))
    parser.add_argument("--suite", default="discovery_flow,production_flow,save_roundtrip")
    parser.add_argument("--rc", action="store_true", help="Full units/soak + four gameplay flows + fresh replay + water benchmark")
    parser.add_argument("--worldgen-full", action="store_true", help="Explicitly rerun the expensive 288-seed matrix")
    args = parser.parse_args()
    if not args.godot:
        parser.error("Set GODOT_BIN or pass --godot /path/to/Godot 4.7")
    logs = ROOT / ".godot/qa-2.0"
    logs.mkdir(parents=True, exist_ok=True)
    checks = [("import", ["--editor", "--quit"], None)]
    unit_args = [] if args.rc else ["--", "--suite=" + args.suite]
    checks.append(("units", ["--script", "tests/test_runner.gd"] + unit_args, "TEST_SUMMARY"))
    if args.worldgen_full:
        checks.append(("worldgen288", ["--script", "tools/qa/batch_phase5_worldgen.gd"], "result=PASS"))
    if args.rc:
        for flow in ["core", "development", "collection", "campaign"]:
            profile = "development" if flow == "campaign" else "release"
            checks.append((flow, ["--script", f"tests/phase20_{flow}_smoke.gd", "--", "--profile=" + profile], f"PHASE20_{flow.upper()}_SMOKE_PASS"))
        checks += [
            ("replay7", ["--script", "tools/qa/verify_phase5_batch_replay.gd"], "PHASE5_FRESH_REPLAY_PASS"),
            ("water_performance", ["--script", "tools/qa/benchmark_phase7_water.gd"], "PHASE7_WATER_BENCHMARK"),
        ]
    results = []
    for name, command, marker in checks:
        try:
            run = subprocess.run([args.godot, "--headless", "--path", str(ROOT)] + command,
                                 cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True, timeout=240)
            output, code = run.stdout, run.returncode
        except subprocess.TimeoutExpired as error:
            output, code = str(error.stdout or "timeout"), -1
        (logs / (name + ".log")).write_text(output)
        bad = any(token in output for token in ["SCRIPT ERROR", "Parse Error", "FAIL |", "ERROR:", "SMOKE_FAIL", "REPLAY_FAIL"])
        passed = code == 0 and not bad and (marker is None or marker in output)
        evidence = [line for line in output.splitlines() if any(tag in line for tag in ["TEST_SUMMARY", "_PASS", "BENCHMARK", "ERROR:", "FAIL |"])]
        results.append({"check": name, "passed": passed, "exit": code, "evidence": evidence})
        print(("PASS " if passed else "FAIL ") + name, flush=True)
        for line in evidence[-3:]:
            print("  " + line, flush=True)
        if not passed:
            break
    document = {"created_utc": datetime.now(timezone.utc).isoformat(), "mode": "rc" if args.rc else "incremental",
                "checks": results, "human_playtest": "pending; automated evidence does not establish appeal",
                "worldgen_matrix": "rerun" if args.worldgen_full else "existing v7 288-seed report; rc verifies seven fresh hashes"}
    report = ROOT / "art/qa/reports/phase20_validation.json"
    if not args.rc:
        report = logs / "incremental.json"
    report.write_text(json.dumps(document, indent=2) + "\n")
    return 0 if len(results) == len(checks) and all(item["passed"] for item in results) else 1


if __name__ == "__main__":
    sys.exit(main())
