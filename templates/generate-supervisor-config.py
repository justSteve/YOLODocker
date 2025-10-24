#!/usr/bin/env python3
"""Generate supervisor config from config4Docker.json"""

import json
import sys
from pathlib import Path

def generate_supervisor_config(config_file, output_file):
    """Generate supervisord.conf from config4Docker.json"""

    # Load config
    with open(config_file) as f:
        config = json.load(f)

    # Validate config has services
    if 'services' not in config or not config['services']:
        print("ERROR: No services defined in config", file=sys.stderr)
        sys.exit(1)

    # Generate supervisor config
    lines = [
        "[supervisord]",
        "nodaemon=true",
        "logfile=/tmp/supervisord.log",
        "pidfile=/tmp/supervisord.pid",
        "",
        "[unix_http_server]",
        "file=/tmp/supervisor.sock",
        "",
        "[supervisorctl]",
        "serverurl=unix:///tmp/supervisor.sock",
        "",
        "[rpcinterface:supervisor]",
        "supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface",
        "",
    ]

    # Add each service
    for service_name, service_config in config['services'].items():
        start_cmd = service_config.get('startCommand', '')

        # Wrap command in sh -c to enable shell features (&&, |, etc.)
        wrapped_cmd = f'sh -c "{start_cmd}"'

        lines.extend([
            f"[program:{service_name}]",
            f"command={wrapped_cmd}",
            "autostart=true",
            "autorestart=true",
            "startretries=3",
            "stderr_logfile=/dev/stderr",
            "stderr_logfile_maxbytes=0",
            "stdout_logfile=/dev/stdout",
            "stdout_logfile_maxbytes=0",
            "startsecs=2",
            "stopasgroup=true",
            "killasgroup=true",
            "",
        ])

    # Write config
    with open(output_file, 'w') as f:
        f.write('\n'.join(lines))

    print(f"Generated supervisor config: {output_file}")

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: generate-supervisor-config.py <config_file> <output_file>")
        sys.exit(1)

    generate_supervisor_config(sys.argv[1], sys.argv[2])
