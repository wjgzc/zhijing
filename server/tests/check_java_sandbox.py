"""Run on Linux with the real local container image; trusted test fixtures only."""
from pathlib import Path
import json
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from java_judge import judge


def source(body):
    return 'public class Solution { public static void main(String[] a) throws Exception {' + body + '} }'


def main():
    cases = [
        ('accepted',source('System.out.println("OK");'),'OK\n'),
        ('wrong_answer',source('System.out.println("NO");'),'OK\n'),
        ('compile_error','public class Solution { invalid java }','OK\n'),
        ('runtime_error',source('throw new RuntimeException("fixture");'),'OK\n'),
        ('time_limit',source('while(true) {}'),'OK\n'),
        ('output_limit',source('while(true) System.out.println("excessive output");'),'OK\n'),
        ('accepted',source('try { java.nio.file.Files.readString(java.nio.file.Path.of("/opt/zhijing/app/server/.env")); System.out.println("LEAK"); } catch (java.io.IOException e) { System.out.println("BLOCKED"); }'),'BLOCKED\n'),
        ('accepted',source('try { new java.net.Socket().connect(new java.net.InetSocketAddress("1.1.1.1",80),500); System.out.println("NETWORK"); } catch (java.io.IOException e) { System.out.println("BLOCKED"); }'),'BLOCKED\n'),
        ('accepted',source('try { java.nio.file.Files.writeString(java.nio.file.Path.of("/etc/escape"),"x"); System.out.println("WRITABLE"); } catch (java.io.IOException e) { System.out.println("BLOCKED"); }'),'BLOCKED\n'),
    ]
    report = []
    for expected,code,output in cases:
        result = judge(code,'Solution',[{'input':'','output':output}])
        print(expected,result['status'],result['detail'][:250],flush=True)
        assert result['status'] == expected,result
        report.append({'expected':expected,'actual':result['status'],'passed':True})
    print(json.dumps(report),flush=True)


if __name__ == '__main__': main()
