# docker-dev Usage Guide

`docker-dev` creates ephemeral, containerized development environments for multi-service projects. It supports projects with Node.js, Python, Go, or any combination thereof.

## Prerequisites and Setup

### System Requirements

`docker-dev` requires:
- **Docker** - Container runtime (installation varies by OS)
- **jq** - JSON command-line processor
- **rsync** - File synchronization tool
- **bash 4.0+** - Already present on most systems

### Automated Setup

The easiest way to install all prerequisites is to run the setup script:

```bash
./bin/setup-docker-dev
```

**What the setup script does:**
1. Detects your operating system
2. Installs Docker (if not present)
3. Installs jq (if not present)
4. Installs rsync (if not present)
5. Verifies Docker daemon is running
6. Builds a test Docker image to verify everything works
7. Shows next steps

**For different scenarios:**

```bash
# Skip Docker installation (assume already installed)
./bin/setup-docker-dev --skip-docker

# Skip building the test image
./bin/setup-docker-dev --skip-build

# Show help
./bin/setup-docker-dev --help
```

### Manual Installation

If you prefer to install prerequisites manually:

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y docker.io jq rsync
sudo usermod -aG docker $USER  # Add your user to docker group
sudo systemctl start docker
```

**Fedora/RedHat:**
```bash
sudo dnf install -y docker jq rsync
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```

**macOS (with Homebrew):**
```bash
brew install --cask docker  # Docker Desktop
brew install jq rsync
# Start Docker Desktop from Applications
```

**Windows:**
1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop)
2. Configure WSL2 backend in Docker Settings
3. Install jq and rsync in WSL2:
   ```bash
   sudo apt-get install -y jq rsync
   ```

### Verify Installation

After installation, verify everything works:

```bash
# Check Docker
docker ps

# Check jq
jq --version

# Check rsync
rsync --version

# Check docker-dev script
./bin/docker-dev help
```

---

## Quick Start

### 1. Add config4Docker.json to Your Repo

```json
{
  "services": {
    "web": {
      "runtime": "node",
      "port": 3000,
      "startCommand": "npm start"
    },
    "api": {
      "runtime": "python",
      "port": 3001,
      "startCommand": "python -m api.server"
    }
  },
  "systemPackages": ["ffmpeg"],
  "externalAPIs": ["http://localhost:3000", "http://localhost:3001"]
}
```

### 2. Start a Development Container

```bash
./bin/docker-dev start
```

This will:
1. Validate your config
2. Build a Docker image
3. Start a container with all services
4. Drop you into an interactive shell

### 3. Work Inside the Container

```bash
# You're now inside the container with /workspace mounted to your repo
npm --version
python3 --version
supervisorctl status  # See all running services
supervisorctl restart web  # Restart specific service
```

### 4. Extract Changes Back to Your Repo

When done:

```bash
# On your host machine:
./bin/docker-dev extract
```

This copies changes from the container back to your repo and shows:
```
git status
```

### 5. Stop the Container

```bash
./bin/docker-dev stop
```

## Configuration Reference

### config4Docker.json

```json
{
  "services": {
    "serviceName": {
      "runtime": "node|python|custom",
      "port": 3000,
      "startCommand": "command to start service"
    }
  },
  "systemPackages": [
    "optional-system-packages",
    "like-ffmpeg"
  ],
  "externalAPIs": [
    "http://localhost:3000",
    "optional-for-future-tooling"
  ]
}
```

### Required Fields

- **services** — Object with at least one service
- **runtime** — "node", "python", or "custom"
- **port** — Numeric port (not required to be unique; for documentation)
- **startCommand** — Command to start the service

### Optional Fields

- **systemPackages** — List of system packages (apt-get install)
- **externalAPIs** — List of URLs (reserved for future integrations)

## Supported Project Types

### Node.js Only

```json
{
  "services": {
    "web": {
      "runtime": "node",
      "port": 3000,
      "startCommand": "npm start"
    }
  }
}
```

Requires: `package.json`

### Python Only

```json
{
  "services": {
    "api": {
      "runtime": "python",
      "port": 5000,
      "startCommand": "python -m app.server"
    }
  }
}
```

Requires: `requirements.txt` or `pyproject.toml`

### Hybrid (Node + Python)

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
  }
}
```

Requires: `package.json` AND (`requirements.txt` OR `pyproject.toml`)

## Common Commands

### Start container in current directory

```bash
./bin/docker-dev start
```

### Start container for specific repo

```bash
./bin/docker-dev start /path/to/repo
```

### View container and image status

```bash
./bin/docker-dev status
```

### See what changed in your repo

```bash
cd /path/to/repo
./bin/docker-dev extract
git status
```

### Stop the running container

```bash
./bin/docker-dev stop
```

### Remove the built image

```bash
./bin/docker-dev clean
```

### Get help

```bash
./bin/docker-dev help
```

## Troubleshooting

### Docker daemon not responding

**Error:** `ERROR: Docker daemon not responding`

**Solution:**
```bash
# On Windows/Mac: Restart Docker Desktop
# On Linux:
sudo systemctl restart docker
```

### config4Docker.json not found

**Error:** `ERROR: config4Docker.json not found`

**Solution:** Create `config4Docker.json` in repo root (see Configuration section)

### Container shell exits immediately

**Symptom:** Container starts but shell closes instantly

**Solution:**
- Check for errors in your service start commands
- Verify `requirements.txt` or `package.json` are valid
- Run with verbose logging (see logs in `.dockerdev/build.log`)

### Changes not extracted

**Error:** `ERROR: No running container found`

**Solution:**
```bash
# Container may have stopped. Check status:
./bin/docker-dev status

# Restart if needed:
./bin/docker-dev start
```

### Slow I/O on WSL2

**Symptom:** Container operations feel slow

**Solution:**
- Move repository to WSL filesystem: `/home/user/...` (not Windows C:\)
- Slower mounts are normal when on Windows filesystem

### Service won't start

**Symptom:** See "FATAL" in supervisorctl output

**Solution:**
1. Get into container shell
2. Run your start command manually:
   ```bash
   npm start  # or python -m app.server
   ```
3. Check for actual error messages
4. Update `startCommand` in `config4Docker.json`

## Advanced Usage

### Monitor service logs in real-time

```bash
# In container shell:
supervisorctl tail -f web
supervisorctl tail -f trading
```

### Restart all services

```bash
# In container shell:
supervisorctl restart all
```

### Run arbitrary commands

```bash
# In container shell:
node scripts/migrate.js
python -m pytest
npm test
```

### Persistent changes during development

Any changes you make inside `/workspace` will be extracted when you run:
```bash
./bin/docker-dev extract
```

Changes are merged back to your repo with a timestamped backup created first.

## Known Limitations

- **WSL2 + Windows Filesystem:** I/O is slower. Keep repos in WSL filesystem.
- **Services on same port:** Port numbers in config are for documentation only; actual binding happens in start commands.
- **No health checks:** Services are assumed to start correctly. Verify manually with `supervisorctl status`.
- **Single container per repo:** `docker-dev start` in same repo creates new container each time.

## Development Model

`docker-dev` is designed for **development** workflows:

1. **Ephemeral containers** — Throw away after each session
2. **Manual service control** — Full shell access for debugging
3. **Explicit configuration** — No magic detection
4. **Secure isolation** — Changes only extracted when you run `extract`

For production deployment, use standard Docker practices and deployment tools.

## Recent Updates & Fixes

### Latest Improvements (October 24, 2025)

- **Fixed container-id metadata corruption** - Diagnostic messages (`INFO:` lines) were being captured in the container-id file, preventing extraction from working. Fixed by redirecting all `info()` output to stderr.
- **Improved container ID matching** - Container validation now uses `docker ps --no-trunc` to properly match full-length container IDs against stored metadata.
- **Comprehensive documentation** - Added message2futureagent.md with architecture details, known issues, testing procedures, and debugging tips for future developers.

## See Also

- **Developer Guide:** `message2futureagent.md` - Architecture, known issues, testing procedures, and debugging tips
- **Design Document:** `docs/plans/2025-10-23-config-driven-multi-service-docker-design.md`
- **Implementation Plan:** `docs/plans/2025-10-23-config-docker-implementation.md`
- **Docker Documentation:** https://docs.docker.com/
- **Supervisor Documentation:** http://supervisord.org/
