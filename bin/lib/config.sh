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
    error "Config file not found: $config_file"
    return 1
  fi

  # Validate JSON
  if ! jq empty "$config_file" 2>/dev/null; then
    error "Invalid JSON in $config_file"
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
    error "Missing required field: services"
    return 1
  fi

  # Check services is object
  if ! echo "$config_json" | jq -e '.services | type == "object"' &>/dev/null; then
    error "services must be an object"
    return 1
  fi

  # Check at least one service
  local service_count=$(echo "$config_json" | jq '.services | length')
  if [[ $service_count -eq 0 ]]; then
    error "At least one service must be declared"
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
      error "Service '$service_name' missing required field: $field"
      return 1
    fi
  done

  # Validate runtime
  local runtime=$(echo "$config_json" | jq -r "$service_path.runtime")
  if [[ ! "$runtime" =~ ^(node|python|custom)$ ]]; then
    error "Service '$service_name' has invalid runtime: $runtime (must be node, python, or custom)"
    return 1
  fi

  # Validate port is number
  local port=$(echo "$config_json" | jq -r "$service_path.port")
  if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    error "Service '$service_name' port must be a number, got: $port"
    return 1
  fi

  # Validate startCommand is non-empty string
  local cmd=$(echo "$config_json" | jq -r "$service_path.startCommand")
  if [[ -z "$cmd" || "$cmd" == "null" ]]; then
    error "Service '$service_name' startCommand cannot be empty"
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
