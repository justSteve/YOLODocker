# Config-Driven Multi-Service Docker Development Environment

**Date:** 2025-10-23
**Status:** Design (validated)
**Scope:** Refined architecture for `bin/docker-dev` with explicit configuration model

---

## Problem Statement

The previous auto-detection model adds complexity without clear benefit:
- Detection logic must handle edge cases (hybrid projects, custom setups)
- Difficult to debug when detection fails silently
- Projects are already self-documenting (manifest files declare dependencies)

## Core Insight

Language package manifests (package.json, requirements.txt, go.mod) are **already self-contained**—like .NET project files. They don't need detection. Only **system-level packages** (ffmpeg, postgresql-client) fall outside standard package managers and require explicit declaration.

**Corollary:** Support multi-service projects (Node web + Python backend in same container) as a first-class pattern, not an edge case.

---

## Design: Eliminate Detection, Use Explicit Configuration

### 1. Single Universal Container Image

**Base Image:** Node + Python runtime (Alpine or standard Ubuntu)

**Auto-Install on Startup:**
- If `package.json` exists → run `npm ci`
- If `requirements.txt` exists → run `pip install -r requirements.txt`
- If `go.mod` exists → run `go mod download`
- Install all that are present (no detection, just "if it exists, use it")

**Rationale:**
- Hybrid projects (TypeScript + Python) work automatically
- No detection logic needed
- Single image serves all project types (Node-only, Python-only, Hybrid)
- Simplicity over image size optimization (revisit only if bloat becomes measurable problem)

### 2. Configuration File: config4Docker.json

**Location:** Repository root (checked in)

**Purpose:** Declare what auto-install cannot handle + multi-service orchestration

**Schema:**

```json
{
  "services": {
    "serviceName": {
      "runtime": "node|python|custom",
      "port": 3000,
      "startCommand": "npm start"
    }
  },
  "systemPackages": [
    "ffmpeg",
    "postgresql-client"
  ],
  "externalAPIs": [
    "http://localhost:3000",
    "http://localhost:3001"
  ]
}
```

**Required fields:**
- `services` — At least one service must be declared
- Each service needs: `runtime`, `port`, `startCommand`

**Optional fields:**
- `systemPackages` — Empty array if none needed
- `externalAPIs` — For future integration with host-level tooling (voice control, shortcuts)

**Example: Node + Python Hybrid Project**

```json
{
  "services": {
    "web": {
      "runtime": "node",
      "port": 3000,
      "startCommand": "npm start"
    },
    "trading": {
      "runtime": "python",
      "port": 3001,
      "startCommand": "python -m trading.service"
    }
  },
  "systemPackages": [],
  "externalAPIs": [
    "http://localhost:3000",
    "http://localhost:3001"
  ]
}
```

### 3. Process Management: Supervisor

**Tool:** Supervisor (language-agnostic process manager)

**Why:**
- Treats all services uniformly (doesn't care if Node or Python)
- Auto-starts all services on container entry
- Unified log output to stdout/stderr
- Restarts failed services (configurable)
- Single configuration file (generated from config4Docker.json)

**Development-focused behavior:**
- Services auto-start on container entry
- No health checks (development tool, not production)
- User can manually restart/debug services in shell
- Container stays running until user exits
- Failures are immediately visible in unified log stream

### 4. Container Startup Flow

1. **Build phase:** Dockerfile built once per project type
2. **Run phase:**
   - Container starts
   - Auto-install from detected manifests (package.json, requirements.txt, etc.)
   - Install system packages declared in config
   - Generate Supervisor config from config4Docker.json
   - Start Supervisor (auto-starts all services)
   - Unified log output visible to user
   - Drop user into interactive shell (bash)
3. **User can:**
   - Monitor logs in real-time
   - Manually restart services via `supervisorctl`
   - Debug in shell
   - Exit when done

### 5. Metadata Storage

**Location:** `.dockerdev/` directory (git-ignored)

**Contents:**
- `container-id` — Running container ID
- `image-id` — Built image name/ID
- `config.json` — Copy of active config4Docker.json (for reference)
- `supervisor.conf` — Generated Supervisor config
- `build.log` — Docker build output (if needed for debugging)

---

## What This Design Removes

- **No auto-detection logic** — Config4Docker.json is source of truth
- **No project-type selection** — Single universal image works for all
- **No complex fallbacks** — Projects without config must provide it (explicit requirement)
- **No health checks or auto-restart** — Development tool, user controls lifecycle

---

## What This Design Enables

- **Multi-service projects work naturally** — Declare services in config, Supervisor manages them
- **Hybrid projects (TypeScript + Python) just work** — No special handling
- **Turnkey startup** — Auto-install + auto-start + unified logging
- **Interactive debugging** — User can shell in, restart services, see logs
- **Future extensibility** — `externalAPIs` field reserved for host-level tool integration

---

## Known Constraints & Notes

### WSL2 / Windows Filesystem

If running on Windows with WSL2:
- **Repos on Windows filesystem (C:\...)** — Slower I/O due to cross-filesystem mounting
- **Repos on WSL filesystem (/home/...)** — Native speed, recommended
- Docker Desktop with WSL2 backend handles mounting, but filesystem choice impacts performance

### Requirements for Repo Owners

1. **config4Docker.json must exist** — Explicit contract; no fallback to detection
2. **Manifest files must be maintained** — package.json, requirements.txt, etc. are auto-installed
3. **System packages must be declared** — Only exceptioncase (ffmpeg, postgresql-client, etc.)

---

## Validation Checklist

- [x] Eliminates auto-detection complexity
- [x] Supports hybrid projects (Node + Python) as first-class
- [x] Turnkey startup with unified logging
- [x] Interactive shell for debugging
- [x] Single configuration file (config4Docker.json)
- [x] Development-focused (no production features)
- [x] Notes WSL2/Windows filesystem constraints
- [x] Reserved for future voice/keyboard integration (externalAPIs field)

---

## Next Steps

1. **Phase 5:** Create implementation plan (10 tasks)
2. **Phase 6:** Set up git worktree for development
3. Build Dockerfile and bin/docker-dev script
4. Create Supervisor config generation logic
5. Test with sample projects (Node-only, Python-only, Hybrid)

