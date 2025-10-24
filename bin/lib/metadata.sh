#!/bin/bash
# Metadata directory (.dockerdev/) management

# Initialize metadata directory
init_metadata() {
  local repo_path="$1"
  local metadata_dir="${repo_path}/.dockerdev"

  mkdir -p "$metadata_dir"

  # Create metadata files if they don't exist
  touch "$metadata_dir/repo-path"
  echo "$(cd $repo_path && pwd)" > "$metadata_dir/repo-path"
}

# Save container metadata
save_container_metadata() {
  local repo_path="$1"
  local container_id="$2"
  local config_file="$3"

  local metadata_dir="${repo_path}/.dockerdev"
  mkdir -p "$metadata_dir"

  echo "$container_id" > "$metadata_dir/container-id"
  cp "$config_file" "$metadata_dir/config.json"
  echo "$(date -Iseconds)" > "$metadata_dir/started-at"
}

# Save image metadata
save_image_metadata() {
  local repo_path="$1"
  local image_name="$2"

  local metadata_dir="${repo_path}/.dockerdev"
  mkdir -p "$metadata_dir"

  echo "$image_name" > "$metadata_dir/image-id"
  echo "$(date -Iseconds)" > "$metadata_dir/built-at"
}

# Get saved container ID
get_container_id() {
  local repo_path="$1"
  local container_id_file="${repo_path}/.dockerdev/container-id"

  if [[ -f "$container_id_file" ]]; then
    cat "$container_id_file"
  fi
}

# Get saved image ID
get_image_id() {
  local repo_path="$1"
  local image_id_file="${repo_path}/.dockerdev/image-id"

  if [[ -f "$image_id_file" ]]; then
    cat "$image_id_file"
  fi
}

# Clean metadata
clean_metadata() {
  local repo_path="$1"
  local metadata_dir="${repo_path}/.dockerdev"

  if [[ -d "$metadata_dir" ]]; then
    rm -rf "$metadata_dir"
    info "Cleaned metadata directory: $metadata_dir"
  fi
}

# Show metadata
show_metadata() {
  local repo_path="$1"
  local metadata_dir="${repo_path}/.dockerdev"

  if [[ ! -d "$metadata_dir" ]]; then
    echo "No metadata found"
    return
  fi

  echo "=== Metadata (.dockerdev/) ==="

  if [[ -f "$metadata_dir/repo-path" ]]; then
    echo "Repo: $(cat $metadata_dir/repo-path)"
  fi

  if [[ -f "$metadata_dir/image-id" ]]; then
    echo "Image: $(cat $metadata_dir/image-id)"
    echo "  Built: $(cat $metadata_dir/built-at 2>/dev/null || echo 'unknown')"
  fi

  if [[ -f "$metadata_dir/container-id" ]]; then
    echo "Container: $(cat $metadata_dir/container-id)"
    echo "  Started: $(cat $metadata_dir/started-at 2>/dev/null || echo 'unknown')"
  fi
}
