#!/bin/bash
# Change extraction from container to repo

# Extract changes from container
extract_changes() {
  local repo_path="$1"
  local container_id="$2"
  local temp_extract_dir

  if [[ -z "$container_id" ]]; then
    error "No container ID provided"
  fi

  info "Extracting changes from container: $container_id"

  # Create temporary directory for extraction
  temp_extract_dir=$(mktemp -d)
  trap "rm -rf $temp_extract_dir" RETURN

  # Copy entire workspace from container
  info "Copying workspace from container..."
  if ! docker cp "$container_id:/workspace/." "$temp_extract_dir/" 2>/dev/null; then
    error "Failed to copy files from container"
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
           "$temp_extract_dir/" "$repo_path/" || error "rsync merge failed"

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
