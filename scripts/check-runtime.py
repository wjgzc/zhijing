"""Validate the runtime bundle, optionally using real local HTTP endpoints."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import build_opener, ProxyHandler, Request

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--live', action='store_true', help='Start a temporary localhost API and exercise both courses')
    args = parser.parse_args()
    manifest = json.loads((ROOT/'server/runtime-manifest.json').read_text(encoding='utf-8'))
    for name, expected in manifest['files'].items():
        file = (ROOT/name).resolve()
        if not file.is_relative_to(ROOT) or not file.is_file():
            raise AssertionError('Missing or unsafe runtime path: '+name)
        if hashlib.sha256(file.read_bytes()).hexdigest() != expected:
            raise AssertionError('Runtime checksum mismatch: '+name)
    print('PASS runtime manifest:', len(manifest['files']), 'assets')
    for name in ['kc_questions.json','math_questions.json','kc_meta.json']:
        json.loads((ROOT/'server/data'/name).read_text(encoding='utf-8'))
    for course in ['math', 'dsa']:
        graph_file = 'graph.json' if course == 'math' else 'graph_dsa.json'
        graph = json.loads((ROOT/'entry/src/main/resources/rawfile'/graph_file).read_text(encoding='utf-8'))
        print('PASS graph:', course, len(graph['nodes']), 'nodes')
    if not args.live:
        return
    with socket.socket() as socket_:
        socket_.bind(('127.0.0.1', 0))
        port = socket_.getsockname()[1]
    environment = os.environ.copy()
    environment['PYTHONDONTWRITEBYTECODE'] = '1'
    opener = build_opener(ProxyHandler({}))
    def request(route, payload=None):
        data = None if payload is None else json.dumps(payload).encode('utf-8')
        value = Request(f'http://127.0.0.1:{port}'+route, data=data,
                        headers={'Content-Type':'application/json'})
        with opener.open(value, timeout=25) as response:
            return json.loads(response.read())
    with tempfile.TemporaryFile(mode='w+b') as log:
        process = subprocess.Popen([sys.executable, '-m', 'uvicorn', 'app:app',
                                    '--host', '127.0.0.1', '--port', str(port)],
                                   cwd=ROOT/'server', env=environment, stdout=log, stderr=log)
        try:
            for attempt in range(100):
                if process.poll() is not None:
                    raise AssertionError('Backend exited during startup; check installed runtime dependencies.')
                try:
                    health = request('/health')
                    break
                except (URLError, OSError):
                    time.sleep(.25)
            else:
                raise AssertionError('Backend startup timed out')
            assert health['courses']['math']['n_kc'] == 865
            assert health['courses']['dsa']['n_kc'] == 96
            print('PASS actual HTTP startup and dual-course health')
            math = json.loads((ROOT/'server/data/math_questions.json').read_text(encoding='utf-8'))
            question = next(q for q in math.values() if q.get('answer') and not q.get('review_flags'))
            questions = request('/questions?course=math&kc='+str(question['kc'])+'&n=3')['questions']
            assert questions and all(q['answer'] == [] and q['analysis'] == '' for q in questions)
            result = request('/submit-math', {'course':'math','qid':question['qid'],
                             'kc':question['kc'],'answers':question['answer']})
            assert result['graded'] and result['correct'] == 1
            prediction = request('/predict', {'course':'math','interactions':[
                {'kc':question['kc'],'qid':question['qid'],'correct':1}]})
            assert len(prediction['mastery']) == 865
            print('PASS math question privacy, actual grading and prediction')
            dsa = json.loads((ROOT/'server/data/dsa/questions.json').read_text(encoding='utf-8'))
            question = next(iter(dsa.values()))
            kc = question['concepts'][0]
            questions = request('/questions?course=dsa&kc='+str(kc)+'&n=3')['questions']
            assert questions and all('tests' not in q and q.get('original') for q in questions)
            prediction = request('/predict', {'course':'dsa','interactions':[
                {'kc':kc,'qid':question['qid'],'correct':1}]})
            assert len(prediction['mastery']) == 96 and prediction['supported_kcs']
            print('PASS Java question test-set privacy and real model prediction')
            image = next(q['images'][0] for q in math.values() if q.get('images'))
            with opener.open(f'http://127.0.0.1:{port}'+image, timeout=10) as response:
                assert response.read(8) == b'\x89PNG\r\n\x1a\n'
            print('PASS bundled math image HTTP delivery')
            print('NOT RUN: paid AI chat and Linux container execution; configure their services separately.')
        except Exception:
            log.seek(0)
            # Do not print configuration or private environment values.
            tail = log.read().decode('utf-8', errors='replace')[-5000:]
            print(tail, file=sys.stderr)
            raise
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == '__main__':
    main()
