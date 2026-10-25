"""Local-only authenticated broker; fixed Docker options, no arbitrary commands."""
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path

from java_judge import judge, JudgeUnavailable

ROOT = Path(__file__).resolve().parent
TOKEN = os.environ.get('JUDGE_TOKEN','')
QUESTIONS = json.loads((ROOT/'data/dsa/questions.json').read_text(encoding='utf-8'))


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/judge' or not hmac.compare_digest(self.headers.get('Authorization',''),'Bearer '+TOKEN):
            self.send_error(403)
            return
        try:
            length = int(self.headers.get('Content-Length','0'))
            if length < 1 or length > 100000:
                raise ValueError('请求过大')
            self.connection.settimeout(5)
            body = json.loads(self.rfile.read(length))
            question = QUESTIONS[str(int(body['qid']))]
            result = judge(body['source'],body.get('main_class','Solution'),question['tests'])
            self.reply(200,result)
        except (KeyError,ValueError,TypeError) as error:
            self.reply(422,{'detail':str(error)})
        except JudgeUnavailable as error:
            self.reply(503,{'detail':str(error)})
        except Exception as error:
            print('Judge infrastructure error: ' + type(error).__name__, flush=True)
            self.reply(503,{'detail':'判题基础服务异常，请稍后重试'})

    def reply(self,status,body):
        value = json.dumps(body,ensure_ascii=False).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type','application/json; charset=utf-8')
        self.send_header('Content-Length',str(len(value)))
        self.end_headers()
        self.wfile.write(value)

    def log_message(self,*args):
        pass  # Never log submitted source or credentials.


if __name__ == '__main__':
    if len(TOKEN) < 32:
        raise SystemExit('A separate JUDGE_TOKEN of at least 32 characters is required')
    ThreadingHTTPServer(('127.0.0.1',8001),Handler).serve_forever()
