#!/bin/bash
# Change extraction from container to repo

# Extract changes from container
extract_changes() {
  local repo_path="$1"
  local container_id="$2"
  local temp_extract_dir

  if [[ -z "$container_id" ]]; then
    error "No container ID provided

Next steps:
  - Start a container first: ./bin/docker-dev start
  - Check container status: ./bin/docker-dev status
  - Ensure container is running: docker ps"
  fi

  info "Extracting changes from container: $container_id"

  # Create temporary directory for extraction
  temp_extract_dir=$(mktemp -d)
  trap "rm -rf $temp_extract_dir" RETURN

  # Copy entire workspace from container
  info "Copying workspace from container..."
  if ! docker cp "$container_id:/workspace/." "$temp_extract_dir/" 2>/dev/null; then
    error "Failed to copy files from container

Next steps:
  - Check if container is running: docker ps | grep $container_id
  - Restart container if stopped: ./bin/docker-dev start
  - Check container logs: docker logs $container_id
  - Verify /workspace exists in container: docker exec $container_id ls -la /workspace"
  fi

  # Backup original repo
  local backup_dir="${repo_path}.backup.$(date +%s)"
  info "Creating backup at: $backup_dir"
  cp -r "$repo_path" "$backup_dir"

  # Use rsync to merge changes back, excluding certain directories
  info "Merging changes back to repo..."
  rsync -av --exclude='.dockerdev' \
           --exclude='.git' \
           --exclude='node_modules' \
           --exclude='__pycache__' \
           --exclude='*.pyc' \
           --exclude='.venv' \
           --exclude='venv' \
           "$temp_extract_dir/" "$repo_path/" || error "rsync merge failed

Next steps:
  - Check rsync is installed: rsync --version
  - Verify write permissions on repo: ls -la $repo_path
  - Check disk space: df -h
  - Restore from backup if needed: cp -r ${repo_path}.backup.* $repo_path"

  info "Changes extracted successfully"
  info "Backup preserved at: $backup_dir"
  info "Review changes with: git status"
}

# Show what changed
show_extraction_summary() {
  local repo_path="$1"

  echo ""
  echo "=== Change Summary ==="
  cd "$repo_path"
  git status --short || true
}
