"""Start the published runtime; keep judge tokens in child-process environments."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def read_environment():
    environment = os.environ.copy()
    filename = ROOT / 'server/.env'
    if filename.exists():
        for line in filename.read_text(encoding='utf-8-sig').splitlines():
            if not line.strip() or line.lstrip().startswith('#') or '=' not in line:
                continue
            name, value = line.split('=', 1)
            environment[name.strip()] = value.strip()
    return environment


def main():
    parser = argparse.ArgumentParser(description='Start the bundled Zhijing backend.')
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8000)
    parser.add_argument('--with-judge', action='store_true', help='Linux container engine required')
    args = parser.parse_args()
    missing = [name for name in ['torch', 'numpy', 'fastapi', 'uvicorn', 'requests']
               if importlib.util.find_spec(name) is None]
    if missing:
        raise SystemExit('Install dependencies first: python -m pip install -r server/requirements.txt')
    manifest = json.loads((ROOT/'server/runtime-manifest.json').read_text(encoding='utf-8'))
    absent = [name for name in manifest['files'] if not (ROOT/name).is_file()]
    if absent:
        raise SystemExit('Missing runtime assets; clone the complete repository. First missing: '+absent[0])
    environment = read_environment()
    worker = None
    if args.with_judge:
        if not sys.platform.startswith('linux'):
            raise SystemExit('The isolated Java judge requires Linux. Use a Linux host or WSL2; no host-code fallback.')
        engine = environment.get('JAVA_CONTAINER_ENGINE', 'podman')
        image = environment.get('JAVA_JUDGE_IMAGE', 'localhost/zhijing-java:17')
        if not shutil.which(engine):
            raise SystemExit('Container engine unavailable. Install Podman or Docker; see README.md.')
        inspection = subprocess.run([engine, 'image', 'inspect', image],
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if inspection.returncode:
            raise SystemExit('Build the Java image first; see README.md.')
        token = environment.get('JUDGE_TOKEN', '')
        if token and len(token) < 32:
            raise SystemExit('JUDGE_TOKEN must contain at least 32 characters, or be omitted for an ephemeral token.')
        environment['JUDGE_TOKEN'] = token or secrets.token_hex(32)
        worker = subprocess.Popen([sys.executable, 'judge_worker.py'], cwd=ROOT/'server', env=environment)
    else:
        print('Java judge not started. Use --with-judge on Linux for code execution.', flush=True)
    if not environment.get('DEEPSEEK_API_KEY'):
        print('AI key not configured: questions, math grading and prediction remain available; AI chat needs server/.env.', flush=True)
    api = None
    try:
        api = subprocess.Popen([sys.executable, '-m', 'uvicorn', 'app:app',
                                '--host', args.host, '--port', str(args.port)], cwd=ROOT/'server', env=environment)
        while True:
            try:
                status = api.wait(timeout=1)
                break
            except subprocess.TimeoutExpired:
                if worker is not None and worker.poll() is not None:
                    raise SystemExit('The isolated judge worker stopped. Check its local output.')
        if status:
            raise SystemExit(status)
    except KeyboardInterrupt:
        pass
    finally:
        for process in [api, worker]:
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == '__main__':
    main()
