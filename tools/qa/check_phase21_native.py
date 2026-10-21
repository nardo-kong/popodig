#!/usr/bin/env python3
"""Rendered experience checks; report #17 separately, never hide other errors."""
import argparse
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    checks = []
    logs = ROOT / '.godot/qa-2.0'
    logs.mkdir(parents=True, exist_ok=True)
    for locale, large in [('en', False), ('zh', False), ('en', True), ('zh', True), ('entry', False)]:
        script = 'entry' if locale == 'entry' else 'experience'
        name = f'phase21_{script}_{locale}_{1920 if large else 1280}'
        command = [args.godot, '--path', str(ROOT), '--quit-after', '1200', '--script', f'tests/phase21_{script}_smoke.gd', '--', '--profile=release', '--capture', '--locale=' + locale]
        if large:
            command.append('--large')
        run = subprocess.run(command, capture_output=True, text=True, timeout=120)
        output = run.stdout + run.stderr
        (logs / (name + '.log')).write_text(output)
        errors = [line for line in output.splitlines() if any(token in line for token in ['SCRIPT ERROR', 'Parse Error', 'ERROR:', 'SMOKE_FAIL'])]
        unexpected = [line for line in errors if not re.fullmatch(r'ERROR: [1-9][0-9]* resources still in use at exit \(run with --verbose for details\).', line)]
        marker = f'PHASE21_{script.upper()}_SMOKE_PASS'
        passed = run.returncode == 0 and marker in output and not unexpected
        checks.append({'check': name, 'functional_pass': passed, 'native_cleanup_pass': not errors,
                       'evidence': [line for line in output.splitlines() if marker in line or 'ERROR:' in line]})
        print(json.dumps(checks[-1]), flush=True)
        if not passed:
            print(output[-4000:])
            break
    (ROOT / 'art/qa/reports/phase21_native.json').write_text(json.dumps(checks, indent=2) + '\n')
    return 0 if len(checks) == 5 and all(check['functional_pass'] for check in checks) else 1


if __name__ == '__main__':
    raise SystemExit(main())
