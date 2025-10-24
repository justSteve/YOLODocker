#!/bin/bash
# Configuration parsing and validation

# Check if jq is available (required for JSON parsing)
check_jq() {
  if ! command -v jq &> /dev/null; then
    error "jq not found. Required for JSON parsing. Install with: apt-get install jq"
  fi
}

# Load config from file
load_config() {
  local config_file="$1"

  if [[ ! -f "$config_file" ]]; then
    error "Config file not found: $config_file

Next steps:
  - Create config4Docker.json in repo root
  - See DOCKER_DEV_USAGE.md for examples
  - Example: {\"services\": {\"web\": {\"runtime\": \"node\", \"port\": 3000, \"startCommand\": \"npm start\"}}}"
    return 1
  fi

  # Validate JSON
  if ! jq empty "$config_file" 2>/dev/null; then
    error "Invalid JSON in $config_file

Next steps:
  - Check JSON syntax with: jq . $config_file
  - Look for missing commas, brackets, or quotes
  - Validate online at: https://jsonlint.com"
    return 1
  fi

  # Return config as string (for use with jq)
  cat "$config_file"
}

# Validate config structure
validate_config() {
  local config_json="$1"

  # Check required fields
  if ! echo "$config_json" | jq -e '.services' &>/dev/null; then
    error "Missing required field: services

Next steps:
  - Add a 'services' object to config4Docker.json
  - Example: {\"services\": {\"web\": {...}}}
  - See DOCKER_DEV_USAGE.md for full config reference"
    return 1
  fi

  # Check services is object
  if ! echo "$config_json" | jq -e '.services | type == "object"' &>/dev/null; then
    error "services must be an object

Next steps:
  - Change 'services' to an object: {\"services\": {}}
  - Services should be key-value pairs: {\"serviceName\": {...}}"
    return 1
  fi

  # Check at least one service
  local service_count=$(echo "$config_json" | jq '.services | length')
  if [[ $service_count -eq 0 ]]; then
    error "At least one service must be declared

Next steps:
  - Add at least one service to the 'services' object
  - Example: {\"services\": {\"web\": {\"runtime\": \"node\", \"port\": 3000, \"startCommand\": \"npm start\"}}}"
    return 1
  fi

  # Validate each service
  local service_names=$(echo "$config_json" | jq -r '.services | keys[]')
  while IFS= read -r service_name; do
    validate_service "$config_json" "$service_name" || return 1
  done <<< "$service_names"

  return 0
}

# Validate individual service
validate_service() {
  local config_json="$1"
  local service_name="$2"

  local service_path=".services[\"$service_name\"]"

  # Check required fields
  for field in "runtime" "port" "startCommand"; do
    if ! echo "$config_json" | jq -e "$service_path | has(\"$field\")" &>/dev/null; then
      error "Service '$service_name' missing required field: $field

Next steps:
  - Add '$field' to service '$service_name'
  - Required fields: runtime, port, startCommand
  - Example: {\"runtime\": \"node\", \"port\": 3000, \"startCommand\": \"npm start\"}"
      return 1
    fi
  done

  # Validate runtime
  local runtime=$(echo "$config_json" | jq -r "$service_path.runtime")
  if [[ ! "$runtime" =~ ^(node|python|custom)$ ]]; then
    error "Service '$service_name' has invalid runtime: $runtime (must be node, python, or custom)

Next steps:
  - Change runtime to one of: node, python, custom
  - For Node.js projects: \"runtime\": \"node\"
  - For Python projects: \"runtime\": \"python\""
    return 1
  fi

  # Validate port is number
  local port=$(echo "$config_json" | jq -r "$service_path.port")
  if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    error "Service '$service_name' port must be a number, got: $port

Next steps:
  - Change port to a numeric value
  - Example: \"port\": 3000
  - Port is for documentation; actual binding happens in startCommand"
    return 1
  fi

  # Validate startCommand is non-empty string
  local cmd=$(echo "$config_json" | jq -r "$service_path.startCommand")
  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    error "Service '$service_name' startCommand cannot be empty

Next steps:
  - Add a valid start command for this service
  - For Node.js: \"startCommand\": \"npm start\"
  - For Python: \"startCommand\": \"python -m app.server\""
    return 1
  fi
}

# Get service names
get_service_names() {
  local config_json="$1"
  echo "$config_json" | jq -r '.services | keys[]'
}

# Get service property
get_service_property() {
  local config_json="$1"
  local service_name="$2"
  local property="$3"

  echo "$config_json" | jq -r ".services[\"$service_name\"] | .$property"
}
