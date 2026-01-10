# Midnight Node Operator Guide

Quick reference for managing Midnight blockchain nodes in development and testing environments.

_Note: The midnight-node implementation lives in the midnight-node repository. This guide focuses on running single nodes, local multi-node networks, and distributed deployments._

## Quick Start

### Single Node Development

```bash
# Start Alice in dev mode (fastest for development)
./midnight-operator.sh start --node alice

# Check status
./midnight-operator.sh status

# View logs
./midnight-operator.sh logs alice

# Stop
./midnight-operator.sh stop
```

### Local Multi-Node Network

```bash
# Start 4-node network (Alice, Bob, Charlie, Dave)
./midnight-operator.sh start --network --nodes 4

# Check all nodes
./midnight-operator.sh status

# Stop all
./midnight-operator.sh stop
```

## Common Commands

```bash
start              # Start node(s)
stop               # Stop node(s)
status             # Check node health
logs               # View node logs
clean              # Clean data directories
chainspec          # Generate chainspec for distributed deployment
join               # Join existing network
help               # Show help
```

## Configuration

### Using Config File

```bash
# Create node-operator.conf in the script directory
cat > node-operator.conf << EOF
# Binary Configuration
BINARY_PATH=/path/to/midnight-node
PROJECT_ROOT=/path/to/midnight-node-repo

# Directories
BASE_DIR=/tmp/midnight-nodes
LOG_DIR=/tmp/midnight-logs
PID_DIR=/tmp/midnight-pids

# Build Configuration
CARGO_PROFILE=release
VERBOSE=true
EOF

# Script will auto-load this config
./midnight-operator.sh start --node alice
```

### Environment Variables

```bash
# Binary location
export BINARY_PATH=/path/to/midnight-node
export PROJECT_ROOT=/path/to/project

# Or use default binary path
export BINARY=./target/release/midnight-node

# Custom directories
export BASE_DIR=/custom/data/dir
export LOG_DIR=/custom/logs

# Then run
./midnight-operator.sh start --node alice
```

## Usage Scenarios

### Single Node Development

Perfect for quick iteration during development.

```bash
# Start Alice (only validator)
./midnight-operator.sh start --node alice

# Your node is at:
# - RPC: ws://localhost:9944
# - P2P: localhost:30333

# Check it's running
./midnight-operator.sh status

# Watch logs
./midnight-operator.sh logs alice

# Clean restart
./midnight-operator.sh stop
./midnight-operator.sh clean
./midnight-operator.sh start --node alice
```

**Use case:** Testing smart contracts, debugging, rapid development cycles

### Local Multi-Node Network

Test consensus, networking, and multi-validator scenarios on one machine.

```bash
# Start 4 validators
./midnight-operator.sh start --network --nodes 4

# All nodes are validators:
# - Alice:   ws://localhost:9944
# - Bob:     ws://localhost:9945
# - Charlie: ws://localhost:9946
# - Dave:    ws://localhost:9947

# Check consensus
./midnight-operator.sh status

# Watch specific node
./midnight-operator.sh logs bob

# Stop specific node
./midnight-operator.sh stop --node bob

# Stop all
./midnight-operator.sh stop
```

**Use case:** Testing consensus, block production, network issues, multi-node interactions

### Distributed Multi-Node Network

Run validators across multiple physical machines or VMs.

#### Step 1: Generate Chainspec (on any machine)

```bash
# Generate for 4 validators
./midnight-operator.sh chainspec --nodes 4 --output chainspec.json

# Copy chainspec.json to ALL machines
scp chainspec.json user@machine-b:~/
scp chainspec.json user@machine-c:~/
```

#### Step 2: Start Bootnode (Machine A)

```bash
# Start Alice as bootnode
./midnight-operator.sh start --network --node alice

# Note the peer ID from output:
# Bootnode peer ID: 12D3KooWEyoppNCUx8Yx66oV9fJnriXwCcXwDDUA2kj6vnc6iDEp
```

#### Step 3: Join from Other Machines

```bash
# On Machine B (join as Bob)
./midnight-operator.sh join \
  --chain chainspec.json \
  --bootnode /ip4/192.168.1.100/tcp/30333/p2p/12D3KooWEyoppNCUx8Yx66oV9fJnriXwCcXwDDUA2kj6vnc6iDEp \
  --node bob

# On Machine C (join as Charlie)
./midnight-operator.sh join \
  --chain chainspec.json \
  --bootnode /ip4/192.168.1.100/tcp/30333/p2p/12D3KooWEyoppNCUx8Yx66oV9fJnriXwCcXwDDUA2kj6vnc6iDEp \
  --node charlie
```

**Use case:** Testing distributed networks, network partitions, geographic distribution, realistic production scenarios

## Node Options

### Available Validators

The script supports 6 well-known Substrate test accounts:

| Node | RPC Port | P2P Port | Use Case |
|------|----------|----------|----------|
| Alice | 9944 | 30333 | Primary/Bootnode |
| Bob | 9945 | 30334 | Secondary |
| Charlie | 9946 | 30335 | Third validator |
| Dave | 9947 | 30336 | Fourth validator |
| Eve | 9948 | 30337 | Fifth validator |
| Ferdie | 9949 | 30338 | Sixth validator |

### Custom Data Directory

```bash
# Single node with custom path
./midnight-operator.sh start --node alice --base-path /custom/path

# Network will use BASE_DIR/<node-name> for each node
```

## Network Isolation

### Protocol ID

Each generated chainspec gets a unique protocol ID for network isolation:

```bash
# Auto-generated (timestamp-based)
./midnight-operator.sh chainspec --nodes 4 --output team-a.json
# Protocol ID: midnight-local-1704801234

# Custom protocol ID
PROTOCOL_ID="my-test-network" ./midnight-operator.sh chainspec --nodes 4 --output team-b.json
# Protocol ID: my-test-network
```

**Important:** Nodes with different protocol IDs will NOT connect to each other, even if they discover each other's addresses. This prevents test networks from interfering with each other.

## Status and Monitoring

### Check Node Health

```bash
# Check all running nodes
./midnight-operator.sh status

# Example output:
# [✓] Alice (PID: 12345, RPC: ws://localhost:9944)
#     Peers: 3 | Syncing: false | Block: 42
# [✓] Bob (PID: 12346, RPC: ws://localhost:9945)
#     Peers: 3 | Syncing: false | Block: 42
```

### View Logs

```bash
# Follow logs in real-time
./midnight-operator.sh logs alice

# Or directly
tail -f /tmp/midnight-logs/Alice.log
```

### Manual RPC Checks

```bash
# Health check
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"system_health","params":[],"id":1}' \
  http://localhost:9944

# Get current block
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"chain_getHeader","params":[],"id":1}' \
  http://localhost:9944

# Get peer count
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"system_peers","params":[],"id":1}' \
  http://localhost:9944
```

## Data Management

### Clean Node Data

```bash
# Clean all nodes
./midnight-operator.sh clean

# Clean specific node
./midnight-operator.sh clean --node alice
```

**Note:** This removes:
- Node databases (`/tmp/midnight-nodes/`)
- Log files (`/tmp/midnight-logs/`)
- Key files (`/tmp/midnight-seeds/`)
- PID files (`/tmp/midnight-pids/`)
- Chainspec files (`/tmp/midnight-chainspecs/`)

### Fresh Start

```bash
# Complete reset
./midnight-operator.sh stop
./midnight-operator.sh clean
./midnight-operator.sh start --network --nodes 4
```

## Troubleshooting

### Node Won't Start

```bash
# Check logs
./midnight-operator.sh logs alice

# Or view last errors
tail -50 /tmp/midnight-logs/Alice.log

# Check if port is in use
netstat -an | grep 9944  # Linux
lsof -i :9944            # macOS
```

### Binary Not Found

```bash
# Check current configuration
echo $BINARY_PATH
echo $PROJECT_ROOT

# Specify binary explicitly
BINARY_PATH=/path/to/midnight-node ./midnight-operator.sh start --node alice

# Or build it first
cd /path/to/midnight-node
cargo build --release
./scripts/midnight-operator.sh start --node alice
```

### Nodes Not Syncing

```bash
# 1. Ensure all nodes use the same chainspec
./midnight-operator.sh stop
./midnight-operator.sh clean
./midnight-operator.sh start --network --nodes 4

# 2. Check if they're connected
./midnight-operator.sh status
# Look for peer count > 0

# 3. Verify protocol IDs match (for distributed networks)
jq -r '.protocolId' chainspec.json  # Should be same on all machines
```

### Port Already in Use

```bash
# Find process using the port
lsof -i :9944

# Kill it
kill <PID>

# Or use a different port (only works for single node)
# Multi-node uses fixed port assignments
```

### Cannot Connect to RPC

```bash
# 1. Check node is running
./midnight-operator.sh status

# 2. Verify RPC is responding
curl http://localhost:9944

# 3. Check firewall (for distributed setups)
# Ensure ports 30333 (P2P) and 9944 (RPC) are accessible
```

### Distributed Nodes Can't Find Each Other

```bash
# 1. Verify network connectivity
ping <bootnode-ip>
nc -zv <bootnode-ip> 30333

# 2. Check bootnode address format
# Correct: /ip4/192.168.1.100/tcp/30333/p2p/12D3KooW...
# Must include the full peer ID

# 3. Ensure chainspec is identical on all machines
md5sum chainspec.json  # Run on each machine

# 4. Check firewall allows P2P port (30333)
```

### Orphaned Processes

```bash
# Clean up orphaned nodes
pkill -f midnight-node

# Or
./midnight-operator.sh stop --all

# Verify nothing running
ps aux | grep midnight-node
```

## Advanced Usage

### Using Non-Standard Binary

```bash
# From different build
BINARY_PATH=/path/to/other-branch/target/release/midnight-node \
  ./midnight-operator.sh start --node alice

# Custom binary name
BINARY_NAME=my-midnight-node \
BINARY_PATH=/opt/midnight/my-midnight-node \
  ./midnight-operator.sh start --node alice
```

### Multiple Independent Networks

```bash
# Network 1 (Team A)
PROTOCOL_ID="team-a-testnet" \
BASE_DIR=/tmp/team-a-nodes \
LOG_DIR=/tmp/team-a-logs \
  ./midnight-operator.sh chainspec --nodes 4 --output team-a.json

# Network 2 (Team B)
PROTOCOL_ID="team-b-testnet" \
BASE_DIR=/tmp/team-b-nodes \
LOG_DIR=/tmp/team-b-logs \
  ./midnight-operator.sh chainspec --nodes 4 --output team-b.json

# These networks are completely isolated
```

### Custom Chainspec Modifications

```bash
# Generate base chainspec
./midnight-operator.sh chainspec --nodes 4 --output base.json

# Modify with jq (example: change block time)
jq '.genesis.runtime.timestamp.minimumPeriod = 3000' base.json > modified.json

# Use modified chainspec
./midnight-operator.sh start --network --node alice
# (Uses chainspec from /tmp/midnight-chainspecs/)
```

## Prerequisites

### Required Tools

```bash
# jq - JSON processor (for multi-node chainspecs)
# Linux
sudo apt-get install jq

# macOS
brew install jq

# curl - HTTP client (usually pre-installed)
# bash - Shell (pre-installed)
```

### Building the Binary

Midnight-node is built using Rust and Cargo:

```bash
# Clone the repository
git clone https://github.com/midnightntwrk/midnight-node.git
cd midnight-node

# Build in release mode (optimized, recommended)
cargo build --release

# Binary will be at: target/release/midnight-node
```

**Development builds** (faster compilation, slower runtime):
```bash
# Build in debug mode (faster to compile, for development)
cargo build

# Binary will be at: target/debug/midnight-node
```

**Clean rebuild** (if you encounter issues):
```bash
# Clean previous builds
cargo clean

# Rebuild
cargo build --release
```

**After building**, the script will automatically find the binary if run from the repository root:
```bash
# From midnight-node repository root
./scripts/midnight-operator.sh start --node alice
```

### Runtime Dependencies

The midnight-node requires the `res/` directory from the repository:

```bash
# Always run from the repository root, or ensure the `res` directory is located at the same level as the midnight-node binary.
cd /path/to/midnight-node
./scripts/midnight-operator.sh start --node alice

# The res/ directory contains:
# - res/cfg/        - Network configuration presets
# - res/dev/        - Development network resources
# - res/genesis/    - Genesis state and blocks
```

## Examples

### Quick Dev Test

```bash
# Start, test, stop
./midnight-operator.sh start --node alice
# ... do your testing ...
./midnight-operator.sh stop
./midnight-operator.sh clean
```

### Local 6-Node Network

```bash
# Maximum validators
./midnight-operator.sh start --network --nodes 6
./midnight-operator.sh status

# RPC endpoints available:
# Alice:   :9944
# Bob:     :9945
# Charlie: :9946
# Dave:    :9947
# Eve:     :9948
# Ferdie:  :9949
```

### Three-Machine Distributed Network

```bash
# === Machine A (Bootnode) ===
./midnight-operator.sh chainspec --nodes 3 --output chain.json
scp chain.json user@machine-b:~/
scp chain.json user@machine-c:~/
./midnight-operator.sh start --network --node alice
# Note peer ID: 12D3KooW...

# === Machine B ===
./midnight-operator.sh join \
  --chain chain.json \
  --bootnode /ip4/192.168.1.10/tcp/30333/p2p/12D3KooW... \
  --node bob

# === Machine C ===
./midnight-operator.sh join \
  --chain chain.json \
  --bootnode /ip4/192.168.1.10/tcp/30333/p2p/12D3KooW... \
  --node charlie
```

## Files and Directories

| Location | Purpose |
|----------|---------|
| `/tmp/midnight-nodes/` | Node database files |
| `/tmp/midnight-logs/` | Log files |
| `/tmp/midnight-seeds/` | Key seed files (secure) |
| `/tmp/midnight-pids/` | Process ID files |
| `/tmp/midnight-chainspecs/` | Generated chainspecs |

### Changing Default Locations

```bash
# Via environment
export BASE_DIR=/data/midnight/nodes
export LOG_DIR=/var/log/midnight
export PID_DIR=/var/run/midnight

./midnight-operator.sh start --node alice

# Via config file
cat > node-operator.conf << EOF
BASE_DIR=/data/midnight/nodes
LOG_DIR=/var/log/midnight
PID_DIR=/var/run/midnight
EOF

./midnight-operator.sh start --node alice
```

## Help

```bash
# Show all commands and options
./midnight-operator.sh help

# View this guide
cat NODE_OPERATOR_GUIDE.md

# Or in the repository
cat midnight-dev-node-operator/README.md
```

## License

This tool is licensed under the GNU General Public License v3.0. See the script header or LICENSE file for details.

**Disclaimer:** This code is provided "as is" without warranty. No responsibility lies with the main developers regarding its use or performance.
