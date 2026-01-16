# Midnight Node Operator Guide

Quick reference for managing Midnight blockchain nodes in development and testing environments.

_Note: The midnight-node implementation lives in the midnight-node repository. This guide focuses on running single nodes, local multi-node networks, and distributed deployments._

> **⚠️ IMPORTANT:** Multi-Node Network functionality is currently blocked pending an upstream PR merge. Only **single node development setup** works at this time. For more information, see [Issue #1](https://github.com/riusricardo/midnight-infra-dev-tools/issues/1).

## Prerequisites

Before building and running the Midnight node, you need to install the required dependencies.

### System Requirements

- **Processor:** 2 GHz minimum (3 GHz recommended)
- **Memory:** 8 GB RAM minimum (16 GB recommended)
- **Storage:** 10 GB available space minimum
- **Network:** Broadband Internet connection

### Install Dependencies

<details>
<summary><strong>Linux (Ubuntu/Debian)</strong></summary>

```bash
# Update package lists
sudo apt update

# Install build-essential (minimum requirement)
sudo apt install --assume-yes build-essential

# Install required packages for cryptography and compilation
sudo apt install --assume-yes clang curl git make libssl-dev protobuf-compiler

# Download and install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Follow the prompts for default installation, then update your shell
source $HOME/.cargo/env

# Verify installation
rustc --version

# Configure Rust toolchain
rustup default stable
rustup update
rustup target add wasm32-unknown-unknown
rustup component add rust-src
```

</details>

<details>
<summary><strong>macOS</strong></summary>

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

# Verify Homebrew
brew --version

# Update Homebrew
brew update

# Install required packages
brew install openssl protobuf cmake

# Download and install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Follow the prompts for default installation, then update your shell
source ~/.cargo/env

# Configure Rust toolchain
rustup default stable
rustup update
rustup target add wasm32-unknown-unknown
rustup component add rust-src
```

</details>

<details>
<summary><strong>Windows (WSL)</strong></summary>

```powershell
# In PowerShell (Run as Administrator)
wsl --install
```

After restart, open Ubuntu from Start menu and run:

```bash
# Update packages
sudo apt update

# Install required packages
sudo apt install --assume-yes build-essential clang curl git make libssl-dev llvm libudev-dev protobuf-compiler

# Download and install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Follow the prompts for default installation, then update your shell
source ~/.cargo/env

# Verify installation
rustc --version

# Configure Rust toolchain
rustup default stable
rustup update
rustup target add wasm32-unknown-unknown
rustup component add rust-src
```

</details>

> **Reference:** For detailed installation instructions, see the [Polkadot SDK Installation Guide](https://docs.polkadot.com/parachains/install-polkadot-sdk/).

## Script Setup

The management script can be used in two ways:

### Option 1: Point to Pre-built Binaries (Recommended for Testing)

If you already have a built `midnight-node` binary, point the script to it:

```bash
# Set the binary path directly
MO_BINARY_PATH=/path/to/midnight-node ./midnight-operator.sh start --node alice

# Or set MO_PROJECT_ROOT if the binary is in target/release/
MO_PROJECT_ROOT=/path/to/midnight-node ./midnight-operator.sh start --node alice
```

### Option 2: Copy Script to Project Root (Recommended for Development)

For the best experience, copy or symlink the script into the `midnight-node` project root:

```bash
# Copy the script to your midnight-node project
cp midnight-operator.sh /path/to/midnight-node/

# Or create a symlink
ln -s $(pwd)/midnight-operator.sh /path/to/midnight-node/

# Navigate to project root and run
cd /path/to/midnight-node
./midnight-operator.sh build      # Build the binary
./midnight-operator.sh start --node alice
```

When the script is in the project root (alongside `Cargo.toml`), it automatically:
- Detects `MO_PROJECT_ROOT`
- Builds binaries to the correct location
- Finds the binary without additional configuration

## Build Binaries

### Using the Management Script (Recommended)

```bash
# Build the midnight-node binary
./midnight-operator.sh build

# Build with specific features (optional)
./midnight-operator.sh build --features "some-feature"

# Build with debug profile (faster compile, slower runtime)
./midnight-operator.sh build --profile dev
```

### Manual Build

```bash
# Navigate to the midnight-node repository
cd midnight-node

# Build in release mode (optimized)
cargo build --release

# Verify the binary was created
ls -la target/release/midnight-node
```

**Build Output:** The following binaries will be available in `target/release/`:
- `midnight-node` - The blockchain node binary
- `midnight-node-toolkit` - CLI tools for wallet operations

### Verify Build

```bash
# Check binary version
./target/release/midnight-node --version
```

> **Note:** The first build will take significant time as it compiles all dependencies. Subsequent builds are faster due to caching.

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

> **⚠️ NOT AVAILABLE YET:** This feature is blocked by an upstream PR. See [Issue #1](https://github.com/riusricardo/midnight-infra-dev-tools/issues/1).

```bash
# Start 4-node network (Alice, Bob, Charlie, Dave) - BLOCKED
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
MO_BINARY_PATH=/path/to/midnight-node
MO_PROJECT_ROOT=/path/to/midnight-node-repo

# Directories
MO_BASE_DIR=/tmp/midnight-nodes
MO_LOG_DIR=/tmp/midnight-logs
MO_PID_DIR=/tmp/midnight-pids

# Build Configuration
MO_CARGO_PROFILE=release
MO_VERBOSE=true
EOF

# Script will auto-load this config
./midnight-operator.sh start --node alice
```

### Environment Variables

```bash
# Binary location
export MO_BINARY_PATH=/path/to/midnight-node
export MO_PROJECT_ROOT=/path/to/project

# Or use default binary path
export MO_BINARY=./target/release/midnight-node

# Custom directories
export MO_BASE_DIR=/custom/data/dir
export MO_m directories
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

> **⚠️ BLOCKED:** This feature requires an upstream PR to be merged. Currently not functional. See [Issue #1](https://github.com/riusricardo/midnight-infra-dev-tools/issues/1).

Test consensus, networking, and multi-validator scenarios on one machine.

```bash
# Start 4 validators - NOT WORKING YET
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

> **⚠️ BLOCKED:** This feature requires an upstream PR to be merged. Currently not functional. See [Issue #1](https://github.com/riusricardo/midnight-infra-dev-tools/issues/1).

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
echo $MO_PROJECT_ROOT

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
