# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**buildDockers** is a Docker factory script project that creates ephemeral, containerized development environments for Claude Code sessions. The core deliverable is `bin/docker-dev` — a bash script that auto-detects project types, generates appropriate Dockerfiles, builds images, and manages container lifecycle with safe extraction of changes.

**Architecture Pattern:** Single bash script with modular functions for detection, build, run, extraction, and cleanup. Supports Node.js, Python (pip and modern), Go, and fallback (Ubuntu). All container metadata stored in `.dockerdev/` directory (excluded from git).

## High-Level Architecture

### Script Components

- **Argument Parsing & Command Dispatcher** (`main()`) — Routes commands: `start`, `extract`, `stop`, `clean`, `status`
- **Project Detection** (`detect_project_type()`) — Inspects repo for markers (package.json, requirements.txt, pyproject.toml, go.mod, Dockerfile)
- **Dockerfile Generation** (`generate_dockerfile()`) — Copies appropriate template to `.dockerdev/Dockerfile`
- **Docker Operations** (`build_docker_image()`, `run_docker_container()`) — Builds image with naming convention `claude-code-{type}-{timestamp}`, runs with `/workspace` mount
- **Extraction** (`copy_workspace_from_container()`) — Docker cp from container, backs up current state, rsync changes back (excluding .dockerdev, .git)
- **Helpers** (`show_status()`, `stop_container()`, `clean_image()`) — Query running state, stop container, remove image

### File Structure

```
.
├── bin/
│   └── docker-dev                    # Main executable (will be created during implementation)
├── templates/
│   ├── Dockerfile.nodejs             # Node.js projects (node:lts-alpine)
│   ├── Dockerfile.python-pip         # Python with requirements.txt
│   ├── Dockerfile.python-modern      # Python with pyproject.toml
│   ├── Dockerfile.golang             # Go projects
│   └── Dockerfile.ubuntu             # Fallback base image
├── docs/
│   └── plans/
│       ├── 2025-10-22-claude-code-yolo-docker-design.md     # Design document
│       └── 2025-10-22-docker-factory-script-implementation.md # Implementation plan (10 tasks)
├── DOCKER_DEV_USAGE.md               # Usage guide (will be created)
├── CLAUDE.md                         # This file
└── .gitignore                        # Excludes .dockerdev/
```

### Container Lifecycle

1. **Build Phase:** Detect project type → Generate Dockerfile → Build image (cached by type)
2. **Runtime Phase:** Mount repo at `/workspace` → Start container → Set `CLAUDE_CODE_ACCEPT_PERMISSIONS=true` and `CLAUDE_CODE_MODE=yolo`
3. **Extraction Phase:** `docker cp /workspace` → Back up original → `rsync` changes back → `git status` shows diff
4. **Cleanup:** `docker stop` container → Remove image

### Metadata Directory (`.dockerdev/`)

Created per session, excluded from git. Contains:
- `container-id` — Running container ID (created after start)
- `image-id` — Built image name (created after build)
- `repo-path` — Absolute path to repo root
- `Dockerfile` — Generated Dockerfile (for reference)
- `build.log` — Docker build output (if build failed)

## Common Commands

### Implementation Tasks (from plan)

The implementation is structured as 10 tasks in `docs/plans/2025-10-22-docker-factory-script-implementation.md`:

1. **Scaffold** — Create `bin/docker-dev`, argument parsing, `.gitignore`
2. **Detection** — Implement `detect_project_type()`, `get_base_image()`
3. **Dockerfile Node.js** — Create `templates/Dockerfile.nodejs` template
4. **Dockerfile Python** — Create `templates/Dockerfile.python-pip` and `python-modern`
5. **Dockerfile Go/Fallback** — Create `templates/Dockerfile.golang` and `ubuntu`
6. **Build & Run** — Implement `build_docker_image()`, `run_docker_container()`, `start_container()`
7. **Extraction** — Implement `copy_workspace_from_container()`, `extract_changes()`
8. **Helpers** — Implement `show_status()`, `stop_container()`, `clean_image()`
9. **Validation** — Add `check_docker()`, `validate_repo_path()`, error handling
10. **Documentation** — Create `DOCKER_DEV_USAGE.md`

### Development & Testing

**Start a container:**
```bash
./bin/docker-dev start /path/to/repo
```
Detects project, generates Dockerfile, builds image, starts interactive shell with `/workspace` mounted.

**Extract changes:**
```bash
./bin/docker-dev extract
```
Copies changes from container to repo, creates backup.

**Stop container:**
```bash
./bin/docker-dev stop
```
Stops running container, clears metadata.

**View status:**
```bash
./bin/docker-dev status
```
Shows container and image status.

**Clean image:**
```bash
./bin/docker-dev clean
```
Removes Docker image.

### Testing (Project Detection)

Manual validation of detection logic (from Task 2 in plan):
```bash
source ./bin/docker-dev
detect_project_type /path/to/nodejs-project    # Should output: nodejs
detect_project_type /path/to/python-project    # Should output: python-pip or python-modern
detect_project_type /path/to/go-project        # Should output: golang
detect_project_type /path/to/empty-project     # Should output: ubuntu (fallback)
```

## Key Design Decisions

### Safety Model

- **Full Isolation:** Container cannot modify host. Runaway processes contained.
- **Ephemeral Containers:** No persistent state between sessions.
- **Explicit Extraction:** User controls what comes back to repo.
- **Auto-Accept Prompts:** `CLAUDE_CODE_ACCEPT_PERMISSIONS=true` environment variable.

### Project Detection Strategy

Priority order (first match wins):
1. `package.json` → Node.js
2. `pyproject.toml` → Python (modern)
3. `requirements.txt` → Python (pip)
4. `go.mod` → Go
5. `Dockerfile` → Custom (use as-is)
6. None → Ubuntu fallback

### Image Naming

Convention: `claude-code-{project-type}-{unix-timestamp}`

Example: `claude-code-nodejs-1729606800`

This ensures:
- Easy identification in `docker images`
- Unique names per build (timestamps prevent conflicts)
- Type-aware caching (rebuild same project = reuse if unchanged)

### Volume Mounts & Working Directory

- `/workspace` mounted to repo root (read-write for Claude Code edits)
- Container working directory set to `/workspace`
- All scripts and tools run from within `/workspace`

### Dockerfile Templates

Each template:
- Installs base dependencies (bash, curl, git, ca-certificates)
- Sets `WORKDIR /workspace`
- Installs project dependencies (npm ci, pip install, go mod download)
- Sets `CLAUDE_CODE_ACCEPT_PERMISSIONS=true` and `CLAUDE_CODE_MODE=yolo`
- Runs `/bin/bash -i` for interactive sessions

## Important Notes for Future Work

### Prerequisites for Testing

- Docker Desktop must be installed and running
- WSL2 compatibility (script tested on WSL2 + Docker Desktop)
- bash 4.0+ required
- rsync required for extraction (install if missing)

### Error Handling

Each major function should:
1. Check Docker availability early (`check_docker()`)
2. Validate repo path exists and is readable (`validate_repo_path()`)
3. Capture build errors to `.dockerdev/build.log`
4. Provide clear error messages with context

### Git Integration

- Repo path assumed to be git-initialized for extraction to show `git status`
- `.dockerdev/` always excluded from commits (in `.gitignore`)
- Backups created as `{repo}.backup.{timestamp}` if extraction needed

### WSL2 Considerations

- File sync through Docker volumes can be slow on WSL2
- Image caching helps reduce rebuild time
- Container startup is generally fast (seconds)

## Links to Key Documentation

- **Design Doc:** `docs/plans/2025-10-22-claude-code-yolo-docker-design.md` — Full architecture, requirements, security model
- **Implementation Plan:** `docs/plans/2025-10-22-docker-factory-script-implementation.md` — 10 tasks with code snippets and verification steps
- **Usage Guide:** `DOCKER_DEV_USAGE.md` (to be created) — End-user documentation with workflows and troubleshooting
