#!/usr/bin/env python3
"""Pi delegates lifecycle and workspace handling to the shared runner."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    calls = root / 'calls'
    for name in ('agent-sandbox', 'container'):
        executable = root / name
        executable.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
with open(os.environ['TEST_CALLS'], 'a') as log:
    log.write(json.dumps([Path(sys.argv[0]).name, *sys.argv[1:]]) + '\\n')
if sys.argv[1] == 'image' and Path(sys.argv[0]).name == 'agent-sandbox': print('base:fixture')
if sys.argv[1] == 'create': print('asb-' + 'a' * 32)
if sys.argv[1] == 'exec': sys.exit(int(os.environ['TEST_EXIT']))
''')
        executable.chmod(0o755)
    source = Path('scripts/pi-sandbox.sh').resolve()
    for code in (0, 23):
        calls.write_text('')
        result = subprocess.run(['bash', '-euo', 'pipefail', str(source), '-p', 'read fixture'], cwd=root, env={
            **os.environ, 'PATH': f"{root}:{os.environ['PATH']}", 'TEST_CALLS': str(calls), 'TEST_EXIT': str(code),
            'PI_SANDBOX_CONTEXT': '/fixture-context', 'LLM_PORT': '11434', 'LLM_CONTEXT': '131072', 'LLM_MODEL_DEFAULT': 'fixture',
        }, capture_output=True, text=True)
        assert result.returncode == code, result.stderr
        commands = [json.loads(line) for line in calls.read_text().splitlines()]
        create = next(command for command in commands if command[:2] == ['agent-sandbox', 'create'])
        assert create[create.index('--network') + 1] == 'model'
        assert Path(create[create.index('--project') + 1]).resolve() == root.resolve()
        assert not any(command[:2] == ['container', 'run'] for command in commands)
        assert not any('--mount' in command for command in commands)
        assert 'Retained asb-' in result.stderr
    print('Pi uses disposable snapshots, retains results, and propagates command status: passed')
