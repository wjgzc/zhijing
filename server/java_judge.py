"""Docker-only Java sandbox. Never falls back to executing submissions on host.

Run by a separate local worker, not the public API service. Submitted code sees
only its own read-only source and an ephemeral /work, never the test catalogue,
credentials, Docker socket or backend files. Docker's default seccomp stays on.
"""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
import time
import uuid

ENGINE = os.environ.get('JAVA_CONTAINER_ENGINE','podman')
IMAGE = os.environ.get('JAVA_JUDGE_IMAGE','localhost/zhijing-java:17')
MAX_OUTPUT = 65536
SLOTS = threading.BoundedSemaphore(1)


class JudgeUnavailable(RuntimeError):
    pass


class OutputLimit(RuntimeError):
    pass


def bounded_run(args, timeout, stdin=None):
    """Bound disk/memory use even when a submission writes forever."""
    with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as error, tempfile.TemporaryFile() as input_file:
        if stdin is not None:
            input_file.write(stdin.encode('utf-8'))
            input_file.seek(0)
        process = subprocess.Popen(args,stdin=input_file,stdout=output,stderr=error)
        start = time.monotonic()
        try:
            while process.poll() is None:
                if os.fstat(output.fileno()).st_size + os.fstat(error.fileno()).st_size > MAX_OUTPUT:
                    raise OutputLimit()
                if time.monotonic()-start > timeout:
                    raise subprocess.TimeoutExpired(args,timeout)
                time.sleep(.02)
            if os.fstat(output.fileno()).st_size + os.fstat(error.fileno()).st_size > MAX_OUTPUT:
                raise OutputLimit()
            output.seek(0)
            error.seek(0)
            return process.returncode,output.read(MAX_OUTPUT).decode('utf-8',errors='replace'),error.read(MAX_OUTPUT).decode('utf-8',errors='replace')
        finally:
            if process.poll() is None:
                process.kill()
            process.wait()


def normalize(value):
    # Ignore CRLF and trailing whitespace, but preserve leading/internal spaces
    # and line boundaries (e.g. step-by-step sorting output).
    return '\n'.join(x.rstrip() for x in value.replace('\r\n','\n').replace('\r','\n').split('\n')).rstrip()


def judge(source, main_class, tests):
    if main_class not in ('Solution','Main'):
        raise ValueError('入口类仅支持 Solution 或 Main')
    if not source.strip() or len(source.encode('utf-8')) > 60000:
        raise ValueError('代码为空或超过 60 KB')
    if not shutil.which(ENGINE):
        raise JudgeUnavailable('隔离判题服务未安装 Docker')
    if not SLOTS.acquire(blocking=False):
        raise JudgeUnavailable('判题队列忙，请稍后重试')
    name = 'zhijing-judge-' + uuid.uuid4().hex
    container_started = False
    started = time.monotonic()
    def verdict(status, passed=0, detail='', actual='', expected=''):
        return {'status':status,'graded':True,'correct':int(status == 'accepted'),
                'passed':passed,'total':len(tests),'detail':detail[:4000],
                'actual':actual[:2000],'expected':expected[:2000],
                'elapsed_ms':int((time.monotonic()-started)*1000)}
    try:
        with tempfile.TemporaryDirectory(prefix='zhijing-java-') as work:
            Path(work,f'{main_class}.java').write_text(source,encoding='utf-8')
            os.chmod(work,0o755)
            os.chmod(Path(work,f'{main_class}.java'),0o644)
            code, _, err = bounded_run([ENGINE,'run','--detach','--pull=never','--name',name,
                '--network=none','--read-only','--user=65534:65534','--cap-drop=ALL',
                '--security-opt=no-new-privileges','--memory=384m','--memory-swap=384m',
                '--cpus=.75','--pids-limit=64','--ulimit=nofile=128:128',
                '--tmpfs=/work:rw,nosuid,nodev,size=48m,mode=1777','--workdir=/work',
                '--mount',f'type=bind,source={work},target=/src,readonly',
                '--log-driver=none','--stop-timeout=0',IMAGE,'sleep','50'],8)
            if code:
                print('Container startup failed: ' + err[:1500], flush=True)
                raise JudgeUnavailable('隔离容器启动失败，请检查判题服务配置')
            container_started = True
            code, out, err = bounded_run([ENGINE,'exec',name,'javac','-J-XX:ActiveProcessorCount=1',
                '-J-Xmx128m','-encoding','UTF-8','-proc:none','-d','/work',f'/src/{main_class}.java'],10)
            if code:
                return verdict('compile_error',detail=err or out)
            for index,test in enumerate(tests):
                remaining = 35-(time.monotonic()-started)
                if remaining <= 0:
                    return verdict('time_limit',index,'本次提交超过总运行时间限制')
                try:
                    code,out,err = bounded_run([ENGINE,'exec','-i',name,'java',
                        '-XX:ActiveProcessorCount=1','-Xms16m','-Xmx128m','-XX:+UseSerialGC',
                        '-XX:MaxMetaspaceSize=64m','-cp','/work',main_class],min(2.5,remaining),test['input'])
                except subprocess.TimeoutExpired:
                    return verdict('time_limit',index,'单个测试运行超时')
                except OutputLimit:
                    return verdict('output_limit',index,'输出超过 64 KB')
                if code in (125,126):
                    raise JudgeUnavailable('容器执行服务异常')
                if code:
                    return verdict('runtime_error',index,err or out)
                if normalize(out) != normalize(test['output']):
                    return verdict('wrong_answer',index,f'第 {index+1} 个测试结果不匹配',out,test['output'])
            return verdict('accepted',len(tests),'全部源题测试通过')
    except subprocess.TimeoutExpired:
        return verdict('time_limit',detail='编译或启动阶段超时')
    except OutputLimit:
        return verdict('output_limit',detail='编译输出超过 64 KB')
    finally:
        try:
            cleanup = [ENGINE,'rm','--force']
            if Path(ENGINE).name == 'podman':
                cleanup.append('--time=0')
            result = subprocess.run(cleanup + [name],capture_output=True,timeout=10)
            if container_started and result.returncode:
                raise JudgeUnavailable('隔离容器清理失败，请检查判题服务')
        finally:
            SLOTS.release()
