# Proof Server Management Guide

Quick reference for managing the Midnight proof server.

_Note: The proof server implementation lives in the midnight-ledger repository. This guide focuses on building, starting, stopping, and monitoring the proof server built from that codebase._

## Quick Start

### Build and Run

```bash
# Build
./manage-proof-server.sh build

# Start server
./manage-proof-server.sh start

# Check status
./manage-proof-server.sh status

# Stop server
./manage-proof-server.sh stop
```

### Using Pre-built Binary

```bash
# From different branch/build
BINARY_PATH=../other-branch/target/release/midnight-proof-server ./manage-proof-server.sh start

# From custom location
./manage-proof-server.sh --binary-path /opt/midnight/proof-server start
```

## Common Commands

```bash
build              # Build the proof server binary
start              # Start the server
stop               # Stop the server
restart            # Restart the server
status             # Show status and health check
logs               # Watch server logs (tail -f)
monitor            # Monitor with auto-restart
config             # Show current configuration
check-gpu          # Verify GPU support (if enabled)
```


### Generate Config File

```bash
./manage-proof-server.sh generate-config
# Creates: proof-server.conf
```

### Config File Options

```bash
# Binary Configuration
BINARY_PATH=/path/to/binary              # Direct path to binary
BINARY_NAME=midnight-proof-server        # Binary name (if renamed)
PROJECT_ROOT=/path/to/project            # For building

# Server
PORT=6300                                # Server port
VERBOSE=true                             # Enable verbose logging

# Workers
NUM_WORKERS=4                            # Number of worker threads
JOB_CAPACITY=10                          # Job queue capacity
JOB_TIMEOUT=600.0                        # Job timeout (seconds)

# Files
PID_FILE=/tmp/proof-server.pid
LOG_FILE=/tmp/proof-server.log

# Monitoring
HEALTH_CHECK_INTERVAL=30                 # Health check interval (seconds)
MAX_RESTART_ATTEMPTS=3                   # Auto-restart attempts
```

### CLI Overrides

```bash
# Override config file settings
./manage-proof-server.sh start \
  --port 8080 \
  --workers 4 \
  --verbose

# Use custom config file
./manage-proof-server.sh --config /path/to/custom.conf start
```

## Environment Variables

```bash
# Binary/Project
export BINARY_PATH=/path/to/binary
export BINARY_NAME=my-proof-server
export PROJECT_ROOT=/path/to/project

# Server settings (alternative to config file)
export MIDNIGHT_PROOF_SERVER_PORT=6300
export MIDNIGHT_PROOF_SERVER_VERBOSE=true
export MIDNIGHT_PROOF_SERVER_NUM_WORKERS=4

# Then run
./manage-proof-server.sh start
```

## Monitoring

### Watch Logs

```bash
# Real-time logs
./manage-proof-server.sh logs

# Or directly
tail -f /tmp/midnight-proof-server.log
```

### Auto-restart on Failure

```bash
# Monitor with auto-restart
./manage-proof-server.sh monitor

# Configure restart behavior
export MAX_RESTART_ATTEMPTS=5
export RESTART_DELAY=10
./manage-proof-server.sh monitor
```

### Metrics

```bash
# Show resource usage and stats
./manage-proof-server.sh metrics
```

## API Testing

```bash
# Test all endpoints
./manage-proof-server.sh test-api

# Manual health check
curl http://localhost:6300/health

# Check readiness
curl http://localhost:6300/ready

# Get version
curl http://localhost:6300/version
```

## Common Scenarios

### Development Workflow

```bash
# Build and start
./manage-proof-server.sh build
./manage-proof-server.sh start

# Make changes, rebuild, restart
./manage-proof-server.sh build
./manage-proof-server.sh restart

# Check logs
./manage-proof-server.sh logs
```

### Testing Different Branches

```bash
# Terminal 1: Run branch A binary
BINARY_PATH=/path/to/branch-a/target/release/midnight-proof-server \
  ./manage-proof-server.sh start --port 6300

# Terminal 2: Run branch B binary (different port)
BINARY_PATH=/path/to/branch-b/target/release/midnight-proof-server \
  ./manage-proof-server.sh start --port 6301
```

### Production Setup

```bash
# 1. Generate config
./manage-proof-server.sh generate-config

# 2. Edit proof-server.conf
vim proof-server.conf

# 3. Start with monitoring
nohup ./manage-proof-server.sh monitor > monitor.log 2>&1 &
```

### Custom Binary Name

```bash
# If binary was renamed
BINARY_NAME=my-custom-proof-server \
BINARY_PATH=/path/to/my-custom-proof-server \
  ./manage-proof-server.sh start
```

## Troubleshooting

### Binary Not Found

```bash
# Check configuration
./manage-proof-server.sh config

# Specify binary path explicitly
BINARY_PATH=/full/path/to/binary ./manage-proof-server.sh start
```

### Port Already in Use

```bash
# Use different port
./manage-proof-server.sh start --port 6301
```

### Server Won't Start

```bash
# Check logs
./manage-proof-server.sh logs

# Or directly
tail -100 /tmp/midnight-proof-server.log

# Check if process is running
ps aux | grep midnight-proof-server
```

### Clean Restart

```bash
# Force stop and clean
./manage-proof-server.sh stop
rm -f /tmp/midnight-proof-server.pid
./manage-proof-server.sh start
```

## Script Locations

The script can be run from multiple locations:

```bash
# From scripts directory (original)
scripts/manage-proof-server.sh start

# From project root (if copied/symlinked)
./manage-proof-server.sh start

# From anywhere (with PROJECT_ROOT)
PROJECT_ROOT=/path/to/project /path/to/manage-proof-server.sh start
```

## Help

```bash
# Show all options and commands
./manage-proof-server.sh help

# Show available build features
./manage-proof-server.sh features
```
