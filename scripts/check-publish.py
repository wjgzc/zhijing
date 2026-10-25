"""Fail publication checks without displaying secret values."""
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SECRET_PATTERNS = [
    ('private key', re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----')),
    ('provider credential', re.compile(rb'\b(?:sk-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16})\b')),
    ('signing password', re.compile(rb'["\'](?:keyPassword|storePassword)["\']\s*:\s*["\'][^"\'\r\n]+["\']')),
]


def main():
    result = subprocess.run(['git','ls-files','-z','-c','-o','--exclude-standard'],
                            cwd=ROOT, capture_output=True, check=True)
    names = sorted(set(name.decode('utf-8') for name in result.stdout.split(b'\0') if name))
    forbidden_suffixes = {'.pem','.key','.p12','.pfx','.cer','.p7b','.jks','.keystore',
                          '.parquet','.npz','.npy','.csv','.tsv','.zip','.hap','.app'}
    failures = []
    count = 0
    for name in names:
        file = ROOT/name
        if not file.is_file():
            continue
        count += 1
        parts = Path(name).parts
        if (file.suffix.lower() in forbidden_suffixes or
            file.name.startswith('.env') and file.name != '.env.example' or
            any(part in {'HarmonyOS-KT','research','history','.idea','.hvigor','node_modules','oh_modules','build'} for part in parts)):
            failures.append((name,'local/private/research or generated file'))
        if file.suffix.lower() in {'.png','.pt'}:
            continue
        data = file.read_bytes()
        for label, pattern in SECRET_PATTERNS:
            match = pattern.search(data)
            if match:
                line = data[:match.start()].count(b'\n')+1
                failures.append((name+':'+str(line),label))
    profile = json.loads((ROOT/'build-profile.json5').read_text(encoding='utf-8'))
    if profile.get('app',{}).get('signingConfigs'):
        failures.append(('build-profile.json5','personal signing config must remain local'))
    for name, reason in failures:
        print('FAIL', name, '-', reason)
    if failures:
        raise SystemExit('Publication blocked. Remove private data from the proposed commit; values were not printed.')
    print('PASS publication check:',count,'candidate files; no recognized secret or forbidden file found.')
    print('Scope: current candidate files only. This does not erase or certify older Git history.')


if __name__ == '__main__':
    main()
