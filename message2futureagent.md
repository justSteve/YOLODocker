# Message to Future Developers

Welcome! This document provides context about the `docker-dev` project to help you understand the architecture, known issues, and development patterns.

## Project Overview

**buildDockers** is a Docker factory tool that creates ephemeral, containerized development environments for multi-service projects. The core deliverable is `bin/docker-dev` — a bash script that manages the full container lifecycle: configuration validation, image building, container startup, service management via Supervisor, and safe extraction of changes.

**Key Design Philosophy:** Configuration-driven (not auto-detection). Users provide explicit `config4Docker.json` files that declare all services, runtimes, and startup commands. No magic detection.

## Architecture at a Glance

..
bin/docker-dev (main entrypoint)
  ├── lib/config.sh (validate config4Docker.json)
  ├── lib/docker-ops.sh (build, run, stop containers)
  ├── lib/extraction.sh (rsync changes back from container)
  ├── lib/metadata.sh (track container/image IDs in .dockerdev/)
  └── lib/supervisor-config.sh (generate supervisor config from JSON)

templates/
  ├── Dockerfile.universal (Ubuntu + Node + Python + Supervisor)
  ├── entrypoint.sh (auto-install deps, generate supervisor config)
  ├── generate-supervisor-config.py (read JSON → supervisord.conf)
  └── supervisord.conf.template (supervisor base config)

bin/setup-docker-dev (automated prerequisite installer)
```

**Container Lifecycle:**
1. User calls `./bin/docker-dev start`
2. Validate config → Build image → Start container with `/workspace` mounted
3. Drop into interactive shell for development
4. Call `./bin/docker-dev extract` to copy changes back
5. Call `./bin/docker-dev stop` to stop container

## Critical Implementation Details

### 1. Output Redirection (Fixed in Latest Commit)

**Problem:** The `info()` function was outputting to stdout, which meant when capturing data like container IDs, info messages would get mixed in.

**Solution:** All `info()` calls redirect to stderr with `>&2`:
```bash
info() {
  echo "INFO: $*" >&2
}
```

**Impact:** This ensures stdout contains only actual data (container IDs, etc.), while diagnostic messages go to stderr.

**Why it matters:** If you modify the `info()` function or add similar diagnostic functions, always use `>&2`.

### 2. Docker Container ID Matching

**Problem:** `docker ps -q` returns short 12-character IDs, but we store full 64-character IDs. The grep check would fail.

**Solution:** Use `docker ps -q --no-trunc` in extraction validation:
```bash
docker ps -q --no-trunc | grep -q "$container_id"
```

**Location:** `bin/docker-dev` line ~197 in `cmd_extract()`

**Why it matters:** If you add other container operations that verify a running container, use `--no-trunc` to match against stored full IDs.

### 3. Supervisor Command Wrapping

**Problem:** Supervisor executes commands directly without shell interpretation, so compound commands like `node server.js && sleep 300` fail.

**Solution:** Wrap all commands in `sh -c`:
```python
wrapped_cmd = f'sh -c "{start_cmd}"'
# Results in: command=sh -c "node server.js && sleep 300"
```

**Location:** `templates/generate-supervisor-config.py` line ~43

**Why it matters:** If you modify how services are started or add new shell features, remember commands need shell wrapping.

### 4. Build Context Path

**Problem:** Docker build context must point to the directory containing files referenced in COPY instructions.

**Solution:** Calculate build context from Dockerfile path:
```bash
local build_context="$(dirname "$(dirname "$dockerfile_path")")"
# If dockerfile = /root/projects/buildDockers/templates/Dockerfile.universal
# Then build_context = /root/projects/buildDockers (parent of templates/)
```

**Location:** `bin/lib/docker-ops.sh` line ~47

**Why it matters:** If you add new templates or change where files are located, verify the build context logic.

## Testing Procedures

### Manual End-to-End Test

```bash
# 1. Create test project
mkdir ~/test-docker-dev && cd ~/test-docker-dev
git init

# 2. Create config4Docker.json
cat > config4Docker.json <<'EOF'
{
  "services": {
    "web": {
      "runtime": "node",
      "port": 3000,
      "startCommand": "node --version && sleep 300"
    }
  }
}
EOF

# 3. Create package.json (required by Node)
echo '{"name": "test"}' > package.json

# 4. Start container
/root/projects/buildDockers/bin/docker-dev start

# 5. Inside container, verify:
supervisorctl status  # Should show 'web' running
node --version        # Should output version

# 6. Exit container (Ctrl+D or 'exit')

# 7. Extract changes
/root/projects/buildDockers/bin/docker-dev extract

# 8. Check changes
git status

# 9. Stop container
/root/projects/buildDockers/bin/docker-dev stop
```

### Verify Setup Script Works

```bash
cd /root/projects/buildDockers
./bin/setup-docker-dev --skip-docker  # Skip Docker, test jq/rsync install
```

**What to watch for:**
- All prerequisite checks should pass (✓)
- Docker daemon connection should succeed
- Test image should build without errors
- Node.js and Python should be detectable in the image

## Known Limitations & Future Work

### Current Limitations

1. **Single container per directory** - Running `docker-dev start` twice in same directory creates a new container each time (old one still running)
2. **No health checks** - Services are assumed to start correctly; failures aren't caught
3. **No networking between services** - Services run in same container but don't auto-discover
4. **Basic supervisor config** - No logging rotation, limited error recovery
5. **Manual extraction** - Must explicitly call `extract` to get changes back (no auto-sync)

### Future Enhancement Ideas

From user feedback and design discussions:

1. **Service discovery** - Parse supervisor output to auto-discover running services
2. **Health checks** - Add startup verification to catch failing services
3. **Multi-container orchestration** - Docker Compose integration for service isolation
4. **Selective extraction** - Allow extracting only specific files/directories
5. **Change detection** - Auto-detect changes without explicit extraction call
6. **Custom Dockerfiles** - Support users bringing their own Dockerfile in config
7. **Environment variables** - Allow passing secrets/config into container via JSON

## Debugging Tips

### Check Docker Build Output

If `docker-dev start` fails during build:

```bash
# Look at build log
cat .dockerdev/build.log

# Or rebuild manually with full output:
docker build -f /root/projects/buildDockers/templates/Dockerfile.universal \
  -t test-image /root/projects/buildDockers
```

### Check Supervisor Status Inside Container

```bash
# Attach to running container
docker exec -it <container-id> /bin/bash

# View supervisor status
supervisorctl status

# View logs for specific service
supervisorctl tail -f web

# Try running service command manually
node --version
```

### Check Metadata Files

```bash
# View what's tracked
cat .dockerdev/container-id
cat .dockerdev/image-id
cat .dockerdev/config.json

# See Docker layer sizes
docker images claude-code-dev* --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

### Enable Verbose Mode

Most library functions use `info()` for diagnostics. These go to stderr, so you can see them while stdout captures data:

```bash
./bin/docker-dev start 2>&1 | less  # See all output including diagnostics
```

## Code Organization

### Key Functions by File

**bin/docker-dev:**
- `cmd_start()` - Start container workflow
- `cmd_extract()` - Extract changes from container
- `cmd_stop()` - Stop running container
- `cmd_status()` - Show metadata and Docker status
- `cmd_clean()` - Remove built image
- `cmd_help()` - Display usage

**bin/lib/config.sh:**
- `load_config()` - Parse JSON config file
- `validate_config()` - Check required fields
- `check_jq()` - Verify jq is available

**bin/lib/docker-ops.sh:**
- `generate_image_name()` - Create timestamped image name
- `build_docker_image()` - Run docker build
- `run_docker_container()` - Start container with volumes
- `stop_docker_container()` - Stop and remove container
- `show_container_status()` - List running containers
- `show_image_status()` - List built images

**bin/lib/extraction.sh:**
- `extract_changes()` - Copy workspace from container, merge back
- `show_extraction_summary()` - Display what changed

**bin/lib/metadata.sh:**
- `init_metadata()` - Create .dockerdev directory
- `save_image_metadata()` - Record image name and timestamp
- `save_container_metadata()` - Record container ID and config
- `show_metadata()` - Display saved metadata

**bin/lib/supervisor-config.sh:**
- `check_supervisor()` - Verify supervisor is available
- `generate_supervisor_config()` - Call Python generator

**templates/generate-supervisor-config.py:**
- `generate_supervisor_config()` - Main function
- Reads `config4Docker.json`, generates `supervisord.conf`

### Configuration Schema

The `config4Docker.json` schema (validated in `config.sh`):

```typescript
{
  services: {
    [serviceName: string]: {
      runtime: "node" | "python" | "custom",
      port: number,
      startCommand: string
    }
  },
  systemPackages?: string[],    // Installed via apt-get
  externalAPIs?: string[]        // For future tooling
}
```

## Recent Fixes (Latest Commits)

1. **Container-ID Corruption** - Redirected `info()` output to stderr to prevent mixing with data
2. **Container ID Matching** - Added `--no-trunc` to docker ps for full ID matching
3. **Supervisor Command Wrapping** - Ensured all commands wrapped in `sh -c` for shell operators
4. **Build Context** - Fixed path calculation to point to repo root for COPY instructions
5. **Setup Script Returns** - Added explicit `return 0` to test functions for proper exit codes

## Style Guidelines

### Bash Script Patterns

**Error handling:**
```bash
error() {
  echo "" >&2
  echo "ERROR: $*" >&2
  echo "Run './bin/docker-dev help' for usage information" >&2
  exit 1
}
```

**Informational output:**
```bash
info() {
  echo "INFO: $*" >&2
}
```

**Data output (captured by parent):**
```bash
echo "actual-data-only"  # No redirection - goes to stdout
```

**Variable capture:**
```bash
local value=$(function_that_returns_data)  # Captures stdout only
```

### File organization

- Library files in `bin/lib/` with `.sh` extension
- Main script as `bin/docker-dev` (no extension)
- Templates in `templates/` with appropriate extensions
- Documentation in project root and `docs/plans/`

## Testing Checklist for New Features

When adding new features:

- [ ] Write feature with stderr redirection for diagnostics
- [ ] Test with end-to-end workflow (start → use → extract → stop)
- [ ] Verify metadata files are created/updated correctly
- [ ] Check Docker output for expected messages
- [ ] Test error paths with invalid input
- [ ] Verify changes are properly extracted
- [ ] Update DOCKER_DEV_USAGE.md if user-facing
- [ ] Add comments explaining non-obvious logic
- [ ] Test on both Linux and WSL2 if possible

## Contact Points with External Systems

### Docker API
- Build: `docker build -f <dockerfile> -t <image> <context>`
- Run: `docker run -d -v <mount> <image> <cmd>`
- Inspect: `docker ps`, `docker images`
- Cleanup: `docker stop`, `docker rmi`

### Supervisor
- Config file: `/etc/supervisor/supervisord.conf`
- Socket: `/tmp/supervisor.sock`
- Control: `supervisorctl status`, `supervisorctl tail`

### File Systems
- Mount point: `/workspace` (maps to repo root)
- Working directory: `/workspace`
- Extraction: `docker cp` + `rsync`

### Shell/Bash
- Minimum: bash 4.0+ (associative arrays)
- Libraries: sourced from `bin/lib/`
- Error set: `set -euo pipefail` in main scripts

## Performance Considerations

1. **Image building** - First build is slow, subsequent runs are cached
2. **WSL2 I/O** - Slow on Windows filesystem; use WSL filesystem
3. **Extraction time** - Depends on repo size; `rsync` is efficient
4. **Container startup** - Usually <5 seconds after image is ready

## What Else Should I Know?

- **Git integration** - Assumes repo is git-initialized for extraction to show diffs
- **Security** - Container runs with user's docker permissions; not production-grade
- **Ephemeral design** - Containers are meant to be thrown away; don't use for persistent state
- **Config-driven** - Configuration is the single source of truth, not detection
- **Supervisor nodaemon=true** - Required for Docker (Supervisor should not daemonize)

---

Good luck with development! If you're fixing bugs or adding features, test thoroughly and update this document with new patterns or issues you discover.
