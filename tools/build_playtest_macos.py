#!/usr/bin/env python3
"""Create an actual release .app with an official Godot 4.7 macOS template."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def run_checked(command, log_path, marker=None, allow_audio_exit_issue=False):
    result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, timeout=240)
    log_path.write_text(result.stdout)
    error_lines = [line for line in result.stdout.splitlines() if any(token in line for token in ["SCRIPT ERROR", "Parse Error", "ERROR:", "CHECK_FAIL"])]
    # This opt-in preview exception only accepts the independently isolated #17
    # resource-at-exit message. Script, export and gameplay failures still block.
    accepted_audio_lines = [line for line in error_lines if re.fullmatch(r"ERROR: [1-9][0-9]* resources still in use at exit \(run with --verbose for details\).", line)]
    bad = bool(error_lines) and not (allow_audio_exit_issue and error_lines == accepted_audio_lines)
    if result.returncode or bad or (marker and marker not in result.stdout):
        print(result.stdout[-6000:])
        raise RuntimeError(f"Failed: {log_path.name}; exit {result.returncode}")
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN") or shutil.which("godot"))
    parser.add_argument("--template", required=True, type=Path, help="macos.zip from official 4.7-stable export templates")
    parser.add_argument("--output", type=Path, default=ROOT / "exports/macos/DigDown.app")
    parser.add_argument("--preview-with-known-audio-issue", action="store_true", help="Produce a local preview even if the isolated #17 native audio exit error recurs; all other failures still block")
    parser.add_argument("--report", type=Path, default=ROOT / "art/qa/reports/phase21_build.json")
    args = parser.parse_args()
    if not args.godot or not args.template.is_file():
        parser.error("Provide a Godot 4.7 executable and matching macos.zip")
    version = subprocess.check_output([args.godot, "--version"], text=True).strip()
    if not version.startswith("4.7.stable"):
        parser.error("This build is pinned to Godot 4.7 stable")
    with zipfile.ZipFile(args.template) as template:
        if not any(name.endswith("godot_macos_release.universal") for name in template.namelist()):
            parser.error("Template does not contain a universal release binary")
    cached = ROOT / "exports/templates/macos.zip"
    cached.parent.mkdir(parents=True, exist_ok=True)
    (ROOT / "exports/.gdignore").touch()
    if cached.resolve() != args.template.resolve():
        shutil.copy2(args.template, cached)
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    logs = ROOT / ".godot/qa-2.0"
    logs.mkdir(parents=True, exist_ok=True)
    run_checked([args.godot, "--headless", "--editor", "--path", str(ROOT), "--quit"], logs / "playtest-import.log")
    run_checked([args.godot, "--headless", "--path", str(ROOT), "--export-release", "macOS Playtest", str(output)], logs / "playtest-export.log")
    plist = plistlib.loads((output / "Contents/Info.plist").read_bytes())
    binary = output / "Contents/MacOS" / plist["CFBundleExecutable"]
    # Passing development on purpose proves the actual release binary clamps it.
    verification = run_checked([str(binary), "--", "--profile=development", "--verify-playtest"], logs / "playtest-built-check.log", "PLAYTEST_BUILD_CHECK_PASS", args.preview_with_known_audio_issue)
    evidence = [line for line in verification.splitlines() if "PLAYTEST_BUILD_CHECK_PASS" in line]
    report = {
        "engine": version, "template_sha256": hashlib.sha256(cached.read_bytes()).hexdigest(),
        "app": str(output.relative_to(ROOT)) if output.is_relative_to(ROOT) else str(output),
        "architecture": "universal", "release_check": evidence,
        "native_audio": "blocked by #17; resource retention at exit observed" if "resources still in use at exit" in verification else "no native exit errors in this run; listening test pending",
        "human_playtest": "pending",
        "signing": "local ad-hoc; not notarized or published",
        "excluded": ["tests", "tools", "docs", "art/qa"],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(("PLAYTEST_PREVIEW_WITH_OPEN_AUDIO_ISSUE " if "resources still in use at exit" in verification else "PLAYTEST_BUILD_PASS ") + str(output))
    for line in evidence:
        print(line)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (RuntimeError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
