#!/bin/bash
set -euo pipefail

# Container entrypoint - handles setup and starts supervisor

# Suppress bash deprecation warning in containers
export BASH_COMPLETION_COMPAT_DIR=/etc/bash_completion.d

info() {
  echo "[ENTRYPOINT] $*"
}

error() {
  echo "[ENTRYPOINT ERROR] $*" >&2
  exit 1
}

# Check if config4Docker.json exists
if [[ ! -f /workspace/config4Docker.json ]]; then
  error "config4Docker.json not found in /workspace"
fi

cd /workspace || error "Failed to change to /workspace"

info "Setting up development environment..."

# Auto-install from manifest files
if [[ -f package.json ]]; then
  info "Installing Node packages..."
  npm ci || error "npm ci failed"
fi

if [[ -f requirements.txt ]]; then
  info "Installing Python packages..."
  pip install -q -r requirements.txt || error "pip install failed"
fi

if command -v go >/dev/null && [[ -f go.mod ]]; then
  info "Downloading Go modules..."
  go mod download || error "go mod download failed"
fi

# Create supervisor config from config4Docker.json
info "Generating supervisor configuration..."
python3 /generate-supervisor-config.py \
  /workspace/config4Docker.json \
  /etc/supervisor/conf.d/services.conf || error "Failed to generate supervisor config"

info "Starting services via supervisor..."

# Start supervisord in foreground (takes over PID 1)
exec supervisord -c /etc/supervisor/supervisord.conf
