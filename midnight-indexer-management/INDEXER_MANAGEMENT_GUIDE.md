# Indexer Management Guide

Quick reference for managing the Midnight indexer in standalone mode.

_Note: The indexer implementation lives in the midnight-indexer repository. This guide focuses on building, starting, stopping, and monitoring the indexer built from that codebase._

## Prerequisites

### System Dependencies

Before building the indexer, ensure you have all required dependencies installed:

1. **Rust toolchain** - See the [Node Operator Guide](../midnight-dev-node-operator/NODE_OPERATOR_GUIDE.md#prerequisites) for complete Rust installation instructions
2. **Midnight node running** - Required for metadata generation and indexing
3. **subxt-cli** - Required for generating node metadata

### Install subxt-cli

```bash
# Install subxt-cli
cargo install subxt-cli

# Verify installation
subxt version
```

> **Note:** The subxt-cli version must match the version specified in the indexer's `Cargo.toml`. Check the file for the exact version if builds fail.

### Verify Node is Running

```bash
# Using the node operator script
cd ../midnight-dev-node-operator
./midnight-operator.sh status

# Or manually check node health
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"system_health","params":[],"id":1}' \
  http://127.0.0.1:9944
```

## Script Setup

The management script can be used in two ways:

### Option 1: Point to Pre-built Binaries (Recommended for Testing)

If you already have a built `indexer-standalone` binary, point the script to it:

```bash
# Set the binary path directly
MI_BINARY_PATH=/path/to/indexer-standalone ./manage-indexer.sh start

# Or set MI_PROJECT_ROOT if the binary is in target/release/
MI_PROJECT_ROOT=/path/to/midnight-indexer ./manage-indexer.sh start
```

### Option 2: Copy Script to Project Root (Recommended for Development)

For the best experience, copy or symlink the script into the `midnight-indexer` project root:

```bash
# Copy the script to your midnight-indexer project
cp manage-indexer.sh /path/to/midnight-indexer/

# Or create a symlink
ln -s $(pwd)/manage-indexer.sh /path/to/midnight-indexer/

# Navigate to project root and run
cd /path/to/midnight-indexer
./manage-indexer.sh generate-metadata  # Generates metadata and builds
./manage-indexer.sh start
```

When the script is in the project root (alongside `Cargo.toml`), it automatically:
- Detects `MI_PROJECT_ROOT`
- Builds binaries to the correct location
- Finds the binary without additional configuration

## Build Indexer Binary

### Using the Management Script (Recommended)

```bash
# Check node connection first
./manage-indexer.sh check-node

# Check node version compatibility
./manage-indexer.sh check-version

# Generate metadata from running node and build automatically
./manage-indexer.sh generate-metadata

# Or build only (if metadata already exists)
./manage-indexer.sh build
```

### Manual Build

```bash
# Navigate to the midnight-indexer repository
cd midnight-indexer

# Build in release mode with standalone feature
cargo build --release -p indexer-standalone --features standalone

# Verify the binary was created
ls -la target/release/indexer-standalone
```

**Build Output:** `target/release/indexer-standalone`

### Verify Build

```bash
# Check binary was created successfully
./target/release/indexer-standalone --help
```

> **Note:** If you encounter metadata mismatch errors during build or runtime, regenerate metadata using `./manage-indexer.sh generate-metadata`.

## Quick Start

### Build and Run

```bash
# Check prerequisites
./manage-indexer.sh check-node

# Generate metadata and build (automatic build after metadata generation)
./manage-indexer.sh generate-metadata

# Start indexer
./manage-indexer.sh start

# Check status
./manage-indexer.sh status

# Stop indexer
./manage-indexer.sh stop
```

### Using Pre-built Binary

```bash
# From different branch/build
BINARY_PATH=../other-branch/target/release/indexer-standalone ./manage-indexer.sh start

# From custom location
./manage-indexer.sh --binary-path /opt/midnight/indexer-standalone start
```

## Common Commands

```bash
# Node Management
check-node         # Check connection to Midnight node
check-version      # Check node version compatibility
generate-metadata  # Generate metadata from running node (auto-builds)

# Build
build              # Build the indexer binary

# Server Management
start              # Start the indexer
stop               # Stop the indexer
restart            # Restart the indexer
status             # Show indexer status
monitor            # Monitor with auto-restart
logs               # Watch indexer logs (tail -f)
metrics            # Show system metrics

# Database
reset-db           # Reset the database (delete and re-index)
db-info            # Show database information

# API
check-api          # Check GraphQL API status
test-api           # Test API with sample queries
```

## Configuration

### Command Line Options

```bash
# Binary Configuration
--binary-path PATH              # Direct path to indexer binary
--project-root PATH             # Project root directory (for building)

# Node Configuration
--node-url URL                  # Substrate node WebSocket URL
                                # (default: ws://127.0.0.1:9944)

# Database Configuration
--data-dir DIR                  # Data directory for database
                                # (default: target/data)
--db-file PATH                  # SQLite database file path

# API Configuration
--api-port PORT                 # GraphQL API port (default: 8088)

# Build Configuration
--profile PROFILE               # Set cargo build profile (default: release)
--features FEATURES             # Set cargo features (default: standalone)

# Other
--log-level LEVEL               # Set RUST_LOG level (default: info)
--verbose                       # Enable verbose logging
```

### CLI Examples

```bash
# Override default settings
./manage-indexer.sh start \
  --node-url ws://192.168.1.100:9944 \
  --api-port 8090 \
  --log-level debug

# Use custom data directory
./manage-indexer.sh --data-dir /var/lib/indexer start

# Build with specific profile
./manage-indexer.sh --profile dev build
```

## Environment Variables

```bash
# Binary/Project
export BINARY_PATH=/path/to/indexer-standalone
export BINARY_NAME=indexer-standalone
export MI_PROJECT_ROOT=/path/to/project

# Node Configuration
export APP__INFRA__NODE__URL=ws://127.0.0.1:9944

# Database Configuration
export DATA_DIR=target/data
export APP__INFRA__STORAGE__CNN_URL=target/data/indexer.sqlite

# API Configuration
export API_PORT=8088

# Security
export APP__INFRA__SECRET=303132333435363738393031323334353637383930313233343536373839303132

# Build Configuration
export CARGO_PROFILE=release
export FEATURES=standalone
export RUST_LOG=info

# Then run
./manage-indexer.sh start
```

## Node Version Management

### Check Compatibility

```bash
# Verify your node version matches expected version
./manage-indexer.sh check-version
```

### Update Metadata

When your node version changes:

```bash
# This will:
# 1. Download metadata from running node
# 2. Update NODE_VERSION file
# 3. Automatically rebuild the indexer
./manage-indexer.sh generate-metadata

# Then restart
./manage-indexer.sh restart
```

### Manual Metadata Update

```bash
# Update NODE_VERSION file manually
echo "0.20.0-your-version" > NODE_VERSION

# Generate metadata and rebuild
./manage-indexer.sh generate-metadata
```

## Monitoring

### Watch Logs

```bash
# Real-time logs
./manage-indexer.sh logs

# Or directly
tail -f /tmp/indexer-standalone.log

# Search for errors
grep -i error /tmp/indexer-standalone.log
```

### Auto-restart on Failure

```bash
# Monitor with auto-restart
./manage-indexer.sh monitor

# Configure restart behavior
export MI_MAX_RESTART_ATTEMPTS=5
export MI_RESTART_DELAY=10
export MI_HEALTH_CHECK_INTERVAL=60
./manage-indexer.sh monitor
```

### Metrics

```bash
# Show comprehensive metrics
./manage-indexer.sh metrics

# Shows:
# - System resource usage (CPU, memory)
# - Database statistics
# - API health status
# - Open file descriptors
# - Network connections
```

## GraphQL API

### Endpoint

The indexer exposes a GraphQL API at:
```
http://localhost:8088/api/v3/graphql
```

### API Testing

```bash
# Quick health check
./manage-indexer.sh check-api

# Run comprehensive tests
./manage-indexer.sh test-api

# Manual queries
curl -s -X POST http://localhost:8088/api/v3/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ block { height hash protocolVersion timestamp } }"}' | jq

# Get genesis block
curl -s -X POST http://localhost:8088/api/v3/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ block(offset: {height: 0}) { hash height transactions { hash } } }"}' | jq
```

### Available Queries

The GraphQL API supports:
- **Queries**: `block`, `transactions`, `contractAction`, `dustGenerationStatus`
- **Mutations**: `connect` (wallet), `disconnect` (wallet)
- **Subscriptions**: `blocks`, `contractActions`, `shieldedTransactions`, `unshieldedTransactions`

See `indexer-api/graphql/schema-v3.graphql` for the full schema.

## Database Management

### View Database Information

```bash
# Show database stats, size, and row counts
./manage-indexer.sh db-info
```

### Reset Database

```bash
# Stop indexer, reset database, and start fresh
./manage-indexer.sh stop
./manage-indexer.sh reset-db  # Deletes entire data directory (requires confirmation)
./manage-indexer.sh start

# The indexer will re-index all blocks from genesis
```

### Manual Database Inspection

```bash
# Using sqlite3
sqlite3 target/data/indexer.sqlite

# Example queries
sqlite3 target/data/indexer.sqlite "SELECT COUNT(*) FROM blocks;"
sqlite3 target/data/indexer.sqlite ".tables"
sqlite3 target/data/indexer.sqlite ".schema blocks"
```

## Common Scenarios

### Development Workflow

```bash
# Initial setup
./manage-indexer.sh check-node
./manage-indexer.sh generate-metadata

# Start indexer
./manage-indexer.sh start

# Make code changes, rebuild, restart
./manage-indexer.sh build
./manage-indexer.sh restart

# Check logs
./manage-indexer.sh logs
```

### After Node Update

```bash
# Check if metadata update is needed
./manage-indexer.sh check-version

# If version mismatch, regenerate metadata
./manage-indexer.sh generate-metadata

# Restart with new metadata
./manage-indexer.sh restart
```

### Testing Different Branches

```bash
# Terminal 1: Run branch A binary
BINARY_PATH=/path/to/branch-a/target/release/indexer-standalone \
  ./manage-indexer.sh start --api-port 8088

# Terminal 2: Run branch B binary (different port)
BINARY_PATH=/path/to/branch-b/target/release/indexer-standalone \
  ./manage-indexer.sh start --api-port 8089
```

### Production Setup

```bash
# 1. Check prerequisites
./manage-indexer.sh check-node
./manage-indexer.sh check-version

# 2. Generate metadata and build
./manage-indexer.sh generate-metadata

# 3. Start with monitoring
nohup ./manage-indexer.sh monitor > monitor.log 2>&1 &

# 4. Verify operation
./manage-indexer.sh status
./manage-indexer.sh check-api
```

### Custom Node Connection

```bash
# Connect to remote node
./manage-indexer.sh --node-url ws://remote-node:9944 start

# Or set environment variable
export APP__INFRA__NODE__URL=ws://remote-node:9944
./manage-indexer.sh start
```

## Troubleshooting

### Binary Not Found

```bash
# Check binary location
./manage-indexer.sh status

# Specify binary path explicitly
BINARY_PATH=/full/path/to/indexer-standalone ./manage-indexer.sh start

# Or build it
./manage-indexer.sh build
```

### Node Connection Issues

```bash
# Verify node is running
./manage-indexer.sh check-node

# Check node URL
echo $APP__INFRA__NODE__URL

# Test node directly
curl -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"system_health","params":[],"id":1}' \
  http://127.0.0.1:9944
```

### Metadata Errors

```bash
# Error: "Cannot decode from type"
# This means metadata doesn't match node version

# Solution: Regenerate metadata
./manage-indexer.sh generate-metadata
./manage-indexer.sh restart
```

### API Not Responding

```bash
# Check if indexer is running
./manage-indexer.sh status

# Check API health
./manage-indexer.sh check-api

# Verify port is listening
ss -tlnp | grep 8088

# Check logs for errors
./manage-indexer.sh logs | grep -i error
```

### Port Already in Use

```bash
# Use different port
./manage-indexer.sh start --api-port 8089

# Or stop the conflicting process
lsof -ti:8088 | xargs kill -9
```

### Indexer Won't Start

```bash
# Check recent logs
./manage-indexer.sh logs | tail -50

# Check if process exists
ps aux | grep indexer-standalone

# Force clean restart
./manage-indexer.sh stop
rm -f /tmp/indexer-standalone.pid
./manage-indexer.sh start
```

### Database Corruption

```bash
# Stop indexer
./manage-indexer.sh stop

# Check database (if it exists)
sqlite3 target/data/indexer.sqlite "PRAGMA integrity_check;"

# If corrupted, reset (deletes entire data directory)
./manage-indexer.sh reset-db
./manage-indexer.sh start
```

## File Locations

| What | Location |
|------|----------|
| Binary | `target/release/indexer-standalone` |
| Database | `target/data/indexer.sqlite` |
| Logs | `/tmp/indexer-standalone.log` |
| PID File | `/tmp/indexer-standalone.pid` |
| Metadata | `.node/<version>/metadata.scale` |
| NODE_VERSION | `NODE_VERSION` (root directory) |
| Config | `indexer-standalone/config.yaml` |

## Script Locations

The script can be run from multiple locations:

```bash
# From midnight-indexer-management directory
cd midnight-indexer-management
./manage-indexer.sh start

# From project root (with MI_PROJECT_ROOT)
MI_PROJECT_ROOT=/path/to/midnight-ledger \
  midnight-indexer-management/manage-indexer.sh start

# From anywhere (with explicit paths)
BINARY_PATH=/path/to/binary \
  /path/to/manage-indexer.sh start
```

## Architecture

The standalone indexer combines three components in a single binary:

- **Chain Indexer**: Connects to the node, fetches and processes blocks
- **Wallet Indexer**: Associates connected wallets with relevant transactions
- **Indexer API**: Exposes GraphQL API for queries and subscriptions

Data is stored in an embedded SQLite database, making it ideal for local development.

## Performance Metrics

Typical operational metrics:

| Metric | Expected Value |
|--------|----------------|
| CPU Usage | < 1% (idle), 5-10% (syncing) |
| Memory Usage | ~50-100 MB |
| API Response Time | < 100ms |
| Database Growth | ~10-20 KB per block |
| Sync Speed | Depends on node |

Monitor these with:
```bash
./manage-indexer.sh metrics
```

## Production Considerations

For production deployment, consider:

1. **Systemd Service**: Convert to systemd service for auto-start on boot
2. **Log Rotation**: Implement log rotation for `/tmp/indexer-standalone.log`
3. **Monitoring**: Integrate with monitoring systems (Prometheus, Grafana)
4. **Backup**: Regular database backups
5. **Security**: Review and harden security settings in config files
6. **Disk Space**: Monitor database growth and plan for storage
7. **Node Availability**: Ensure reliable connection to Midnight node

## Help

```bash
# Show all options and commands
./manage-indexer.sh help

# Show version information
./manage-indexer.sh check-version
```

## Related Resources

- **Local Indexer Setup Guide**: `../guides/2-local-indexer-setup_md.md`
- **Quick Reference**: `QUICK_REFERENCE.md`
- **Setup Summary**: `INDEXER_SETUP_SUMMARY.md`
- **GraphQL Schema**: `indexer-api/graphql/schema-v3.graphql` (in midnight-indexer)
- **Node Operator Guide**: `../midnight-dev-node-operator/NODE_OPERATOR_GUIDE.md`
- **Proof Server Guide**: `../proof-server-management/PROOF_SERVER_GUIDE.md`
