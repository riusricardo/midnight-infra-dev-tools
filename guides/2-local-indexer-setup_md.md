# Running the Midnight Indexer Locally

This guide explains how to run the Midnight Indexer in standalone mode, connecting to a local Midnight node.

> **Management Script:** This guide uses [manage-indexer.sh](../midnight-indexer-management/manage-indexer.sh) for all operations. For advanced usage and additional commands, see the [Indexer Management Guide](../midnight-indexer-management/INDEXER_MANAGEMENT_GUIDE.md).

## Prerequisites

- **Midnight node running** - See [Node Operator Guide](../midnight-dev-node-operator/NODE_OPERATOR_GUIDE.md)
- **Rust toolchain installed** - Required for building the indexer
- **System dependencies** - Build tools (gcc, pkg-config, libssl-dev, protobuf-compiler, clang, cmake)
- **subxt-cli** - Must match version in Cargo.toml (currently 0.44.0)
  ```bash
  cargo install subxt-cli
  ```

### Quick Start: Running a Dev Node

```bash
# Using midnight-operator.sh (recommended)
cd midnight-dev-node-operator
./midnight-operator.sh start --node alice

# Verify node is running
./midnight-operator.sh status
```

## Quick Start

Once your node is running, start the indexer:

```bash
# Check node connection
./manage-indexer.sh check-node

# Build the indexer (first time only)
./manage-indexer.sh build

# Start the indexer
./manage-indexer.sh start

# Check status
./manage-indexer.sh status
```

The indexer will start indexing from genesis and expose the GraphQL API at `http://localhost:8088`.

## Node Version Compatibility

The indexer must have metadata that matches your node's runtime. If you're running a different node version than what's in `NODE_VERSION`, you need to regenerate the metadata.

### Check Node Version Compatibility

```bash
# Check if your node version matches
./manage-indexer.sh check-version
```

### Generate Metadata from Your Running Node

If your node version differs from `NODE_VERSION`, regenerate the metadata:

```bash
# Generate metadata, update NODE_VERSION, and rebuild automatically
./manage-indexer.sh generate-metadata
```

The script will automatically:
1. Download metadata from your running node
2. Update the NODE_VERSION file
3. Rebuild the indexer with the new metadata

<details>
<summary>Manual metadata generation (alternative method)</summary>

```bash
# Get your node version
NODE_VERSION=$(curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"system_version","params":[],"id":1}' \
  http://127.0.0.1:9944 | jq -r '.result')

# Create directory and download metadata
mkdir -p .node/$NODE_VERSION
subxt metadata --url ws://127.0.0.1:9944 -o .node/$NODE_VERSION/metadata.scale

# Update NODE_VERSION file
echo "$NODE_VERSION" > NODE_VERSION

# Rebuild the indexer
cargo build -p indexer-standalone --features standalone
```
</details>

## Running the Indexer

### Using the Management Script (Recommended)

```bash
# Start with default configuration
./manage-indexer.sh start

# Start with custom node URL
./manage-indexer.sh --node-url ws://192.168.1.100:9944 start

# Start with custom API port
./manage-indexer.sh --api-port 8090 start

# Check status
./manage-indexer.sh status

# View logs
./manage-indexer.sh logs

# Stop the indexer
./manage-indexer.sh stop
```

The script handles all configuration automatically and provides:
- Automatic PID management
- Graceful shutdown handling
- Health monitoring
- Log file management at `/tmp/indexer-standalone.log`

### Configuration Options

The management script supports various configuration options:

| Option | Environment Variable | Default | Description |
|--------|---------------------|---------|-------------|
| `--node-url` | `APP__INFRA__NODE__URL` | `ws://127.0.0.1:9944` | Node WebSocket URL |
| `--data-dir` | `DATA_DIR` | `target/data` | Data directory |
| `--db-file` | `APP__INFRA__STORAGE__CNN_URL` | `$DATA_DIR/indexer.sqlite` | Database file |
| `--api-port` | `API_PORT` | `8088` | GraphQL API port |
| `--log-level` | `RUST_LOG` | `info` | Logging level |

<details>
<summary>Manual execution (without script)</summary>

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `APP__INFRA__SECRET` | 32-byte hex secret for encryption (64 hex chars) | `303132...` |
| `APP__INFRA__NODE__URL` | Substrate node WebSocket URL | `ws://127.0.0.1:9944` |
| `APP__INFRA__STORAGE__CNN_URL` | SQLite database path | `target/data/indexer.sqlite` |

### Start the Indexer

```bash
# Create data directory
mkdir -p target/data

# Run the standalone indexer
RUST_LOG=info \
APP__INFRA__NODE__URL="ws://127.0.0.1:9944" \
APP__INFRA__STORAGE__CNN_URL=target/data/indexer.sqlite \
APP__INFRA__SECRET=303132333435363738393031323334353637383930313233343536373839303132 \
CONFIG_FILE=indexer-standalone/config.yaml \
cargo run -p indexer-standalone --features standalone
```
</details>

The indexer will:
1. Connect to your node at `ws://127.0.0.1:9944`
2. Create/migrate the SQLite database
3. Start indexing blocks from genesis
4. Expose the GraphQL API at `http://localhost:8088`

### Successful Output

You should see logs indicating blocks being indexed:

```
{"message":"starting indexing","kvs":{"highest_height":"None"}}
{"message":"listening to TCP connections","kvs":{"address":"0.0.0.0","port":8088}}
{"message":"block indexed","kvs":{"caught_up":false,"height":0,...}}
{"message":"block indexed","kvs":{"caught_up":false,"height":1,...}}
...
{"message":"caught-up status changed","kvs":{"caught_up":"true"}}
```

Use the management script to view logs in real-time:

```bash
./manage-indexer.sh logs
```

## Testing the GraphQL API

### Using the Management Script

```bash
# Quick API health check
./manage-indexer.sh check-api

# Run comprehensive API tests
./manage-indexer.sh test-api
```

### Manual Testing

Once running, test the API directly:

```bash
# Get latest block
curl -s -X POST http://localhost:8088 \
  -H "Content-Type: application/json" \
  -d '{"query": "{ block { hash height protocolVersion timestamp } }"}' | jq

# Get genesis block
curl -s -X POST http://localhost:8088 \
  -H "Content-Type: application/json" \
  -d '{"query": "{ block(offset: {height: 0}) { hash height transactions { hash } } }"}' | jq
```
## Resetting the Indexer

To completely reset the indexer and start fresh:

```bash
# Using the management script (recommended)
# This will delete the entire data directory
./manage-indexer.sh stop
./manage-indexer.sh reset-db
./manage-indexer.sh start
```

<details>
<summary>Manual reset (alternative method)</summary>

```bash
# Stop the indexer process
# Remove the entire data directory
rm -rf target/data

# Restart the indexer - it will recreate the database and re-index all blocks
```
</details>

### View Database Information

```bash
# Show database details and statistics
./manage-indexer.sh db-info
```

## Troubleshooting

### Error: "Cannot decode from type; expected length X but got length Y"

This means the node metadata doesn't match your node version. Regenerate metadata:

```bash
# This will download metadata and rebuild automatically
./manage-indexer.sh generate-metadata
```

<details>
<summary>Manual metadata regeneration</summary>

```bash
subxt metadata --url ws://127.0.0.1:9944 -o .node/$(cat NODE_VERSION)/metadata.scale
cargo build -p indexer-standalone --features standalone
```
</details>

### Error: "relative URL without a base"

Check that the node URL is correctly formatted (must include `ws://` prefix).

```bash
# Verify node connection
./manage-indexer.sh check-node
```

### Connection Refused

Ensure your Substrate node is running and the WebSocket port (9944) is accessible.

```bash
# Check node status
cd ../midnight-dev-node-operator
./midnight-operator.sh status

# Check indexer configuration
cd ../midnight-indexer-management
./manage-indexer.sh status
```

### View Detailed Metrics

```bash
# Show comprehensive system metrics
./manage-indexer.sh metrics

# Monitor indexer with auto-restart
./manage-indexer.sh monitor
```

## Architecture Overview

The standalone indexer combines three components in a single binary:

- **Chain Indexer**: Connects to the node, fetches and processes blocks
- **Wallet Indexer**: Associates connected wallets with relevant transactions
- **Indexer API**: Exposes GraphQL API for queries and subscriptions

Data is stored in an embedded SQLite database, making it ideal for local development.

## GraphQL API Endpoints

The API at `http://localhost:8088` supports:

- **Queries**: `block`, `transactions`, `contractAction`, `dustGenerationStatus`
- **Mutations**: `connect` (wallet), `disconnect` (wallet)
- **Subscriptions**: `blocks`, `contractActions`, `shieldedTransactions`, `unshieldedTransactions`

## Additional Management Commands

The management script provides additional developer-friendly commands:

```bash
# View all available commands
./manage-indexer.sh help

# Restart the indexer
./manage-indexer.sh restart

# Monitor with automatic restart on failure
./manage-indexer.sh monitor

# Show comprehensive metrics
./manage-indexer.sh metrics
```

For complete documentation and advanced usage, refer to the [Indexer Management Guide](../midnight-indexer-management/INDEXER_MANAGEMENT_GUIDE.md).

For the full schema, see `indexer-api/graphql/schema-v3.graphql`.
