# Claude Code Yolo Mode Docker Design
**Date:** 2025-10-22
**Context:** Secure, ephemeral development environment for Claude Code sessions with auto-accepting permission prompts

---

## Overview

A factory script that creates isolated Docker containers for Claude Code sessions. Containers are ephemeral, sandbox-safe, and designed for "yolo mode" rapid iteration without risk to live systems.

**Core Safety Model:** Containerization prevents runaway processes from affecting live data. Changes are explicitly extracted back to the repository only when verified safe.

---

## Requirements

### Functional
- Accept repo path as input
- Auto-detect project type from dependency files (package.json, requirements.txt, pyproject.toml, Dockerfile, go.mod)
- Generate appropriate Dockerfile based on detected type
- Build and start container with auto-accepting Claude Code permission prompts
- Mount repo at `/workspace` with read-write access
- Container persists across idle periods within a session
- Extract code + updated dependency files back to repo after session
- Discard container and image when session ends

### Non-Functional
- Must work on WSL2 with Docker Desktop
- Fast startup times (minimal layer rebuilding)
- Container should be memory-efficient
- No persistent docker state between sessions

### Security (Yolo Mode)
- Full isolation: Changes inside container cannot affect host/live data
- Auto-accept Claude Code permission prompts (environment variable override)
- Non-interactive prompts get default responses
- User controls extraction: Bad sessions discarded, good sessions extracted explicitly

---

## Architecture

### Container Lifecycle

1. **Build Phase**
   - Script inspects repo root for dependency markers
   - Generates minimal Dockerfile tailored to project type
   - Builds image (cached for fast rebuilds of unchanged repos)

2. **Runtime Phase**
   - Starts container with volume mounts
   - Repo mounted at `/workspace` (read-write)
   - Optional `/data` mount for persistent session data
   - Claude Code runs inside with permission prompts auto-accepted
   - Container stays running until explicitly stopped

3. **Extraction Phase**
   - User runs `docker-dev extract` to copy changes back
   - Copies `/workspace/*` → repo directory
   - Captures updated dependency files (package.json, requirements.txt, etc.)
   - User commits changes to git

4. **Cleanup Phase**
   - `docker-dev stop` → Removes running container
   - `docker-dev clean` → Removes image
   - Between sessions: No persistent docker state

### Project Type Detection

| Marker File | Project Type | Base Image | Package Manager |
|---|---|---|---|
| `package.json` | Node.js | `node:lts-alpine` | npm/yarn |
| `requirements.txt` | Python (pip) | `python:3.11-slim` | pip |
| `pyproject.toml` | Python (modern) | `python:3.11-slim` | pip/uv |
| `go.mod` | Go | `golang:1.21-alpine` | go |
| `Dockerfile` | Custom | Use as-is | N/A |
| None/Ambiguous | Fallback | `ubuntu:24.04` | apt-get |

### Volume Mounts

- `/workspace` → Repository root (read-write for editing)
- `/data` → Optional persistent directory per session
- `/tmp` → Ephemeral working space

### Environment Variables

- `CLAUDE_CODE_ACCEPT_PERMISSIONS=true` → Auto-accept Claude Code prompts
- `CLAUDE_CODE_MODE=yolo` → Signal unsafe mode to Claude Code
- Project-specific vars from repo (if `.dockerdev/env` exists)

---

## Script Interface

### Primary Commands

```bash
# Start/create container for repo
docker-dev /path/to/repo [--name container-name]

# Extract changes back to repo
docker-dev extract

# Stop container (discard changes)
docker-dev stop [--discard]

# View container status
docker-dev status

# Clean up image
docker-dev clean
```

### Metadata Storage

Container metadata stored in `.dockerdev/` directory:
- `.dockerdev/container-id` → Current running container ID
- `.dockerdev/image-id` → Built image ID
- `.dockerdev/Dockerfile` → Generated Dockerfile (for reference)
- `.dockerdev/config.yaml` → Session configuration

---

## Security Model

### What's Protected
- **Host system:** Containerized process cannot escape or modify host files
- **Live data:** Anything outside repo is unreachable from container
- **Data exfiltration:** Only explicit extraction pulls data out
- **Session isolation:** Each container is independent; old sessions don't affect new ones

### What's NOT Protected
- **Malicious intent within container:** User assumes responsibility for code reviewed by Claude
- **Source code exposure:** Code runs in container; assume Claude has visibility
- **Performance DOS:** Runaway processes inside container are contained but could consume resources

### Design Assumption
- User trusts Claude Code's decision-making
- User reviews extracted changes before committing
- Safety comes from isolation (runaway processes can't escape), not from detection

---

## Data Flow

```
User calls: docker-dev /path/to/repo
    ↓
Script detects project type (package.json, requirements.txt, etc.)
    ↓
Generate Dockerfile + mount bindings
    ↓
Build image (cached if unchanged)
    ↓
Start container with /workspace mount
    ↓
Claude Code session begins (auto-accepts prompts)
    ↓
Code + package changes made inside /workspace
    ↓
Session ends - user inspects output
    ↓
User calls: docker-dev extract
    ↓
Copy /workspace → repo directory
    ↓
Capture updated package files (package.json, requirements.txt, etc.)
    ↓
User commits to git
    ↓
docker-dev stop (container discarded)
    ↓
Next session: Build fresh container from updated repo state
```

---

## Implementation Priorities

1. **Core script** (bash) - argument parsing, detection logic, docker commands
2. **Dockerfile generation** - templates for Node, Python, Go, fallback
3. **Extract mechanism** - copy changes back cleanly
4. **Helper commands** - status, cleanup, stop
5. **Error handling** - clear messages when detection fails
6. **Documentation** - usage guide and troubleshooting

---

## Known Constraints

- WSL2 + Docker Desktop required
- Auto-accept works only if Claude Code respects `CLAUDE_CODE_ACCEPT_PERMISSIONS` env var
- Performance depends on host Docker daemon (WSL2 can be slower than native Docker)
- Image caching helps but large projects may rebuild slowly
- File sync between container and host depends on Docker volumes (usually fast, occasionally slow on WSL2)

---

## Next Steps

- Create implementation plan with specific tasks
- Build core script with detection + build logic
- Test on sample projects (Node, Python, mixed)
- Implement extraction and cleanup
- Document usage and add error handling
