#!/usr/bin/env bash

################################################################################
# Midnight Node Operator Script
# Production-ready script for managing Midnight nodes in development mode
#
# Copyright (C) 2026 Midnight Developers
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# The main developers assume no liability for any issues arising from the use of
# this software.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
################################################################################

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-detect PROJECT_ROOT intelligently
if [[ -z "${PROJECT_ROOT:-}" ]]; then
    # Check if we're in the project root (Cargo.toml exists here)
    if [[ -f "$SCRIPT_DIR/Cargo.toml" ]]; then
        PROJECT_ROOT="$SCRIPT_DIR"
    # Check if we're in a subdirectory like scripts/ (Cargo.toml exists in parent)
    elif [[ -f "$SCRIPT_DIR/../Cargo.toml" ]]; then
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    else
        PROJECT_ROOT=""
    fi
fi

# Binary configuration (MO = Midnight Operator)
MO_BINARY_NAME="${MO_BINARY_NAME:-midnight-node}"
MO_BINARY_PATH="${MO_BINARY_PATH:-}"  # Direct path to binary (optional)
MO_CONFIG_FILE="${MO_CONFIG_FILE:-$SCRIPT_DIR/node-operator.conf}"

# Default configuration - can be overridden by config file or environment
MO_BINARY="${MO_BINARY:-./target/release/midnight-node}"
MO_BASE_DIR="${MO_BASE_DIR:-/tmp/midnight-nodes}"
MO_LOG_DIR="${MO_LOG_DIR:-/tmp/midnight-logs}"
MO_SEED_DIR="${MO_SEED_DIR:-/tmp/midnight-seeds}"
MO_CHAIN_SPEC_DIR="${MO_CHAIN_SPEC_DIR:-/tmp/midnight-chainspecs}"
MO_PID_DIR="${MO_PID_DIR:-/tmp/midnight-pids}"

# Build configuration
MO_CARGO_PROFILE="${MO_CARGO_PROFILE:-release}"
MO_FEATURES="${MO_FEATURES:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Node configurations: Name:P2PPort:RPCPort:NodeKey
NODE_CONFIGS=(
    "Alice:30333:9944:0000000000000000000000000000000000000000000000000000000000000001"
    "Bob:30334:9945:0000000000000000000000000000000000000000000000000000000000000002"
    "Charlie:30335:9946:0000000000000000000000000000000000000000000000000000000000000003"
    "Dave:30336:9947:0000000000000000000000000000000000000000000000000000000000000004"
    "Eve:30337:9948:0000000000000000000000000000000000000000000000000000000000000005"
    "Ferdie:30338:9949:0000000000000000000000000000000000000000000000000000000000000006"
)

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }
log_debug() {
    if [[ "${MO_VERBOSE:-false}" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $*"
    fi
}

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}================================================${NC}"
}

################################################################################
# Configuration Functions
################################################################################

# Load configuration from file if it exists
load_config() {
    if [[ -f "$MO_CONFIG_FILE" ]]; then
        log_info "Loading configuration from: $MO_CONFIG_FILE"
        # shellcheck source=/dev/null
        source "$MO_CONFIG_FILE"
    else
        log_debug "No configuration file found at: $MO_CONFIG_FILE"
    fi
}

################################################################################
# Utility Functions
################################################################################

# Get the path to the binary
get_binary_path() {
    local binary_path=""
    
    # First priority: explicitly provided MO_BINARY_PATH
    if [[ -n "$MO_BINARY_PATH" ]]; then
        binary_path="$MO_BINARY_PATH"
        if [[ ! -f "$binary_path" ]]; then
            log_error "Binary not found at specified path: $binary_path"
            return 1
        fi
    # Second priority: derive from PROJECT_ROOT
    elif [[ -n "$PROJECT_ROOT" ]]; then
        binary_path="$PROJECT_ROOT/target/$MO_CARGO_PROFILE/$MO_BINARY_NAME"
        if [[ ! -f "$binary_path" ]]; then
            log_error "Binary not found at: $binary_path"
            log_info "Please build the project first using: cargo build --release"
            log_info "Or specify binary path: MO_BINARY_PATH=/path/to/binary $0 start ..."
            return 1
        fi
    # Third priority: use MO_BINARY variable
    elif [[ -f "$MO_BINARY" ]]; then
        binary_path="$MO_BINARY"
    else
        log_error "Cannot locate binary: neither MO_BINARY_PATH nor PROJECT_ROOT is set, and MO_BINARY ($MO_BINARY) not found"
        log_info "Set MO_BINARY_PATH: MO_BINARY_PATH=/path/to/binary $0 start ..."
        log_info "Or set PROJECT_ROOT: PROJECT_ROOT=/path/to/project $0 start ..."
        return 1
    fi
    
    echo "$binary_path"
}

# Check if binary exists and is executable
check_binary() {
    local binary_path
    binary_path=$(get_binary_path) || {
        log_error "Binary validation failed"
        exit 1
    }
    
    if [[ ! -x "$binary_path" ]]; then
        log_error "Binary is not executable: $binary_path"
        log_info "Make it executable: chmod +x $binary_path"
        exit 1
    fi
    
    log_debug "Using binary: $binary_path"
    return 0
}

# Check if the process is running via PID file
is_node_running() {
    local node_name="$1"
    local pid_file="${PID_DIR}/${node_name}.pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid
        pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            log_debug "PID file exists but process $pid is not running for $node_name"
            rm -f "$pid_file"
            return 1
        fi
    fi
    
    # Fallback: check by process name
    if pgrep -f "midnight-node.*--name $node_name" > /dev/null; then
        log_warning "Node $node_name running but PID file missing, may be orphaned"
        return 0
    fi
    
    return 1
}

# Get process PID for a node
get_node_pid() {
    local node_name="$1"
    local pid_file="${PID_DIR}/${node_name}.pid"
    
    if [[ -f "$pid_file" ]]; then
        cat "$pid_file"
    else
        pgrep -f "midnight-node.*--name $node_name" | head -1
    fi
}

# Save PID to file
save_pid() {
    local node_name="$1"
    local pid="$2"
    local pid_file="${PID_DIR}/${node_name}.pid"
    
    mkdir -p "$MO_PID_DIR"
    echo "$pid" > "$pid_file"
    log_debug "Saved PID $pid to $pid_file"
}

# Remove PID file
remove_pid() {
    local node_name="$1"
    local pid_file="${PID_DIR}/${node_name}.pid"
    
    rm -f "$pid_file"
    log_debug "Removed PID file: $pid_file"
}

# Validate node name
validate_node_name() {
    local name="$1"
    local valid_nodes=("alice" "bob" "charlie" "dave" "eve" "ferdie")
    
    for valid in "${valid_nodes[@]}"; do
        if [[ "${name,,}" == "$valid" ]]; then
            return 0
        fi
    done
    
    log_error "Invalid node name: $name"
    log_info "Valid options: alice, bob, charlie, dave, eve, ferdie"
    return 1
}

# Show usage
show_usage() {
    cat << EOF
Midnight Node Operator Script

USAGE:
    $0 <command> [options]

COMMANDS:
    start       Start one or more nodes (local network)
    join        Join an existing network on a remote machine
    chainspec   Generate chainspec for distributed deployment
    stop        Stop running nodes
    status      Check node health and status
    clean       Clean database and logs
    logs        View node logs
    help        Show this help message

START OPTIONS (Local Network):
    --node NAME         Start single node in quick dev mode (Alice-only chainspec)
    --network           Start multi-node local network OR bootnode for distributed deployment
    --network --node X  Start node X as bootnode (for distributed deployment)
    --nodes N           Number of nodes in local network (default: 4, max: 6)
    --base-path PATH    Custom data directory

CHAINSPEC OPTIONS:
    --nodes N           Number of validators to include (default: 4, max: 6)
    --output PATH       Output path for chainspec (default: ./chainspec.json)

JOIN OPTIONS (Distributed Network):
    --chain PATH        Path to chainspec file (required)
    --bootnode ADDR     Bootnode multiaddr (required)
    --node NAME         Node identity: alice, bob, charlie, dave, eve, ferdie
    --base-path PATH    Custom data directory

STOP OPTIONS:
    --node NAME         Stop specific node
    --all               Stop all nodes (default)

CLEAN OPTIONS:
    --node NAME         Clean specific node data
    --all               Clean all data (default)

EXAMPLES:
    # === LOCAL DEVELOPMENT (single machine) ===
    
    # Quick single-node dev mode
    $0 start --node alice

    # 4-node local network
    $0 start --network --nodes 4

    # === DISTRIBUTED DEPLOYMENT (multiple machines) ===
    
    # Step 1: Generate chainspec on any machine
    $0 chainspec --nodes 4 --output chainspec.json
    
    # Step 2: Copy chainspec.json to all machines
    
    # Step 3: Start Alice as bootnode on Machine A
    $0 start --network --node alice
    
    # Step 4: Join from Machine B as Bob
    $0 join --chain chainspec.json \\
            --bootnode /ip4/<MACHINE_A_IP>/tcp/30333/p2p/<PEER_ID> \\
            --node bob
    
    # === OTHER COMMANDS ===
    
    # Check status
    $0 status

    # View logs
    $0 logs alice

    # Stop all
    $0 stop

NOTES:
    - Single node mode (--node alone) uses built-in dev chainspec (Alice-only)
    - Network mode (--network) uses multi-validator chainspec
    - Combine --network --node alice to start a bootnode for distributed deployment
    - All machines in a distributed network MUST use the same chainspec file
    - Bootnode address format: /ip4/<IP>/tcp/<PORT>/p2p/<PEER_ID>

EOF
}

# Generate multi-node chain specification
generate_chain_spec() {
    local num_validators="$1"
    local output_file="${CHAIN_SPEC_DIR}/local-multi-node-raw.json"
    
    check_binary
    mkdir -p "$MO_CHAIN_SPEC_DIR"
    
    if [[ -f "$output_file" ]]; then
        log_info "Using existing chain spec: $output_file" >&2
        echo "$output_file"
        return 0
    fi
    
    log_info "Generating chain spec for $num_validators validators..." >&2
    
    if ! command -v jq &> /dev/null; then
        log_error "jq is required to generate multi-node chain spec" >&2
        log_info "Install: sudo apt-get install jq (Linux) or brew install jq (macOS)" >&2
        return 1
    fi
    
    # Get binary path
    local binary_path
    binary_path=$(get_binary_path) || return 1
    
    # Step 1: Generate base chain spec from dev
    local base_spec="${CHAIN_SPEC_DIR}/local-multi-node-plain.json"
    
    log_info "Generating base chain spec..." >&2
    CFG_PRESET=dev "$binary_path" build-spec --chain dev --disable-default-bootnode 2>/dev/null > "$base_spec"
    
    if [[ ! -f "$base_spec" ]] || [[ ! -s "$base_spec" ]]; then
        log_error "Failed to generate base chain spec (file empty or missing)" >&2
        return 1
    fi
    
    log_success "Base chain spec generated ($(wc -l < "$base_spec") lines)" >&2
    
    # Step 2: Set protocol ID for network isolation
    # This ensures nodes from different test chains won't connect to each other
    local protocol_id="${PROTOCOL_ID:-midnight-local-$(date +%s)}"
    log_info "Setting protocol ID: $protocol_id" >&2
    
    jq --arg pid "$protocol_id" '.protocolId = $pid' "$base_spec" > "${base_spec}.tmp"
    if [[ ! -f "${base_spec}.tmp" ]] || [[ ! -s "${base_spec}.tmp" ]]; then
        log_error "Failed to set protocol ID" >&2
        return 1
    fi
    mv "${base_spec}.tmp" "$base_spec"
    log_success "Protocol ID set for network isolation" >&2
    
    # Step 3: Add additional validators to session.initialValidators in genesis
    local validators_to_add=$((num_validators - 1))  # Alice is already in dev chain
    log_info "Adding $validators_to_add validators to genesis initial validators..." >&2
    
    # The validators are in: .genesis.runtimeGenesis.config.session.initialValidators
    # Format: [[stash_account, {aura: aura_key, grandpa: grandpa_key}], ...]
    # Alice is already in the dev chain spec
    
    # Well-known Substrate test account addresses
    # Stash uses ECDSA-derived address, Aura uses SR25519, Grandpa uses ED25519
    
    # Bob
    local bob_stash="5DVskgSC9ncWQpxFMeUn45NU43RUq93ByEge6ApbnLk6BR9N"      # ECDSA
    local bob_aura="5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty"       # SR25519
    local bob_grandpa="5GoNkf6WdbxCFnPdAnYYQyCjAKPJgLNxXwPjwTh6DGg6gN3E"   # ED25519
    
    # Charlie  
    local charlie_stash="5EP2cMaCxLzhfD3aFAqqgu3kfXH7GcwweEv6JXZRP6ysRHkQ"  # ECDSA
    local charlie_aura="5FLSigC9HGRKVhB9FiEo4Y3koPsNmBmLJbpXg2mp1hXcS59Y"   # SR25519
    local charlie_grandpa="5DbKjhNLpqX3zqZdNBc9BGb4fHU1cRBaDhJUskrvkwfraDi6" # ED25519
    
    # Dave
    local dave_stash="5CtLD1M83vbXs42XPYyvygkUg6BxxMRBAiNqg1XD5qe7iW8g"     # ECDSA
    local dave_aura="5DAAnrj7VHTznn2AWBemMuyBwZWs6FNFjdyVXUeYum3PTXFy"      # SR25519
    local dave_grandpa="5ECTwv6cZ5nJQPk6tWfaTrEk8YH2L7X1VT4EL5Tx2ikfFwb7"  # ED25519
    
    # Eve
    local eve_stash="5GCnMRtSQq8i2fShXieQThcRyLakPyVPcTLm65Bcii4NAp5n"      # ECDSA
    local eve_aura="5HGjWAeFDfFCWPsjFQdVV2Msvz2XtMktvgocEZcCj68kUMaw"       # SR25519
    local eve_grandpa="5Ck2miBfCe1JQ4cY3NDsXyBaD6EcsgiVmEFTWwqNSs25XDEq"   # ED25519
    
    # Ferdie
    local ferdie_stash="5HkJ124K2dtXW3EFE8oUw9bkgiJMrSh4E9gNiiSCU2TpEjTS"   # ECDSA
    local ferdie_aura="5CiPPseXPECbkjWCa6MnjNokrgYjMqmKndv2rSnekmSK2DjL"    # SR25519
    local ferdie_grandpa="5E2BmpVFzYGd386XRCZ76cDePMB3sfbZp5ZKGUsrG1m6gomN" # ED25519
    
    # Build jq command based on number of validators
    local jq_cmd='.genesis.runtimeGenesis.config.session.initialValidators'
    
    if [[ $num_validators -ge 2 ]]; then
        jq_cmd="$jq_cmd + [[\"$bob_stash\", {\"aura\": \"$bob_aura\", \"grandpa\": \"$bob_grandpa\"}]]"
    fi
    if [[ $num_validators -ge 3 ]]; then
        jq_cmd="$jq_cmd + [[\"$charlie_stash\", {\"aura\": \"$charlie_aura\", \"grandpa\": \"$charlie_grandpa\"}]]"
    fi
    if [[ $num_validators -ge 4 ]]; then
        jq_cmd="$jq_cmd + [[\"$dave_stash\", {\"aura\": \"$dave_aura\", \"grandpa\": \"$dave_grandpa\"}]]"
    fi
    if [[ $num_validators -ge 5 ]]; then
        jq_cmd="$jq_cmd + [[\"$eve_stash\", {\"aura\": \"$eve_aura\", \"grandpa\": \"$eve_grandpa\"}]]"
    fi
    if [[ $num_validators -ge 6 ]]; then
        jq_cmd="$jq_cmd + [[\"$ferdie_stash\", {\"aura\": \"$ferdie_aura\", \"grandpa\": \"$ferdie_grandpa\"}]]"
    fi
    
    # Apply the transformation
    jq ".genesis.runtimeGenesis.config.session.initialValidators = $jq_cmd" "$base_spec" > "${base_spec}.tmp"
    
    if [[ ! -f "${base_spec}.tmp" ]] || [[ ! -s "${base_spec}.tmp" ]]; then
        log_error "Failed to modify chain spec with jq" >&2
        return 1
    fi
    
    mv "${base_spec}.tmp" "$base_spec"
    
    log_success "Added $num_validators validators to genesis" >&2
    
    # Step 4: Convert to raw chain spec
    log_info "Converting to raw chain spec..." >&2
    CFG_PRESET=dev "$binary_path" build-spec \
        --chain "$base_spec" \
        --raw \
        --disable-default-bootnode \
        2>/dev/null > "$output_file"
    
    if [[ -f "$output_file" ]] && [[ -s "$output_file" ]]; then
        log_success "Chain spec generated: $output_file ($(wc -l < "$output_file") lines)" >&2
        echo "$output_file"
        return 0
    else
        log_error "Failed to generate raw chain spec (file empty or missing)" >&2
        return 1
    fi
}

# Export chainspec to a specified path for distributed deployment
export_chainspec() {
    local num_validators="${1:-4}"
    local output_path="${2:-./chainspec.json}"
    
    check_binary
    
    log_info "Generating chainspec for $num_validators validators..."
    
    # Generate the chainspec
    local temp_spec
    temp_spec=$(generate_chain_spec "$num_validators")
    
    if [[ ! -f "$temp_spec" ]]; then
        log_error "Failed to generate chainspec"
        return 1
    fi
    
    # Copy to output path
    cp "$temp_spec" "$output_path"
    
    log_success "Chainspec exported to: $output_path"
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "DISTRIBUTED DEPLOYMENT INSTRUCTIONS:"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "1. Copy this chainspec to all machines in your network"
    log_info "2. On the bootnode machine (Machine A), start Alice:"
    echo ""
    echo "   $0 start --network --node alice"
    echo ""
    log_info "3. Note the peer ID from the output (12D3KooW...)"
    log_info "4. On other machines, join the network:"
    echo ""
    echo "   $0 join --chain $output_path \\"
    echo "           --bootnode /ip4/<MACHINE_A_IP>/tcp/30333/p2p/<PEER_ID> \\"
    echo "           --node bob"
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Validators included in this chainspec:"
    local validators=("Alice" "Bob" "Charlie" "Dave" "Eve" "Ferdie")
    for i in $(seq 0 $((num_validators - 1))); do
        log_info "  - ${validators[$i]}"
    done
}

# Join an existing network (for distributed deployment)
join_network() {
    local chain_spec="$1"
    local bootnode_addr="$2"
    local node_name="$3"
    local base_path="${4:-}"
    
    # Validate inputs
    if [[ -z "$chain_spec" ]]; then
        log_error "Chain spec path is required (--chain)"
        return 1
    fi
    
    if [[ ! -f "$chain_spec" ]]; then
        log_error "Chain spec file not found: $chain_spec"
        return 1
    fi
    
    if [[ -z "$bootnode_addr" ]]; then
        log_error "Bootnode address is required (--bootnode)"
        log_info "Format: /ip4/<IP>/tcp/<PORT>/p2p/<PEER_ID>"
        return 1
    fi
    
    if [[ -z "$node_name" ]]; then
        log_error "Node name is required (--node)"
        log_info "Options: alice, bob, charlie, dave, eve, ferdie"
        return 1
    fi
    
    # Validate node name
    validate_node_name "$node_name" || return 1
    
    local config
    if ! config=$(get_node_config "$node_name"); then
        log_error "Unknown node: $node_name"
        log_info "Options: alice, bob, charlie, dave, eve, ferdie"
        return 1
    fi
    
    IFS=':' read -r name p2p_port rpc_port node_key <<< "$config"
    
    # Check if already running
    if is_node_running "$name"; then
        log_warning "Node $name is already running (PID: $(get_node_pid "$name"))"
        return 1
    fi
    
    # Set base path
    if [[ -z "$base_path" ]]; then
        base_path="${BASE_DIR}/${name}"
    fi
    
    mkdir -p "$base_path" "$MO_LOG_DIR" "$MO_PID_DIR"
    
    log_info "Joining network as $name..."
    log_info "  Chain spec: $chain_spec"
    log_info "  Bootnode:   $bootnode_addr"
    log_info "  Base path:  $base_path"
    log_info "  RPC port:   $rpc_port"
    log_info "  P2P port:   $p2p_port"
    
    # Determine which dev account flag to use
    local dev_account_flag=""
    case "${name,,}" in
        alice)   dev_account_flag="--alice" ;;
        bob)     dev_account_flag="--bob" ;;
        charlie) dev_account_flag="--charlie" ;;
        dave)    dev_account_flag="--dave" ;;
        eve)     dev_account_flag="--eve" ;;
        ferdie)  dev_account_flag="--ferdie" ;;
    esac
    
    # Get binary path
    local binary_path
    binary_path=$(get_binary_path) || return 1
    
    # Build command
    local cmd_args=(
        "--chain" "$chain_spec"
        "--base-path" "$base_path"
        "--name" "$name"
        "--port" "$p2p_port"
        "--rpc-port" "$rpc_port"
        "--validator"
        "--bootnodes" "$bootnode_addr"
        "--rpc-methods" "unsafe"
        "--rpc-cors" "all"
        "--unsafe-rpc-external"
        "--node-key" "$node_key"
        "$dev_account_flag"
    )
    
    # Start node as background process
    CFG_PRESET=dev \
    "$binary_path" "${cmd_args[@]}" > "${LOG_DIR}/${name}.log" 2>&1 &
    
    local pid=$!
    save_pid "$name" "$pid"
    sleep 3
    
    if ! ps -p "$pid" > /dev/null 2>&1; then
        log_error "Failed to start $name"
        log_info "Check logs: ${LOG_DIR}/${name}.log"
        remove_pid "$name"
        return 1
    fi
    
    log_success "Started $name (PID: $pid)"
    
    echo ""
    log_info "Node is connecting to the network..."
    log_info "Check status: $0 status"
    log_info "View logs:    $0 logs $name"
    log_info "Stop node:    $0 stop --node $name"
    
    # Wait for RPC and insert session keys
    log_info "Waiting for RPC to be ready..."
    if wait_for_node_ready "$name" "$rpc_port" 30; then
        insert_session_keys "$name" "$rpc_port"
    else
        log_warning "RPC not ready, session keys not inserted"
        log_info "Insert manually later if needed"
    fi
    
    return 0
}

# Get node configuration by name
get_node_config() {
    local name="$1"
    for config in "${NODE_CONFIGS[@]}"; do
        IFS=':' read -r node_name p2p rpc key <<< "$config"
        if [[ "${node_name,,}" == "${name,,}" ]]; then
            echo "$node_name:$p2p:$rpc:$key"
            return 0
        fi
    done
    return 1
}

# Wait for a node's RPC endpoint to be ready
# Returns 0 on success, 1 on timeout
wait_for_node_ready() {
    local node_name="$1"
    local rpc_port="$2"
    local max_attempts="${3:-30}"  # Default 30 attempts (30 seconds)
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        # Try to call system_health RPC method
        if response=$(curl -s --connect-timeout 1 -H "Content-Type: application/json" \
                     -d '{"jsonrpc":"2.0","method":"system_health","params":[],"id":1}' \
                     "http://localhost:$rpc_port" 2>/dev/null); then
            # Check if we got a valid response with result
            if echo "$response" | jq -e '.result' > /dev/null 2>&1; then
                return 0
            fi
        fi
        
        ((attempt++))
        sleep 1
    done
    
    log_error "Timeout waiting for $node_name RPC on port $rpc_port" >&2
    return 1
}

# Insert session keys for a validator node using well-known dev keys
insert_session_keys() {
    local node_name="$1"
    local rpc_port="$2"
    
    log_info "Inserting session keys for $node_name..." >&2
    
    # Define well-known dev keys for each validator
    # Aura uses SR25519, Grandpa uses ED25519
    local aura_key grandpa_key
    case "${node_name,,}" in
        alice)
            aura_key="0xd43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d"  # //Alice SR25519
            grandpa_key="0x88dc3417d5058ec4b4503e0c12ea1a0a89be200fe98922423d4334014fa6b0ee"  # //Alice ED25519
            ;;
        bob)
            aura_key="0x8eaf04151687736326c9fea17e25fc5287613693c912909cb226aa4794f26a48"  # //Bob SR25519
            grandpa_key="0xd17c2d7823ebf260fd138f2d7e27d114c0145d968b5ff5006125f2414fadae69"  # //Bob ED25519
            ;;
        charlie)
            aura_key="0x90b5ab205c6974c9ea841be688864633dc9ca8a357843eeacf2314649965fe22"  # //Charlie SR25519
            grandpa_key="0x439660b36c6c03afafca027b910b4fecf99801834c62a5e6006f27d978de234f"  # //Charlie ED25519
            ;;
        dave)
            aura_key="0x306721211d5404bd9da88e0204360a1a9ab8b87c66c1bc2fcdd37f3c2222cc20"  # //Dave SR25519
            grandpa_key="0x5e639b43e0052c47447dac87d6fd2b6ec50bdd4d0f614e4299c665249bbd09d9"  # //Dave ED25519
            ;;
        eve)
            aura_key="0xe659a7a1628cdd93febc04a4e0646ea20e9f5f0ce097d9a05290d4a9e054df4e"  # //Eve SR25519
            grandpa_key="0x1dfe3e22cc0d45c70779c1095f7489a8ef3cf52d62fbd8c2fa38c9f1723502b5"  # //Eve ED25519
            ;;
        ferdie)
            aura_key="0x1cbd2d43530a44705ad088af313e18f80b53ef16b36177cd4b77b846f2a5f07c"  # //Ferdie SR25519
            grandpa_key="0x568cb4a574c6d178feb39c27dfc8b3f789e5f5423e19c71633c748b9acf086b5"  # //Ferdie ED25519
            ;;
        *)
            log_error "Unknown validator: $node_name" >&2
            return 1
            ;;
    esac
    
    # Insert Aura key (SR25519)
    curl -sS -H "Content-Type: application/json" \
        -d "{\"id\":1,\"jsonrpc\":\"2.0\",\"method\":\"author_insertKey\",\"params\":[\"aura\",\"//$(echo ${node_name^})\",\"$aura_key\"]}" \
        http://localhost:$rpc_port > /dev/null || {
            log_warning "Failed to insert Aura key for $node_name" >&2
        }
    
    # Insert Grandpa key (ED25519)
    curl -sS -H "Content-Type: application/json" \
        -d "{\"id\":1,\"jsonrpc\":\"2.0\",\"method\":\"author_insertKey\",\"params\":[\"gran\",\"//$(echo ${node_name^})\",\"$grandpa_key\"]}" \
        http://localhost:$rpc_port > /dev/null || {
            log_warning "Failed to insert Grandpa key for $node_name" >&2
        }
    
    log_info "✓ Session keys inserted for $node_name" >&2
}
# Start a single node in dev mode (always runs as validator)
start_node() {
    local name="$1"
    local base_path="$2"
    
    # Validate node name
    validate_node_name "$name" || return 1
    
    local config
    if ! config=$(get_node_config "$name"); then
        log_error "Unknown node: $name"
        return 1
    fi
    
    IFS=':' read -r node_name p2p_port rpc_port node_key <<< "$config"
    
    # Check if already running
    if is_node_running "$node_name"; then
        log_warning "Node $node_name is already running (PID: $(get_node_pid "$node_name"))"
        return 1
    fi
    
    mkdir -p "$MO_SEED_DIR" "$MO_LOG_DIR" "$MO_PID_DIR"
    chmod 700 "$MO_SEED_DIR"
    
    # Create seed file
    local seed_file="${SEED_DIR}/${node_name}-seed"
    echo "//${node_name}" > "$seed_file"
    chmod 600 "$seed_file"
    
    # Create node key file
    local key_file="${SEED_DIR}/${node_name}-key"
    echo "$node_key" > "$key_file"
    chmod 600 "$key_file"
    
    log_info "Starting $node_name..."
    log_info "  Base path: $base_path"
    log_info "  RPC:       ws://localhost:$rpc_port"
    
    # Build command - keep it simple like the working manual test
    local cmd_args=(
        "--dev"
        "--base-path" "$base_path"
        "--name" "$node_name"
    )
    
    # Add custom ports if not defaults
    if [[ "$rpc_port" != "9944" ]]; then
        cmd_args+=("--rpc-port" "$rpc_port")
    fi
    
    if [[ "$p2p_port" != "30333" ]]; then
        cmd_args+=("--port" "$p2p_port")
    fi
    
    # Get binary path
    local binary_path
    binary_path=$(get_binary_path) || return 1
    
    # Start node
    CFG_PRESET=dev \
    "$binary_path" "${cmd_args[@]}" > "${LOG_DIR}/${node_name}.log" 2>&1 &
    
    local pid=$!
    save_pid "$node_name" "$pid"
    sleep 2
    
    if ps -p "$pid" > /dev/null 2>&1; then
        log_success "Started $node_name (PID: $pid)"
        log_info "Logs: tail -f ${LOG_DIR}/${node_name}.log"
        return 0
    else
        log_error "Failed to start $node_name"
        log_info "Check logs: ${LOG_DIR}/${node_name}.log"
        remove_pid "$node_name"
        return 1
    fi
}

# Start network
# Args: num_nodes, [bootnode_name]
# If bootnode_name is provided, start only that node as bootnode using existing chainspec
start_network() {
    local num_nodes="${1:-4}"
    local specific_node="${2:-}"  # Optional: start only this specific node as bootnode
    
    # If starting a specific node, we're in bootnode-only mode
    local bootnode_only=false
    if [[ -n "$specific_node" ]]; then
        bootnode_only=true
        num_nodes=1
    fi
    
    if [[ "$bootnode_only" == "false" ]] && [[ $num_nodes -lt 1 || $num_nodes -gt 6 ]]; then
        log_error "Number of nodes must be between 1 and 6"
        return 1
    fi
    
    check_binary
    mkdir -p "$MO_SEED_DIR" "$MO_LOG_DIR"
    
    local chain_spec=""
    
    # Generate or use existing chain spec
    if [[ "$bootnode_only" == "true" ]]; then
        # Bootnode-only mode: use existing chainspec or generate default 4-validator
        chain_spec="${CHAIN_SPEC_DIR}/local-multi-node-raw.json"
        if [[ ! -f "$chain_spec" ]]; then
            log_info "No existing chainspec found, generating 4-validator chainspec..."
            chain_spec=$(generate_chain_spec 4)
        else
            log_info "Using existing chainspec: $chain_spec"
        fi
    elif [[ $num_nodes -gt 1 ]]; then
        log_info "Generating chain spec for $num_nodes validators..."
        chain_spec=$(generate_chain_spec "$num_nodes")
    fi
    
    if [[ -n "$chain_spec" ]] && [[ ! -f "$chain_spec" ]]; then
        log_error "Failed to generate chain spec"
        return 1
    fi
    
    if [[ -n "$chain_spec" ]]; then
        log_success "Using chain spec: $chain_spec"
    fi
    
    echo ""
    
    # Determine bootnode configuration
    local bootnode_config
    local bootnode_index=0
    
    if [[ "$bootnode_only" == "true" ]]; then
        # Find the specific node's config
        for i in "${!NODE_CONFIGS[@]}"; do
            IFS=':' read -r name _ _ _ <<< "${NODE_CONFIGS[$i]}"
            if [[ "${name,,}" == "${specific_node,,}" ]]; then
                bootnode_config="${NODE_CONFIGS[$i]}"
                bootnode_index=$i
                break
            fi
        done
        if [[ -z "$bootnode_config" ]]; then
            log_error "Unknown node: $specific_node"
            return 1
        fi
        log_info "Starting $specific_node as bootnode..."
    else
        bootnode_config="${NODE_CONFIGS[0]}"
        log_info "Starting $num_nodes-node network..."
    fi
    
    IFS=':' read -r bootnode_name bootnode_p2p bootnode_rpc bootnode_key <<< "$bootnode_config"
    
    local bootnode_base_path="${BASE_DIR}/${bootnode_name}"
    mkdir -p "$bootnode_base_path" "$MO_LOG_DIR" "$MO_PID_DIR"
    
    log_info "Starting bootnode ($bootnode_name)..."
    
    # Determine which dev account flag to use
    local dev_account_flag=""
    case "${bootnode_name,,}" in
        alice)   dev_account_flag="--alice" ;;
        bob)     dev_account_flag="--bob" ;;
        charlie) dev_account_flag="--charlie" ;;
        dave)    dev_account_flag="--dave" ;;
        eve)     dev_account_flag="--eve" ;;
        ferdie)  dev_account_flag="--ferdie" ;;
    esac
    
    # Build bootnode command
    local bootnode_cmd_args=(
        "--base-path" "$bootnode_base_path"
        "--name" "$bootnode_name"
        "--port" "$bootnode_p2p"
        "--rpc-port" "$bootnode_rpc"
        "--prometheus-port" "9615"
        "--validator"
        "$dev_account_flag"
    )
    
    # Bootnode-only mode or multi-node: use chainspec
    # Single node without specific node: use --dev
    if [[ "$bootnode_only" == "true" ]] || [[ $num_nodes -gt 1 ]]; then
        bootnode_cmd_args+=("--chain" "$chain_spec")
        bootnode_cmd_args+=("--node-key" "$bootnode_key")
        bootnode_cmd_args+=("--rpc-methods" "unsafe")
        bootnode_cmd_args+=("--rpc-cors" "all")
        bootnode_cmd_args+=("--unsafe-rpc-external")
        bootnode_cmd_args+=("--force-authoring")
    else
        bootnode_cmd_args+=("--dev")
    fi
    
    # Get binary path
    local binary_path
    binary_path=$(get_binary_path) || return 1
    
    CFG_PRESET=dev \
    "$binary_path" "${bootnode_cmd_args[@]}" > "${LOG_DIR}/${bootnode_name}.log" 2>&1 &
    
    local bootnode_pid=$!
    save_pid "$bootnode_name" "$bootnode_pid"
    sleep 3
    
    if ! ps -p "$bootnode_pid" > /dev/null 2>&1; then
        log_error "Failed to start bootnode $bootnode_name"
        log_info "Check logs: ${LOG_DIR}/${bootnode_name}.log"
        remove_pid "$bootnode_name"
        return 1
    fi
    
    log_success "Started $bootnode_name (PID: $bootnode_pid)"
    
    # Get bootnode peer ID from logs
    local bootnode_peer_id=$(grep "Local node identity" "${LOG_DIR}/${bootnode_name}.log" 2>/dev/null | \
        sed -n 's/.*Local node identity is: \(.*\)/\1/p' | tail -1)
    
    if [[ -z "$bootnode_peer_id" ]]; then
        # Fallback to deterministic peer ID for node key 0x...01
        bootnode_peer_id="12D3KooWEyoppNCUx8Yx66oV9fJnriXwCcXwDDUA2kj6vnc6iDEp"
        log_info "Using deterministic peer ID: $bootnode_peer_id"
    else
        log_success "Bootnode peer ID: $bootnode_peer_id"
    fi
    
    local bootnode_addr="/ip4/127.0.0.1/tcp/${bootnode_p2p}/p2p/${bootnode_peer_id}"
    
    # Start remaining nodes (if multi-node network)
    if [[ $num_nodes -gt 1 ]]; then
        for i in $(seq 1 $((num_nodes - 1))); do
            local node_config="${NODE_CONFIGS[$i]}"
            IFS=':' read -r node_name p2p_port rpc_port node_key <<< "$node_config"
            
            local base_path="${BASE_DIR}/${node_name}"
            
            # Check if already running
            if is_node_running "$node_name"; then
                log_warning "Node $node_name is already running (PID: $(get_node_pid "$node_name"))"
                continue
            fi
            
            mkdir -p "$base_path" "$MO_LOG_DIR" "$MO_PID_DIR"
            
            log_info "Starting $node_name (validator)..."
            
            # Build command with chain spec and validator flag
            local prom_port=$((9615 + i))
            local cmd_args=(
                "--chain" "$chain_spec"
                "--base-path" "$base_path"
                "--name" "$node_name"
                "--port" "$p2p_port"
                "--rpc-port" "$rpc_port"
                "--prometheus-port" "$prom_port"
                "--validator"
                "--bootnodes" "$bootnode_addr"
                "--node-key" "$node_key"
                "--rpc-methods" "unsafe"
            )
            
            # Add dev account flags for session keys
            case "${node_name,,}" in
                bob)
                    cmd_args+=("--bob")
                    ;;
                charlie)
                    cmd_args+=("--charlie")
                    ;;
                dave)
                    cmd_args+=("--dave")
                    ;;
                eve)
                    cmd_args+=("--eve")
                    ;;
                ferdie)
                    cmd_args+=("--ferdie")
                    ;;
            esac
            
            # Get binary path
            local binary_path
            binary_path=$(get_binary_path) || continue
            
            # Start node
            CFG_PRESET=dev \
            "$binary_path" "${cmd_args[@]}" > "${LOG_DIR}/${node_name}.log" 2>&1 &
            
            local pid=$!
            save_pid "$node_name" "$pid"
            sleep 2
            
            if ps -p "$pid" > /dev/null 2>&1; then
                log_success "Started $node_name (PID: $pid)"
            else
                log_error "Failed to start $node_name"
                log_info "Check logs: ${LOG_DIR}/${node_name}.log"
                remove_pid "$node_name"
            fi
        done
    fi
    
    echo ""
    log_success "Network started!"
    echo ""
    
    # Insert session keys for bootnode in bootnode-only mode
    if [[ "$bootnode_only" == "true" ]]; then
        log_info "Waiting for bootnode to be ready..."
        if wait_for_node_ready "$bootnode_name" "$bootnode_rpc" 30; then
            insert_session_keys "$bootnode_name" "$bootnode_rpc"
        else
            log_warning "Bootnode not ready, session keys not inserted"
        fi
        echo ""
        
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "BOOTNODE STARTED"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        log_info "  Node:       $bootnode_name"
        log_info "  RPC:        ws://localhost:$bootnode_rpc"
        log_info "  P2P:        $bootnode_p2p"
        log_info "  Peer ID:    $bootnode_peer_id"
        echo ""
        log_info "Other nodes can join using:"
        echo ""
        echo "  $0 join \\"
        echo "      --chain <PATH_TO_CHAINSPEC> \\"
        echo "      --bootnode /ip4/<THIS_MACHINE_IP>/tcp/$bootnode_p2p/p2p/$bootnode_peer_id \\"
        echo "      --node <NODE_NAME>"
        echo ""
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    elif [[ $num_nodes -gt 1 ]]; then
        # Insert session keys for all validators in multi-node mode
        log_info "Waiting for nodes to be ready..."
        
        # Wait for each node's RPC to be available, then insert keys
        local nodes_ready=true
        
        # Define node list with ports
        local node_list=("Alice:9944")
        [[ $num_nodes -ge 2 ]] && node_list+=("Bob:9945")
        [[ $num_nodes -ge 3 ]] && node_list+=("Charlie:9946")
        [[ $num_nodes -ge 4 ]] && node_list+=("Dave:9947")
        [[ $num_nodes -ge 5 ]] && node_list+=("Eve:9948")
        [[ $num_nodes -ge 6 ]] && node_list+=("Ferdie:9949")
        
        for node_info in "${node_list[@]}"; do
            IFS=':' read -r name port <<< "$node_info"
            
            if wait_for_node_ready "$name" "$port" 30; then
                insert_session_keys "$name" "$port"
            else
                log_error "Node $name not ready, skipping key insertion"
                nodes_ready=false
            fi
        done
        
        if [[ "$nodes_ready" == "false" ]]; then
            log_warning "Some nodes may not have session keys inserted"
        fi
        echo ""
        
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "RPC Endpoints:"
        for i in $(seq 0 $((num_nodes - 1))); do
            IFS=':' read -r name _ rpc _ <<< "${NODE_CONFIGS[$i]}"
            log_info "  $name: ws://localhost:$rpc"
        done
        echo ""
        log_warning "All validators can produce blocks in multi-node mode"
        log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi
    
    echo ""
    log_info "Commands:"
    log_info "  Status:  $0 status"
    log_info "  Logs:    $0 logs ${bootnode_name,,}"
    log_info "  Stop:    $0 stop"
}

# Stop nodes
stop_nodes() {
    local node_name="${1:-all}"
    
    if [[ "$node_name" == "all" ]]; then
        log_info "Stopping all midnight nodes..."
        
        local stopped_count=0
        # Stop nodes with PID files first
        if [[ -d "$MO_PID_DIR" ]]; then
            for pid_file in "$MO_PID_DIR"/*.pid; do
                [[ -f "$pid_file" ]] || continue
                local name=$(basename "$pid_file" .pid)
                if stop_single_node "$name"; then
                    ((stopped_count++))
                fi
            done
        fi
        
        # Clean up any orphaned processes
        if pgrep -f midnight-node > /dev/null; then
            log_warning "Cleaning up orphaned midnight-node processes..."
            pkill -SIGTERM -f midnight-node || true
            sleep 2
            
            # Force kill if still running
            if pgrep -f midnight-node > /dev/null; then
                log_warning "Force killing remaining processes..."
                pkill -SIGKILL -f midnight-node || true
            fi
        fi
        
        if [[ $stopped_count -gt 0 ]]; then
            log_success "Stopped $stopped_count node(s)"
        else
            log_info "No running nodes found"
        fi
    else
        validate_node_name "$node_name" || return 1
        stop_single_node "$node_name"
    fi
}

# Stop a single node
stop_single_node() {
    local node_name="$1"
    # Capitalize first letter to match the actual node name in the process
    local capitalized_name="$(tr '[:lower:]' '[:upper:]' <<< ${node_name:0:1})${node_name:1}"
    
    log_info "Stopping $capitalized_name..."
    
    local pid
    pid=$(get_node_pid "$capitalized_name")
    
    if [[ -z "$pid" ]]; then
        log_warning "Node $capitalized_name not running"
        remove_pid "$capitalized_name"
        return 1
    fi
    
    # Send SIGTERM for graceful shutdown
    if kill -TERM "$pid" 2>/dev/null; then
        # Wait for graceful shutdown (max 15 seconds)
        local count=0
        while ps -p "$pid" > /dev/null 2>&1 && [[ $count -lt 15 ]]; do
            sleep 1
            ((count++))
        done
        
        # Force kill if still running
        if ps -p "$pid" > /dev/null 2>&1; then
            log_warning "Graceful shutdown failed, forcing kill"
            kill -KILL "$pid" 2>/dev/null || true
            sleep 1
        fi
        
        remove_pid "$capitalized_name"
        log_success "Stopped $capitalized_name"
        return 0
    else
        log_error "Failed to stop $capitalized_name (PID: $pid)"
        remove_pid "$capitalized_name"
        return 1
    fi
}

# Check status
check_status() {
    print_header "Midnight Node Status"
    
    if ! command -v jq &> /dev/null; then
        log_warning "jq not installed, limited status available"
        log_info "Install jq for full status: sudo apt-get install jq (Linux) or brew install jq (macOS)"
        echo ""
        pgrep -a midnight-node || log_info "No nodes running"
        return
    fi
    
    local found_any=false
    local total_nodes=0
    local healthy_nodes=0
    
    for config in "${NODE_CONFIGS[@]}"; do
        IFS=':' read -r name _ rpc _ <<< "$config"
        
        # Check if process is running
        if ! is_node_running "$name"; then
            continue
        fi
        
        found_any=true
        ((total_nodes++))
        
        local pid
        pid=$(get_node_pid "$name")
        
        # Check RPC
        if response=$(curl -s --connect-timeout 2 -H "Content-Type: application/json" \
                     -d '{"jsonrpc":"2.0","method":"system_health","params":[],"id":1}' \
                     "http://localhost:$rpc" 2>/dev/null); then
            
            local peers=$(echo "$response" | jq -r '.result.peers // 0')
            local syncing=$(echo "$response" | jq -r '.result.isSyncing // false')
            
            # Get block number
            local block_response=$(curl -s --connect-timeout 2 -H "Content-Type: application/json" \
                                  -d '{"jsonrpc":"2.0","method":"chain_getHeader","params":[],"id":1}' \
                                  "http://localhost:$rpc" 2>/dev/null)
            local block_hex=$(echo "$block_response" | jq -r '.result.number // "0x0"')
            local block_num=$((16#${block_hex#0x}))
            
            log_success "$name (PID: $pid, RPC: ws://localhost:$rpc)"
            echo "    Peers: $peers | Syncing: $syncing | Block: $block_num"
            ((healthy_nodes++))
        else
            log_warning "$name (PID: $pid, RPC: ws://localhost:$rpc) - RPC not responding"
        fi
    done
    
    if [[ "$found_any" == "false" ]]; then
        log_info "No nodes running"
    else
        echo ""
        log_info "Summary: $healthy_nodes/$total_nodes nodes healthy"
    fi
}

# View logs
view_logs() {
    local node_name="${1:-}"
    
    if [[ -z "$node_name" ]]; then
        log_error "Specify node name: $0 logs alice"
        return 1
    fi
    
    local config
    if ! config=$(get_node_config "$node_name"); then
        log_error "Unknown node: $node_name"
        return 1
    fi
    
    IFS=':' read -r name _ _ _ <<< "$config"
    local log_file="${LOG_DIR}/${name}.log"
    
    if [[ ! -f "$log_file" ]]; then
        log_error "Log file not found: $log_file"
        return 1
    fi
    
    log_info "Viewing logs for $name (Ctrl+C to exit)"
    tail -f "$log_file"
}

# Clean data
clean_data() {
    local node_name="${1:-all}"
    
    log_warning "Cleaning data..."
    
    # Stop nodes first
    if pgrep -f midnight-node > /dev/null; then
        log_info "Stopping running nodes first..."
        stop_nodes "$node_name"
        sleep 1
    fi
    
    if [[ "$node_name" == "all" ]]; then
        if [[ -d "$MO_BASE_DIR" ]]; then
            rm -rf "$MO_BASE_DIR"
            log_info "Removed: $MO_BASE_DIR"
        fi
        if [[ -d "$MO_SEED_DIR" ]]; then
            rm -rf "$MO_SEED_DIR"
            log_info "Removed: $MO_SEED_DIR"
        fi
        if [[ -d "$MO_LOG_DIR" ]]; then
            rm -rf "$MO_LOG_DIR"
            log_info "Removed: $MO_LOG_DIR"
        fi
    else
        local config
        if ! config=$(get_node_config "$node_name"); then
            log_error "Unknown node: $node_name"
            return 1
        fi
        
        IFS=':' read -r name _ _ _ <<< "$config"
        local node_dir="${BASE_DIR}/${name}"
        
        if [[ -d "$node_dir" ]]; then
            rm -rf "$node_dir"
            log_info "Removed: $node_dir"
        fi
        
        local log_file="${LOG_DIR}/${name}.log"
        if [[ -f "$log_file" ]]; then
            rm -f "$log_file"
            log_info "Removed: $log_file"
        fi
    fi
    
    log_success "Cleanup complete"
}

# Main command dispatcher
main() {
    # Load configuration if available
    load_config
    
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        start)
            local mode="single"
            local node_name=""
            local num_nodes=4
            local base_path=""
            local network_mode=false
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --node)
                        node_name="$2"
                        shift 2
                        ;;
                    --network)
                        network_mode=true
                        shift
                        ;;
                    --nodes)
                        num_nodes="$2"
                        shift 2
                        ;;
                    --base-path)
                        base_path="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        show_usage
                        exit 1
                        ;;
                esac
            done
            
            check_binary
            
            if [[ "$network_mode" == "true" ]]; then
                if [[ -n "$node_name" ]]; then
                    # Network mode with specific node = start as bootnode
                    start_network "1" "$node_name"
                else
                    # Network mode with count = start multiple nodes locally
                    start_network "$num_nodes"
                fi
            else
                # Single node dev mode
                if [[ -z "$node_name" ]]; then
                    node_name="alice"
                fi
                if [[ -z "$base_path" ]]; then
                    base_path="${BASE_DIR}/${node_name}"
                fi
                start_node "$node_name" "$base_path"
            fi
            ;;
        
        chainspec)
            local num_nodes=4
            local output_path="./chainspec.json"
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --nodes)
                        num_nodes="$2"
                        shift 2
                        ;;
                    --output)
                        output_path="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        show_usage
                        exit 1
                        ;;
                esac
            done
            
            export_chainspec "$num_nodes" "$output_path"
            ;;
        
        join)
            local chain_spec=""
            local bootnode_addr=""
            local node_name=""
            local base_path=""
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --chain)
                        chain_spec="$2"
                        shift 2
                        ;;
                    --bootnode)
                        bootnode_addr="$2"
                        shift 2
                        ;;
                    --node)
                        node_name="$2"
                        shift 2
                        ;;
                    --base-path)
                        base_path="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        show_usage
                        exit 1
                        ;;
                esac
            done
            
            check_binary
            join_network "$chain_spec" "$bootnode_addr" "$node_name" "$base_path"
            ;;
            
        stop)
            local target="all"
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --node)
                        target="$2"
                        shift 2
                        ;;
                    --all)
                        target="all"
                        shift
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        exit 1
                        ;;
                esac
            done
            
            stop_nodes "$target"
            ;;
            
        status)
            check_status
            ;;
            
        logs)
            if [[ $# -eq 0 ]]; then
                log_error "Specify node name: $0 logs alice"
                exit 1
            fi
            view_logs "$1"
            ;;
            
        clean)
            local target="all"
            
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --node)
                        target="$2"
                        shift 2
                        ;;
                    --all)
                        target="all"
                        shift
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        exit 1
                        ;;
                esac
            done
            
            clean_data "$target"
            ;;
            
        help|--help|-h)
            show_usage
            ;;
            
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
