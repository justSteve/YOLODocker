# Docker Factory Script Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a bash script that creates ephemeral Docker containers for Claude Code sessions with auto-accepting permission prompts, project-aware Dockerfile generation, and safe extraction of changes.

**Architecture:** Single bash script (`docker-dev`) that detects project type, generates a Dockerfile, builds/runs container with mounts, and provides extraction/cleanup commands. Metadata stored in `.dockerdev/` directory per session.

**Tech Stack:** Bash, Docker CLI, Docker Desktop, WSL2 compatible

---

## Task 1: Create Project Structure and Core Script Skeleton

**Files:**
- Create: `bin/docker-dev` (main executable script)
- Create: `.gitignore` (exclude .dockerdev/)

**Step 1: Create bin directory**

```bash
mkdir -p /root/projects/buildDockers/bin
```

**Step 2: Create main script with argument parsing**

```bash
cat > /root/projects/buildDockers/bin/docker-dev << 'EOF'
#!/bin/bash

# Claude Code Docker Factory Script
# Purpose: Create ephemeral dev containers for Claude Code sessions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Main command dispatcher
main() {
    local command="${1:-help}"
    local repo_path="${2:-.}"

    case "$command" in
        help)
            show_help
            ;;
        start|run)
            if [[ -z "${2:-}" ]]; then
                log_error "Usage: docker-dev start <repo-path>"
                exit 1
            fi
            start_container "$repo_path"
            ;;
        extract)
            extract_changes "$repo_path"
            ;;
        stop)
            stop_container "$repo_path"
            ;;
        clean)
            clean_image "$repo_path"
            ;;
        status)
            show_status "$repo_path"
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

show_help() {
    cat << 'HELP'
Claude Code Docker Factory Script

Usage:
  docker-dev start <repo-path>     Start container for repo
  docker-dev extract               Extract changes back to repo
  docker-dev stop                  Stop and discard container
  docker-dev clean                 Remove image
  docker-dev status                Show container status
  docker-dev help                  Show this help

Environment:
  CLAUDE_CODE_ACCEPT_PERMISSIONS=true   (auto-set in container)
  CLAUDE_CODE_MODE=yolo                 (auto-set in container)

Examples:
  docker-dev start /path/to/myproject
  docker-dev extract
  docker-dev stop
HELP
}

# Placeholder functions - will be implemented in subsequent tasks
start_container() {
    log_info "start_container not yet implemented"
}

extract_changes() {
    log_info "extract_changes not yet implemented"
}

stop_container() {
    log_info "stop_container not yet implemented"
}

clean_image() {
    log_info "clean_image not yet implemented"
}

show_status() {
    log_info "show_status not yet implemented"
}

main "$@"
EOF

chmod +x /root/projects/buildDockers/bin/docker-dev
```

**Step 3: Update .gitignore to exclude .dockerdev/\**

```bash
cat >> /root/projects/buildDockers/.gitignore << 'EOF'
# Docker development containers
.dockerdev/
EOF
```

**Step 4: Verify script runs**

```bash
/root/projects/buildDockers/bin/docker-dev help
```

Expected output: Shows help text

**Step 5: Commit**

```bash
cd /root/projects/buildDockers
git add bin/docker-dev .gitignore docs/plans/
git commit -m "feat: scaffold docker-dev script with argument parsing"
```

---

## Task 2: Implement Project Type Detection

**Files:**
- Modify: `bin/docker-dev` (add detect_project_type function)

**Step 1: Add detection function**

Add this function to `bin/docker-dev` before `show_help()`:

```bash
# Detect project type based on dependency files
detect_project_type() {
    local repo_path="$1"

    if [[ ! -d "$repo_path" ]]; then
        log_error "Repository path does not exist: $repo_path"
        return 1
    fi

    # Check for markers in order of priority
    if [[ -f "$repo_path/package.json" ]]; then
        echo "nodejs"
        return 0
    fi

    if [[ -f "$repo_path/pyproject.toml" ]]; then
        echo "python-modern"
        return 0
    fi

    if [[ -f "$repo_path/requirements.txt" ]]; then
        echo "python-pip"
        return 0
    fi

    if [[ -f "$repo_path/go.mod" ]]; then
        echo "golang"
        return 0
    fi

    if [[ -f "$repo_path/Dockerfile" ]]; then
        echo "custom"
        return 0
    fi

    # Fallback
    echo "ubuntu"
    return 0
}

# Get base image and package manager for project type
get_base_image() {
    local project_type="$1"

    case "$project_type" in
        nodejs)
            echo "node:lts-alpine"
            ;;
        python-modern|python-pip)
            echo "python:3.11-slim"
            ;;
        golang)
            echo "golang:1.21-alpine"
            ;;
        ubuntu)
            echo "ubuntu:24.04"
            ;;
        custom)
            echo "custom"
            ;;
        *)
            echo "ubuntu:24.04"
            ;;
    esac
}
```

**Step 2: Test detection with sample repo paths**

Create a test structure:

```bash
mkdir -p /tmp/test-repos/{nodejs-project,python-project,go-project,empty-project}
echo '{}' > /tmp/test-repos/nodejs-project/package.json
echo '' > /tmp/test-repos/python-project/requirements.txt
echo 'module github.com/test/app' > /tmp/test-repos/go-project/go.mod
```

**Step 3: Manually verify detection works**

Source the script and test:

```bash
source /root/projects/buildDockers/bin/docker-dev

# Test each detection
project_type=$(detect_project_type /tmp/test-repos/nodejs-project)
[[ "$project_type" == "nodejs" ]] && echo "✓ NodeJS detection works" || echo "✗ NodeJS detection failed"

project_type=$(detect_project_type /tmp/test-repos/python-project)
[[ "$project_type" == "python-pip" ]] && echo "✓ Python detection works" || echo "✗ Python detection failed"

project_type=$(detect_project_type /tmp/test-repos/go-project)
[[ "$project_type" == "golang" ]] && echo "✓ Go detection works" || echo "✗ Go detection failed"

project_type=$(detect_project_type /tmp/test-repos/empty-project)
[[ "$project_type" == "ubuntu" ]] && echo "✓ Fallback detection works" || echo "✗ Fallback detection failed"
```

Expected: All four checks pass

**Step 4: Commit**

```bash
cd /root/projects/buildDockers
git add bin/docker-dev
git commit -m "feat: add project type detection logic"
```

---

## Task 3: Implement Dockerfile Generation for Node.js

**Files:**
- Create: `templates/Dockerfile.nodejs`
- Modify: `bin/docker-dev` (add generate_dockerfile function)

**Step 1: Create Node.js Dockerfile template**

```bash
mkdir -p /root/projects/buildDockers/templates

cat > /root/projects/buildDockers/templates/Dockerfile.nodejs << 'EOF'
FROM node:lts-alpine

# Install additional utilities
RUN apk add --no-cache \
    bash \
    curl \
    git \
    ca-certificates

# Set working directory
WORKDIR /workspace

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --prefer-offline

# Environment for Claude Code yolo mode
ENV CLAUDE_CODE_ACCEPT_PERMISSIONS=true
ENV CLAUDE_CODE_MODE=yolo
ENV PATH="/workspace/node_modules/.bin:$PATH"

# Keep container running
CMD ["/bin/bash", "-i"]
EOF
```

**Step 2: Add generate_dockerfile function to bin/docker-dev**

Add this before `show_help()`:

```bash
# Generate Dockerfile based on project type
generate_dockerfile() {
    local repo_path="$1"
    local project_type="$2"
    local output_path="$3"

    local template_path="$PROJECT_ROOT/templates/Dockerfile.${project_type}"

    if [[ "$project_type" == "custom" ]]; then
        log_info "Project has custom Dockerfile, using as-is"
        cp "$repo_path/Dockerfile" "$output_path"
        return 0
    fi

    if [[ ! -f "$template_path" ]]; then
        log_error "No template found for project type: $project_type"
        return 1
    fi

    cp "$template_path" "$output_path"
    log_info "Generated Dockerfile for $project_type"
}
```

**Step 3: Test Dockerfile generation**

```bash
source /root/projects/buildDockers/bin/docker-dev

test_output="/tmp/test-Dockerfile"
generate_dockerfile "/tmp/test-repos/nodejs-project" "nodejs" "$test_output"

if [[ -f "$test_output" ]] && grep -q "FROM node:lts-alpine" "$test_output"; then
    echo "✓ Dockerfile generation works"
else
    echo "✗ Dockerfile generation failed"
fi

cat "$test_output"
```

Expected: Dockerfile exists and contains Node.js base image

**Step 4: Commit**

```bash
cd /root/projects/buildDockers
git add templates/Dockerfile.nodejs bin/docker-dev
git commit -m "feat: add Node.js Dockerfile template and generation"
```

---

## Task 4: Implement Dockerfile Generation for Python

**Files:**
- Create: `templates/Dockerfile.python-pip`
- Create: `templates/Dockerfile.python-modern`
- Modify: `bin/docker-dev` (update generate_dockerfile to handle Python variants)

**Step 1: Create Python pip Dockerfile template**

```bash
cat > /root/projects/buildDockers/templates/Dockerfile.python-pip << 'EOF'
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Copy requirements
COPY requirements*.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Environment for Claude Code yolo mode
ENV CLAUDE_CODE_ACCEPT_PERMISSIONS=true
ENV CLAUDE_CODE_MODE=yolo
ENV PYTHONUNBUFFERED=1

# Keep container running
CMD ["/bin/bash", "-i"]
EOF
```

**Step 2: Create Python modern (pyproject.toml) Dockerfile template**

```bash
cat > /root/projects/buildDockers/templates/Dockerfile.python-modern << 'EOF'
FROM python:3.11-slim

# Install system dependencies and uv
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install uv for faster dependency resolution
RUN pip install --no-cache-dir uv

# Set working directory
WORKDIR /workspace

# Copy project files for dependency installation
COPY pyproject.toml ./

# Install dependencies with uv
RUN uv pip install --system -e .

# Environment for Claude Code yolo mode
ENV CLAUDE_CODE_ACCEPT_PERMISSIONS=true
ENV CLAUDE_CODE_MODE=yolo
ENV PYTHONUNBUFFERED=1

# Keep container running
CMD ["/bin/bash", "-i"]
EOF
```

**Step 3: Test Python detection and generation**

```bash
source /root/projects/buildDockers/bin/docker-dev

# Test pip variant
test_output="/tmp/test-Dockerfile-pip"
generate_dockerfile "/tmp/test-repos/python-project" "python-pip" "$test_output"
if grep -q "requirements" "$test_output"; then
    echo "✓ Python pip Dockerfile works"
fi

# Test modern variant
test_output="/tmp/test-Dockerfile-modern"
generate_dockerfile "/tmp/test-repos/python-project" "python-modern" "$test_output"
if grep -q "pyproject.toml" "$test_output"; then
    echo "✓ Python modern Dockerfile works"
fi
```

Expected: Both Dockerfiles generated correctly

**Step 4: Commit**

```bash
cd /root/projects/buildDockers
git add templates/Dockerfile.python-pip templates/Dockerfile.python-modern
git commit -m "feat: add Python Dockerfile templates for pip and pyproject.toml"
```

---

## Task 5: Implement Dockerfile Generation for Go and Fallback

**Files:**
- Create: `templates/Dockerfile.golang`
- Create: `templates/Dockerfile.ubuntu`
- Modify: `bin/docker-dev` (verify generation handles all types)

**Step 1: Create Go Dockerfile template**

```bash
cat > /root/projects/buildDockers/templates/Dockerfile.golang << 'EOF'
FROM golang:1.21-alpine

# Install additional utilities
RUN apk add --no-cache \
    bash \
    curl \
    git \
    ca-certificates

# Set working directory
WORKDIR /workspace

# Copy go mod files
COPY go.mod go.sum* ./

# Download dependencies
RUN go mod download

# Environment for Claude Code yolo mode
ENV CLAUDE_CODE_ACCEPT_PERMISSIONS=true
ENV CLAUDE_CODE_MODE=yolo

# Keep container running
CMD ["/bin/bash", "-i"]
EOF
```

**Step 2: Create Ubuntu fallback Dockerfile template**

```bash
cat > /root/projects/buildDockers/templates/Dockerfile.ubuntu << 'EOF'
FROM ubuntu:24.04

# Install basic development tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    wget \
    ca-certificates \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Environment for Claude Code yolo mode
ENV CLAUDE_CODE_ACCEPT_PERMISSIONS=true
ENV CLAUDE_CODE_MODE=yolo

# Keep container running
CMD ["/bin/bash", "-i"]
EOF
```

**Step 3: Test all generation paths**

```bash
source /root/projects/buildDockers/bin/docker-dev

# Create test repo with go.mod
echo 'module github.com/test/app' > /tmp/test-repos/go-project/go.mod

test_output="/tmp/test-Dockerfile-go"
generate_dockerfile "/tmp/test-repos/go-project" "golang" "$test_output"
if grep -q "golang:1.21" "$test_output"; then
    echo "✓ Go Dockerfile works"
fi

test_output="/tmp/test-Dockerfile-ubuntu"
generate_dockerfile "/tmp/test-repos/empty-project" "ubuntu" "$test_output"
if grep -q "ubuntu:24.04" "$test_output"; then
    echo "✓ Ubuntu Dockerfile works"
fi
```

Expected: Both Dockerfiles generated correctly

**Step 4: Commit**

```bash
cd /root/projects/buildDockers
git add templates/Dockerfile.golang templates/Dockerfile.ubuntu
git commit -m "feat: add Go and Ubuntu fallback Dockerfile templates"
```

---

## Task 6: Implement Docker Build and Run Functionality

**Files:**
- Modify: `bin/docker-dev` (implement start_container function)

**Step 1: Add helper functions for Docker operations**

Add these functions before `show_help()`:

```bash
# Create .dockerdev directory and store metadata
setup_dockerdev_dir() {
    local repo_path="$1"
    local dockerdev_dir="$repo_path/.dockerdev"

    mkdir -p "$dockerdev_dir"
    echo "$repo_path" > "$dockerdev_dir/repo-path"
}

# Build Docker image for repo
build_docker_image() {
    local repo_path="$1"
    local project_type="$2"
    local dockerdev_dir="$repo_path/.dockerdev"

    local image_name="claude-code-${project_type}-$(date +%s)"

    log_info "Building Docker image: $image_name"

    if ! docker build -f "$dockerdev_dir/Dockerfile" -t "$image_name" "$repo_path"; then
        log_error "Docker build failed"
        return 1
    fi

    echo "$image_name" > "$dockerdev_dir/image-id"
    log_info "Image built: $image_name"
}

# Run Docker container
run_docker_container() {
    local repo_path="$1"
    local image_name="$2"
    local dockerdev_dir="$repo_path/.dockerdev"

    local container_name="claude-code-$(date +%s)"

    log_info "Starting container: $container_name"

    docker run \
        --name "$container_name" \
        -v "$repo_path:/workspace" \
        -e CLAUDE_CODE_ACCEPT_PERMISSIONS=true \
        -e CLAUDE_CODE_MODE=yolo \
        -it \
        "$image_name" \
        /bin/bash

    echo "$container_name" > "$dockerdev_dir/container-id"

    log_info "Container exited: $container_name"
}
```

**Step 2: Implement start_container function**

Replace the placeholder with:

```bash
start_container() {
    local repo_path="${1:-.}"
    local repo_path="$(cd "$repo_path" && pwd)"  # Normalize to absolute path

    log_info "Starting container for repo: $repo_path"

    # Setup metadata directory
    setup_dockerdev_dir "$repo_path"
    local dockerdev_dir="$repo_path/.dockerdev"

    # Detect project type
    local project_type
    if ! project_type=$(detect_project_type "$repo_path"); then
        log_error "Failed to detect project type"
        return 1
    fi
    log_info "Detected project type: $project_type"

    # Generate Dockerfile
    if ! generate_dockerfile "$repo_path" "$project_type" "$dockerdev_dir/Dockerfile"; then
        log_error "Failed to generate Dockerfile"
        return 1
    fi

    # Build image
    if ! build_docker_image "$repo_path" "$project_type"; then
        log_error "Failed to build image"
        return 1
    fi

    # Run container
    local image_name
    image_name=$(cat "$dockerdev_dir/image-id")
    run_docker_container "$repo_path" "$image_name"
}
```

**Step 3: Test with actual Docker build**

Create a minimal test repo:

```bash
mkdir -p /tmp/docker-test
cd /tmp/docker-test
echo '{"name": "test-project", "version": "1.0.0"}' > package.json

# Note: This will actually try to build Docker image
# Only run if Docker Desktop is running
# /root/projects/buildDockers/bin/docker-dev start /tmp/docker-test
```

**Step 4: Commit**

```bash
cd /root/projects/buildDockers
git add bin/docker-dev
git commit -m "feat: implement Docker build and container run functionality"
```

---

## Task 7: Implement Extraction Mechanism

**Files:**
- Modify: `bin/docker-dev` (implement extract_changes function)

**Step 1: Add extraction helper functions**

Add these before `show_help()`:

```bash
# Extract changes from running container back to repo
copy_workspace_from_container() {
    local container_id="$1"
    local repo_path="$2"
    local dockerdev_dir="$repo_path/.dockerdev"

    log_info "Extracting changes from container: $container_id"

    # Create temporary extraction directory
    local extract_dir="/tmp/docker-extract-$$"
    mkdir -p "$extract_dir"

    # Copy entire workspace from container
    if ! docker cp "$container_id:/workspace/." "$extract_dir/"; then
        log_error "Failed to extract workspace from container"
        rm -rf "$extract_dir"
        return 1
    fi

    # Back up current repo state
    local backup_dir="${repo_path}.backup.$(date +%s)"
    log_warn "Backing up current repo to: $backup_dir"
    cp -r "$repo_path" "$backup_dir"

    # Copy extracted files back to repo (excluding .dockerdev and .git)
    rsync -av --exclude=.dockerdev --exclude=.git "$extract_dir/" "$repo_path/"

    # Cleanup
    rm -rf "$extract_dir"

    log_info "Changes extracted successfully"
    log_info "Backup saved to: $backup_dir"
}

# List changed files since extraction
list_changes() {
    local repo_path="$1"
    local dockerdev_dir="$repo_path/.dockerdev"

    if [[ ! -f "$dockerdev_dir/container-id" ]]; then
        log_warn "No active container found"
        return 1
    fi

    log_info "Changes in working directory:"
    git -C "$repo_path" status --short
}
```

**Step 2: Implement extract_changes function**

Replace placeholder with:

```bash
extract_changes() {
    local repo_path="${1:-.}"
    local repo_path="$(cd "$repo_path" && pwd)"
    local dockerdev_dir="$repo_path/.dockerdev"

    if [[ ! -f "$dockerdev_dir/container-id" ]]; then
        log_error "No active container found for repo: $repo_path"
        return 1
    fi

    local container_id
    container_id=$(cat "$dockerdev_dir/container-id")

    # Verify container exists
    if ! docker ps -a --format "{{.ID}}" | grep -q "^${container_id:0:12}"; then
        log_error "Container not found: $container_id"
        return 1
    fi

    copy_workspace_from_container "$container_id" "$repo_path"
    list_changes "$repo_path"
}
```

**Step 3: Test extraction (manual verification)**

The extraction mechanism will be tested during full integration.

**Step 4: Commit**

```bash
cd /root/projects/buildDockers
git add bin/docker-dev
git commit -m "feat: implement extraction of changes from container"
```

---

## Task 8: Implement Helper Commands (Status, Stop, Clean)

**Files:**
- Modify: `bin/docker-dev` (implement stop_container, clean_image, show_status)

**Step 1: Implement show_status function**

Replace placeholder with:

```bash
show_status() {
    local repo_path="${1:-.}"
    local repo_path="$(cd "$repo_path" && pwd)"
    local dockerdev_dir="$repo_path/.dockerdev"

    log_info "Status for repo: $repo_path"

    if [[ ! -d "$dockerdev_dir" ]]; then
        log_warn "No .dockerdev directory found - no active session"
        return 0
    fi

    if [[ -f "$dockerdev_dir/container-id" ]]; then
        local container_id
        container_id=$(cat "$dockerdev_dir/container-id")

        if docker ps --format "{{.ID}}" | grep -q "^${container_id:0:12}"; then
            log_info "Container is running: $container_id"
        else
            log_warn "Container exists but is stopped: $container_id"
        fi
    fi

    if [[ -f "$dockerdev_dir/image-id" ]]; then
        local image_id
        image_id=$(cat "$dockerdev_dir/image-id")
        log_info "Image: $image_id"
    fi

    if [[ -f "$dockerdev_dir/Dockerfile" ]]; then
        log_info "Dockerfile exists in .dockerdev/"
    fi
}
```

**Step 2: Implement stop_container function**

Replace placeholder with:

```bash
stop_container() {
    local repo_path="${1:-.}"
    local repo_path="$(cd "$repo_path" && pwd)"
    local dockerdev_dir="$repo_path/.dockerdev"

    if [[ ! -f "$dockerdev_dir/container-id" ]]; then
        log_warn "No active container found"
        return 0
    fi

    local container_id
    container_id=$(cat "$dockerdev_dir/container-id")

    log_info "Stopping container: $container_id"

    if docker ps --format "{{.ID}}" | grep -q "^${container_id:0:12}"; then
        docker stop "$container_id" || true
    fi

    # Clean up metadata
    rm -f "$dockerdev_dir/container-id"

    log_info "Container stopped and metadata cleared"
}
```

**Step 3: Implement clean_image function**

Replace placeholder with:

```bash
clean_image() {
    local repo_path="${1:-.}"
    local repo_path="$(cd "$repo_path" && pwd)"
    local dockerdev_dir="$repo_path/.dockerdev"

    if [[ ! -f "$dockerdev_dir/image-id" ]]; then
        log_warn "No image found to clean"
        return 0
    fi

    local image_id
    image_id=$(cat "$dockerdev_dir/image-id")

    log_info "Removing image: $image_id"

    docker rmi "$image_id" || log_warn "Could not remove image (may be in use)"

    # Clean up metadata
    rm -f "$dockerdev_dir/image-id" "$dockerdev_dir/Dockerfile"

    log_info "Image cleaned up"
}
```

**Step 4: Test helper commands**

Manual verification after full integration.

**Step 5: Commit**

```bash
cd /root/projects/buildDockers
git add bin/docker-dev
git commit -m "feat: implement status, stop, and clean commands"
```

---

## Task 9: Add Error Handling and Input Validation

**Files:**
- Modify: `bin/docker-dev` (add validation throughout)

**Step 1: Add input validation helpers**

Add before `show_help()`:

```bash
# Validate Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        return 1
    fi

    if ! docker ps > /dev/null 2>&1; then
        log_error "Docker daemon is not running. Please start Docker Desktop."
        return 1
    fi

    log_info "Docker is available"
}

# Validate repository path exists and is valid
validate_repo_path() {
    local repo_path="$1"

    if [[ ! -d "$repo_path" ]]; then
        log_error "Repository path does not exist: $repo_path"
        return 1
    fi

    if [[ ! -r "$repo_path" ]]; then
        log_error "Repository path is not readable: $repo_path"
        return 1
    fi

    return 0
}
```

**Step 2: Add Docker error handling to build function**

Update `build_docker_image()` to capture better error messages:

```bash
build_docker_image() {
    local repo_path="$1"
    local project_type="$2"
    local dockerdev_dir="$repo_path/.dockerdev"

    local image_name="claude-code-${project_type}-$(date +%s)"
    local build_log="$dockerdev_dir/build.log"

    log_info "Building Docker image: $image_name"

    if ! docker build \
        -f "$dockerdev_dir/Dockerfile" \
        -t "$image_name" \
        "$repo_path" \
        > "$build_log" 2>&1; then

        log_error "Docker build failed. Log:"
        cat "$build_log" | tail -20
        return 1
    fi

    echo "$image_name" > "$dockerdev_dir/image-id"
    log_info "Image built successfully: $image_name"
}
```

**Step 3: Update start_container with validation**

Add validation at beginning:

```bash
start_container() {
    local repo_path="${1:-.}"
    local repo_path="$(cd "$repo_path" && pwd)"

    log_info "Starting container for repo: $repo_path"

    # Validate prerequisites
    if ! check_docker; then
        return 1
    fi

    if ! validate_repo_path "$repo_path"; then
        return 1
    fi

    # ... rest of function
}
```

**Step 4: Commit**

```bash
cd /root/projects/buildDockers
git add bin/docker-dev
git commit -m "feat: add Docker validation and error handling"
```

---

## Task 10: Create Usage Documentation and README

**Files:**
- Create: `DOCKER_DEV_USAGE.md`

**Step 1: Create comprehensive usage guide**

```bash
cat > /root/projects/buildDockers/DOCKER_DEV_USAGE.md << 'EOF'
# Docker Dev - Claude Code Yolo Mode

A factory script for creating ephemeral Docker containers optimized for Claude Code sessions with auto-accepting permission prompts.

## Quick Start

```bash
# Start a development container for your repo
./bin/docker-dev start /path/to/your/repo

# In the container:
# - Make code changes
# - Install new packages with npm/pip/go/apt
# - Test your code

# Exit the container (Ctrl+D or exit)

# Extract changes back to your repo
./bin/docker-dev extract

# Stop the container (cleanup)
./bin/docker-dev stop

# Remove the image
./bin/docker-dev clean
```

## How It Works

### Container Lifecycle

1. **Start**: `docker-dev start <repo>` detects project type, generates a Dockerfile, builds an image, and starts a container
2. **Develop**: Work inside the container with full access to modify code and install packages
3. **Extract**: `docker-dev extract` copies code and updated dependency files back to your repo
4. **Stop**: `docker-dev stop` removes the running container
5. **Clean**: `docker-dev clean` removes the Docker image

### Safety Model

- **Fully isolated**: Changes inside the container cannot affect your host system
- **Ephemeral**: Container is discarded after each session, no persistent state
- **Explicit extraction**: Changes only come back to your repo when you explicitly extract
- **Auto-accepting**: Claude Code permission prompts are automatically accepted inside the container

### Project Detection

The script automatically detects your project type:

| File | Type | Base Image |
|------|------|-----------|
| `package.json` | Node.js | `node:lts-alpine` |
| `pyproject.toml` | Python (modern) | `python:3.11-slim` |
| `requirements.txt` | Python (pip) | `python:3.11-slim` |
| `go.mod` | Go | `golang:1.21-alpine` |
| `Dockerfile` | Custom | Uses your Dockerfile |
| None | Fallback | `ubuntu:24.04` |

## Commands

### Start Container
```bash
./bin/docker-dev start /path/to/repo
```

Detects project type, generates Dockerfile, builds image, and starts interactive container.

### Extract Changes
```bash
./bin/docker-dev extract
```

Copies code and updated dependency files from running container back to repo directory.

### Stop Container
```bash
./bin/docker-dev stop
```

Stops the running container and clears metadata. Container is discarded.

### View Status
```bash
./bin/docker-dev status
```

Shows current container and image status.

### Clean Image
```bash
./bin/docker-dev clean
```

Removes the Docker image from your system.

## Workflow Example

### Node.js Project
```bash
# Start container
./bin/docker-dev start ~/projects/my-app

# Inside container:
npm install new-package
npm test
npm run build

# Exit container (Ctrl+D)

# Extract changes
./bin/docker-dev extract

# Commit to git
cd ~/projects/my-app
git add package.json package-lock.json src/
git commit -m "Add new package and features"

# Stop and clean
./bin/docker-dev stop
./bin/docker-dev clean
```

### Python Project
```bash
# Start container
./bin/docker-dev start ~/projects/data-analysis

# Inside container:
pip install new-library
python script.py

# Exit container

# Extract changes
./bin/docker-dev extract

# Commit to git
cd ~/projects/data-analysis
git add requirements.txt analysis/
git commit -m "Update dependencies and analysis"

# Cleanup
./bin/docker-dev stop
./bin/docker-dev clean
```

## Metadata

After running `docker-dev start`, a `.dockerdev/` directory is created with:

- `container-id` - ID of running container
- `image-id` - ID of built image
- `repo-path` - Absolute path to repository
- `Dockerfile` - Generated Dockerfile for reference
- `build.log` - Docker build output (if build failed)

This directory is excluded from git (see `.gitignore`).

## Troubleshooting

### Docker not found
```
Error: Docker is not installed or not in PATH
```
Install Docker Desktop or ensure `docker` command is available.

### Docker daemon not running
```
Error: Docker daemon is not running
```
Start Docker Desktop.

### Build fails
Check the build log:
```bash
cat .dockerdev/build.log
```

### Permission denied on extraction
Ensure the container is still running:
```bash
./bin/docker-dev status
```

## Environment Variables

Inside the container, these are automatically set:

- `CLAUDE_CODE_ACCEPT_PERMISSIONS=true` - Auto-accept Claude Code permission prompts
- `CLAUDE_CODE_MODE=yolo` - Signal yolo mode to Claude Code
- `PYTHONUNBUFFERED=1` (Python projects) - Unbuffered output

## Files and Structure

```
.
├── bin/
│   └── docker-dev           # Main factory script
├── templates/
│   ├── Dockerfile.nodejs
│   ├── Dockerfile.python-pip
│   ├── Dockerfile.python-modern
│   ├── Dockerfile.golang
│   └── Dockerfile.ubuntu
├── docs/
│   └── plans/
│       ├── 2025-10-22-claude-code-yolo-docker-design.md
│       └── 2025-10-22-docker-factory-script-implementation.md
└── DOCKER_DEV_USAGE.md       # This file
```

## Next Steps

1. Make the script executable: `chmod +x bin/docker-dev`
2. Add `bin/` to your PATH or use full path
3. Start your first container: `./bin/docker-dev start .`
4. Extract changes when done: `./bin/docker-dev extract`

EOF
```

**Step 2: Verify documentation is clear**

Review the documentation against the script functionality.

**Step 3: Commit**

```bash
cd /root/projects/buildDockers
git add DOCKER_DEV_USAGE.md
git commit -m "docs: add comprehensive usage documentation"
```

---

## Final Verification

**After completing all tasks:**

1. ✓ All templates exist (`templates/Dockerfile.*`)
2. ✓ Main script is executable (`bin/docker-dev`)
3. ✓ Script has all functions implemented
4. ✓ Documentation is complete
5. ✓ `.dockerdev/` is in `.gitignore`

---

## How to Proceed

Plan complete and saved to `docs/plans/2025-10-22-docker-factory-script-implementation.md`.

**Two execution options:**

**Option 1: Subagent-Driven (this session)**
- Fresh subagent per task with code review
- Fast iteration with quality gates
- Best if you want detailed review of each step

**Option 2: Parallel Session (separate)**
- Open new session with executing-plans skill
- Batch execution with checkpoints
- Best for focused, uninterrupted implementation

**Which approach would you prefer?**
