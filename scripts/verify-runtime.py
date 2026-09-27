#!/usr/bin/env python3
"""Isolated release recovery/reload/cleanup checks. Never reads the user's config."""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('--app', type=Path, required=True)
parser.add_argument('--report', type=Path, required=True)
parser.add_argument('--cycles', type=int, default=100)
args = parser.parse_args()
app = args.app.resolve()
binary = app / 'Contents/MacOS/Rill'
cli = app / 'Contents/Resources/bin/rillctl'
report = {'cycles': args.cycles, 'passed': False}
with tempfile.TemporaryDirectory(prefix='rill-check-', dir='/tmp') as root:
    root = Path(root)
    runtime = root / 'run'
    config = root / 'config.toml'
    sentinel = root / 'producer.sh'
    sentinel.write_text('#!/bin/sh\ntrap \'\' TERM\nwhile :; do printf \'{"version":1,"type":"module.update","data":{"text":"ready"}}\\n\'; sleep 1; done\n')
    sentinel.chmod(0o700)
    good = f'''schema_version = 1
[[surfaces]]
id = "main"
kind = "bar"
display = "all"
edge = "top"
start = ["feed"]
[[modules]]
id = "feed"
kind = "custom"
provider = "source"
[[providers]]
id = "source"
kind = "stream"
executable = "{sentinel}"
timeout_ms = 100
'''
    def write(text):
        temporary = config.with_suffix('.new')
        temporary.write_text(text)
        temporary.replace(config)
    def rpc(command):
        with socket.socket(socket.AF_UNIX) as connection:
            connection.settimeout(3)
            connection.connect(str(runtime / 'control.sock'))
            connection.sendall((json.dumps({'version': 1, 'request_id': 'check', 'command': command, 'data': {}})+'\n').encode())
            data = b''
            while not data.endswith(b'\n'):
                part = connection.recv(65536)
                if not part:
                    raise RuntimeError('IPC closed')
                data += part
            return json.loads(data)
    def wait_for(predicate, timeout=8):
        deadline = time.monotonic()+timeout
        while time.monotonic() < deadline:
            try:
                value = predicate()
                if value:
                    return value
            except (OSError, KeyError):
                pass
            time.sleep(.04)
        raise AssertionError('Runtime condition timed out')
    def processes():
        rows = subprocess.check_output(['ps','-axo','pid=,ppid=,command='], text=True).splitlines()
        return [(int(parts[0]), int(parts[1]), parts[2]) for row in rows if len(parts := row.strip().split(None,2)) == 3]
    def children():
        return [pid for pid, parent, _ in processes() if parent == process.pid]
    def descriptors():
        result = subprocess.run(['lsof','-p',str(process.pid),'-Fn'], capture_output=True, text=True)
        return len([line for line in result.stdout.splitlines() if line.startswith('f')])
    write('{ invalid')
    environment = dict(os.environ, RILL_RUNTIME_DIR=str(runtime))
    with (root/'app.log').open('w') as log:
        process = subprocess.Popen([str(binary),'--config',str(config)], env=environment, stdout=log, stderr=log)
        try:
            initial = wait_for(lambda: rpc('status')['result'])
            assert initial['configuration_error'] and not initial['providers']
            report['invalid_start_no_children'] = not children()
            write(good)
            wait_for(lambda: rpc('status')['result']['providers'].get('source') == 'ready')
            report['automatic_recovery'] = True
            time.sleep(.3)
            baseline = rpc('diagnostics')['result']['visible_panel_count']
            report['baseline_panels'] = baseline
            report['baseline_descriptors'] = descriptors()
            assert baseline > 0
            for index in range(args.cycles):
                write(good + f'\n# iteration {index}\n')
                assert rpc('reload')['ok']
                time.sleep(.22)
                write('{ invalid')
                rejected = rpc('reload')
                assert not rejected['ok'] and rejected['error']['code'] == 'reload_rejected'
                assert rpc('diagnostics')['result']['visible_panel_count'] == baseline
            write(good)
            assert rpc('reload')['ok']
            wait_for(lambda: rpc('status')['result']['providers'].get('source') == 'ready')
            time.sleep(.4)
            report['final_descriptors'] = descriptors()
            report['final_direct_children'] = len(children())
            assert report['final_descriptors'] <= report['baseline_descriptors'] + 8
            assert len(children()) == 1
            # A second instance must not spawn panels/providers or steal the socket.
            second = subprocess.Popen([str(binary),'--config',str(config)], env=environment, stdout=log, stderr=log)
            try:
                time.sleep(.4)
                assert not [pid for pid, parent, _ in processes() if parent == second.pid]
                assert rpc('status')['result']['running']
                report['second_instance_no_children'] = True
            finally:
                second.terminate()
                second.wait(timeout=5)
            process.terminate()
            process.wait(timeout=5)
            assert not (runtime/'control.sock').exists()
            assert not [row for row in processes() if str(sentinel) in row[2]]
            report['graceful_shutdown_no_owned_children_or_socket'] = True
            report['passed'] = True
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
