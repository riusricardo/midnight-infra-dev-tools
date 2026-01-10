# Midnight Infrastructure Dev Tools

Production-ready management scripts for Midnight blockchain development infrastructure.

## Quick Start

```bash
# Start a development node
cd midnight-dev-node-operator
./midnight-operator.sh start --node alice

# Start the proof server
cd proof-server-management
./manage-proof-server.sh build
./manage-proof-server.sh start

# Start the indexer
cd midnight-indexer-management
./manage-indexer.sh check-node
./manage-indexer.sh generate-metadata
./manage-indexer.sh start
```

## Components

### Node Operator
Manages single and multi-node Midnight networks.

**Location**: `midnight-dev-node-operator/`  
**Script**: `midnight-operator.sh`  
**Guide**: [NODE_OPERATOR_GUIDE.md](midnight-dev-node-operator/NODE_OPERATOR_GUIDE.md)

**Commands**:
- `start` - Start single node or multi-node network
- `stop` - Stop nodes
- `status` - Check node status
- `logs` - View node logs
- `clean` - Clean node data

### Proof Server
Manages the Midnight proof server for zero-knowledge proof generation.

**Location**: `proof-server-management/`  
**Script**: `manage-proof-server.sh`  
**Guide**: [PROOF_SERVER_GUIDE.md](proof-server-management/PROOF_SERVER_GUIDE.md)

**Commands**:
- `build` - Build the proof server
- `start` - Start the server
- `stop` - Stop the server
- `status` - Check server status and health
- `monitor` - Monitor with auto-restart
- `test-api` - Test server endpoints

### Indexer
Manages the standalone indexer for blockchain data and GraphQL API.

**Location**: `midnight-indexer-management/`  
**Script**: `manage-indexer.sh`  
**Guide**: [INDEXER_MANAGEMENT_GUIDE.md](midnight-indexer-management/INDEXER_MANAGEMENT_GUIDE.md)

**Commands**:
- `check-node` - Verify node connection
- `generate-metadata` - Generate and build metadata
- `start` - Start the indexer
- `status` - Check indexer status
- `check-api` - Test GraphQL API
- `reset-db` - Reset database

## Guides

- [Node Operator Guide](midnight-dev-node-operator/NODE_OPERATOR_GUIDE.md) - Single and multi-node setup
- [Proof Server Guide](proof-server-management/PROOF_SERVER_GUIDE.md) - Proof server management
- [Indexer Management Guide](midnight-indexer-management/INDEXER_MANAGEMENT_GUIDE.md) - Indexer operations
- [Wallet Funding Guide](guides/1-wallet-funding-guide_md.md) - Fund wallets and register DUST
- [Local Indexer Setup](guides/2-local-indexer-setup_md.md) - Quick indexer setup

## Requirements

- Rust toolchain (latest stable)
- Midnight node binary (for indexer)
- subxt-cli (for indexer metadata)
- System dependencies: gcc, pkg-config, libssl-dev, protobuf-compiler, clang, cmake

## Common Workflows

### Development Environment
```bash
# 1. Start a node
cd midnight-dev-node-operator
./midnight-operator.sh start --node alice

# 2. Start proof server
cd ../proof-server-management
./manage-proof-server.sh build
./manage-proof-server.sh start

# 3. Start indexer
cd ../midnight-indexer-management
./manage-indexer.sh generate-metadata
./manage-indexer.sh start
```

### Multi-Node Network
```bash
cd midnight-dev-node-operator
./midnight-operator.sh start --network
./midnight-operator.sh status
```

### Production Monitoring
```bash
# Monitor components with auto-restart
./manage-proof-server.sh monitor &
./manage-indexer.sh monitor &
```

## Repository Structure

```
midnight-infra-dev-tools/
├── midnight-dev-node-operator/    # Node management
│   ├── midnight-operator.sh
│   └── NODE_OPERATOR_GUIDE.md
├── proof-server-management/       # Proof server
│   ├── manage-proof-server.sh
│   └── PROOF_SERVER_GUIDE.md
├── midnight-indexer-management/   # Indexer
│   ├── manage-indexer.sh
│   └── INDEXER_MANAGEMENT_GUIDE.md
└── guides/                        # Additional guides
    ├── 1-wallet-funding-guide_md.md
    └── 2-local-indexer-setup_md.md
```

## Troubleshooting

All scripts include comprehensive help:
```bash
./midnight-operator.sh help
./manage-proof-server.sh help
./manage-indexer.sh help
```

For detailed troubleshooting, see individual component guides.

## Disclaimer

This code is provided "as is", without warranty of any kind. No responsibility regarding its use or performance lies with the main developers. Use at your own risk.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
