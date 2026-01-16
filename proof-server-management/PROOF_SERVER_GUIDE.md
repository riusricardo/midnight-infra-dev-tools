# Proof Server Management Guide

Quick reference for managing the Midnight proof server.

_Note: The proof server implementation lives in the midnight-ledger repository (as the `midnight-proof-server` package). This guide focuses on building, starting, stopping, and monitoring the proof server built from that codebase._

## Prerequisites

### System Dependencies

Before building the proof server, ensure you have all required dependencies installed:

1. **Rust toolchain** - See the [Node Operator Guide](../midnight-dev-node-operator/NODE_OPERATOR_GUIDE.md#prerequisites) for complete Rust installation instructions
2. **Build tools** - `build-essential`, `clang`, `curl`, `git`, `make`
3. **Cryptography libraries** - `libssl-dev` (for public/private key generation and transaction signatures)

<details>
<summary><strong>Linux (Ubuntu/Debian)</strong></summary>

```bash
# Update package lists
sudo apt update

# Install build-essential (minimum requirement)
sudo apt install --assume-yes build-essential

# Install required packages
sudo apt install --assume-yes clang curl git make libssl-dev

# Verify Rust is installed
rustc --version
cargo --version
```

</details>

<details>
<summary><strong>macOS</strong></summary>

```bash
# Install required packages
brew install openssl cmake

# Verify Rust is installed
rustc --version
cargo --version
```

</details>

> **Reference:** For complete dependency information, see the [Polkadot SDK Installation Guide](https://docs.polkadot.com/parachains/install-polkadot-sdk/).

## Script Setup

The management script can be used in two ways:

### Option 1: Point to Pre-built Binaries (Recommended for Testing)

If you already have a built `midnight-proof-server` binary, point the script to it:

```bash
# Set the binary path directly
MPS_BINARY_PATH=/path/to/midnight-proof-server ./manage-proof-server.sh start

# Or set PROJECT_ROOT if the binary is in target/release/
PROJECT_ROOT=/path/to/midnight-ledger ./manage-proof-server.sh start
```

### Option 2: Copy Script to Project Root (Recommended for Development)

For the best experience, copy or symlink the script into the `midnight-ledger` project root:

```bash
# Copy the script to your midnight-ledger project
cp manage-proof-server.sh /path/to/midnight-ledger/

# Or create a symlink
ln -s $(pwd)/manage-proof-server.sh /path/to/midnight-ledger/

# Navigate to project root and run
cd /path/to/midnight-ledger
./manage-proof-server.sh build      # Build the binary
./manage-proof-server.sh start
```

When the script is in the project root (alongside `Cargo.toml`), it automatically:
- Detects `PROJECT_ROOT`
- Builds the `midnight-proof-server` package from the workspace
- Finds the binary without additional configuration

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

## Build Proof Server Binary

### Using the Management Script (Recommended)

```bash
# Standard build (release mode)
./manage-proof-server.sh build

# Build with debug profile (faster compile, slower runtime)
MPS_CARGO_PROFILE=dev ./manage-proof-server.sh build
```

### Manual Build

```bash
# Navigate to the midnight-ledger repository
cd midnight-ledger

# Build in release mode
cargo build --release --package midnight-proof-server

# Verify the binary was created
ls -la target/release/midnight-proof-server
```

**Build Output:** `target/release/midnight-proof-server`

### Verify Build

```bash
# Check binary was created successfully
./target/release/midnight-proof-server --help

# Check version
./target/release/midnight-proof-server --version
```

> **Note:** The first build will take significant time as it compiles cryptographic libraries.

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
