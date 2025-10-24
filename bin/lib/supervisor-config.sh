#!/bin/bash
# Supervisor configuration generation

# Generate supervisor.conf from config4Docker.json
generate_supervisor_config() {
  local config_json="$1"
  local output_file="$2"

  cat > "$output_file" <<'EOF'
[supervisord]
nodaemon=true
logfile=/tmp/supervisord.log
pidfile=/tmp/supervisord.pid

[unix_http_server]
file=/tmp/supervisor.sock

[supervisorctl]
serverurl=unix:///tmp/supervisor.sock

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface
EOF

  # Add each service as a program
  local service_names=$(echo "$config_json" | jq -r '.services | keys[]')
  while IFS= read -r service_name; do
    local start_cmd=$(echo "$config_json" | jq -r ".services[\"$service_name\"].startCommand")
    local port=$(echo "$config_json" | jq -r ".services[\"$service_name\"].port")

    # Add program section
    cat >> "$output_file" <<EOF

[program:$service_name]
command=$start_cmd
autostart=true
autorestart=true
startretries=3
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
startsecs=2
stopasgroup=true
killasgroup=true
EOF
  done <<< "$service_names"

  return 0
}

# Install supervisor config in running container
install_supervisor_config() {
  local container_id="$1"
  local supervisor_conf="$2"

  # Copy config to container
  docker cp "$supervisor_conf" "$container_id:/etc/supervisor/conf.d/services.conf"

  # Reload supervisor
  docker exec "$container_id" supervisorctl reread
  docker exec "$container_id" supervisorctl update
  docker exec "$container_id" supervisorctl start all
}
