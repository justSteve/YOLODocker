#!/bin/bash
# Docker build and run operations

# Check Docker availability
check_docker() {
  if ! command -v docker &> /dev/null; then
    error "Docker not found. Install Docker and ensure daemon is running."
  fi

  if ! docker ps &>/dev/null; then
    error "Docker daemon not responding. Check if Docker is running."
  fi
}

# Generate image name
generate_image_name() {
  local timestamp=$(date +%s)
  echo "claude-code-dev-${timestamp}"
}

# Build Docker image
build_docker_image() {
  local repo_path="$1"
  local dockerfile_path="$2"
  local image_name="$3"
  local build_log="${repo_path}/.dockerdev/build.log"

  info "Building Docker image: $image_name"

  # Create metadata directory
  mkdir -p "${repo_path}/.dockerdev"

  # Build with log capture
  if docker build -f "$dockerfile_path" \
    -t "$image_name" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    "$repo_path" > "$build_log" 2>&1; then
    info "Image built successfully: $image_name"
    echo "$image_name"
  else
    error "Docker build failed. See $build_log for details"
  fi
}

# Run Docker container
run_docker_container() {
  local image_name="$1"
  local repo_path="$2"
  local config_file="${repo_path}/config4Docker.json"

  info "Starting container from image: $image_name"

  # Generate container name
  local container_name="claude-dev-$(date +%s)"

  # Copy config to container via volume
  # Note: entrypoint.sh expects config at /workspace/config4Docker.json
  local container_id=$(docker run \
    -d \
    --name "$container_name" \
    -v "${repo_path}:/workspace" \
    -e "CLAUDE_CODE_ACCEPT_PERMISSIONS=true" \
    -e "CLAUDE_CODE_MODE=yolo" \
    "$image_name" \
    tail -f /dev/null)

  if [[ -z "$container_id" ]]; then
    error "Failed to start container"
  fi

  info "Container started: $container_id"
  echo "$container_id"
}

# Attach to running container
attach_to_container() {
  local container_id="$1"
  info "Attaching to container: $container_id"
  docker exec -it "$container_id" /bin/bash
}

# Stop running container
stop_docker_container() {
  local container_id="$1"
  if [[ -z "$container_id" ]]; then
    return 0
  fi

  if docker ps -q | grep -q "$container_id"; then
    info "Stopping container: $container_id"
    docker stop "$container_id" || true
    docker rm "$container_id" || true
  fi
}

# Show container status
show_container_status() {
  if docker ps | grep -q claude-dev; then
    echo "Running containers:"
    docker ps --filter "name=claude-dev" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
  else
    echo "No running claude-dev containers"
  fi
}

# Show image status
show_image_status() {
  if docker images | grep -q claude-code-dev; then
    echo "Built images:"
    docker images --filter "reference=claude-code-dev*" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.Created}}"
  else
    echo "No built claude-code-dev images"
  fi
}

# Remove Docker image
remove_docker_image() {
  local image_name="$1"
  if [[ -z "$image_name" ]]; then
    return 0
  fi

  if docker images --quiet "$image_name" &>/dev/null; then
    info "Removing image: $image_name"
    docker rmi -f "$image_name" || true
  fi
}
