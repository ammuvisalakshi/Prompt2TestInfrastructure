"""Helper: reads a diagram .py file, strips imports, calls MCP server to generate PNG."""
import json
import subprocess
import sys
import os

def generate(py_file):
    with open(py_file, 'r', encoding='utf-8') as f:
        code = f.read()

    lines = code.split('\n')
    code_no_imports = '\n'.join(l for l in lines if not l.startswith('from ') and not l.startswith('import '))

    basename = os.path.splitext(os.path.abspath(py_file))[0].replace('\\', '/')

    msgs = []
    msgs.append(json.dumps({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'protocolVersion':'2024-11-05','capabilities':{},'clientInfo':{'name':'cli','version':'1.0'}}}))
    msgs.append(json.dumps({'jsonrpc':'2.0','method':'notifications/initialized'}))
    msgs.append(json.dumps({'jsonrpc':'2.0','id':2,'method':'tools/call','params':{'name':'generate_diagram','arguments':{'code': code_no_imports.strip(), 'filename': basename}}}))

    mcp_exe = r'C:\Users\ammuv\AppData\Roaming\uv\tools\awslabs-aws-diagram-mcp-server\Scripts\awslabs.aws-diagram-mcp-server.exe'

    env = os.environ.copy()
    env['GRAPHVIZ_DOT'] = r'C:\Program Files\Graphviz\bin\dot.exe'
    env['DIAGRAM_OUTPUT_DIR'] = r'C:\Users\ammuv\aws-diagrams'
    env['PATH'] = r'C:\Program Files\Graphviz\bin;' + env.get('PATH', '')

    proc = subprocess.run(
        [mcp_exe],
        input='\n'.join(msgs) + '\n',
        capture_output=True,
        text=True,
        timeout=120,
        env=env,
    )

    output_lines = [l for l in proc.stdout.strip().split('\n') if l.strip()]
    if output_lines:
        last = json.loads(output_lines[-1])
        result = json.loads(last['result']['content'][0]['text'])
        print(f"{os.path.basename(py_file)}: {result.get('status')} - {result.get('message', result.get('path', ''))}")
        return result.get('status') == 'success'
    else:
        print(f"{os.path.basename(py_file)}: FAILED - no output")
        if proc.stderr:
            print(f"  stderr: {proc.stderr[:200]}")
        return False

if __name__ == '__main__':
    for f in sys.argv[1:]:
        generate(f)
