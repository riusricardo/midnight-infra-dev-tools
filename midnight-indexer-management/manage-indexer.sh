#!/usr/bin/env bash

################################################################################
# Midnight Indexer Management Script
# Production-ready script for managing the midnight indexer (standalone mode)
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

# Auto-detect MI_PROJECT_ROOT intelligently
if [[ -z "${MI_PROJECT_ROOT:-}" ]]; then
    # Check if we're in the project root (Cargo.toml exists here)
    if [[ -f "$SCRIPT_DIR/Cargo.toml" ]]; then
        MI_PROJECT_ROOT="$SCRIPT_DIR"
    # Check if we're in a subdirectory like scripts/ (Cargo.toml exists in parent)
    elif [[ -f "$SCRIPT_DIR/../Cargo.toml" ]]; then
        MI_PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    else
        MI_PROJECT_ROOT=""
    fi
fi

MI_BINARY_NAME="${MI_BINARY_NAME:-indexer-standalone}"
MI_BINARY_PATH="${MI_BINARY_PATH:-}"  # Direct path to binary (optional)
MI_PID_FILE="${MI_PID_FILE:-/tmp/${MI_BINARY_NAME}.pid}"
MI_LOG_FILE="${MI_LOG_FILE:-/tmp/${MI_BINARY_NAME}.log}"
MI_CONFIG_FILE="${MI_CONFIG_FILE:-$SCRIPT_DIR/indexer-standalone/config.yaml}"

# Node configuration
MI_NODE_URL="${MI_NODE_URL:-ws://127.0.0.1:9944}"
MI_NODE_VERSION_FILE="${MI_NODE_VERSION_FILE:-$SCRIPT_DIR/NODE_VERSION}"

# Database configuration
MI_DATA_DIR="${MI_DATA_DIR:-$SCRIPT_DIR/target/data}"
MI_DB_FILE="${MI_DB_FILE:-$MI_DATA_DIR/indexer.sqlite}"

# API configuration
MI_API_PORT="${MI_API_PORT:-8088}"

# Default secret (32-byte hex, 64 hex chars) - CHANGE THIS IN PRODUCTION!
DEFAULT_SECRET="303132333435363738393031323334353637383930313233343536373839303132"
MI_APP_SECRET="${MI_APP_SECRET:-$DEFAULT_SECRET}"

# Build configuration
MI_CARGO_PROFILE="${MI_CARGO_PROFILE:-release}"
MI_FEATURES="${MI_FEATURES:-standalone}"
MI_RUST_LOG="${MI_RUST_LOG:-info}"
MI_RUST_BACKTRACE="${MI_RUST_BACKTRACE:-1}"

# Monitoring configuration
MI_HEALTH_CHECK_INTERVAL="${MI_HEALTH_CHECK_INTERVAL:-30}"
MI_MAX_RESTART_ATTEMPTS="${MI_MAX_RESTART_ATTEMPTS:-3}"
MI_RESTART_DELAY="${MI_RESTART_DELAY:-5}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    if [[ "${MI_VERBOSE:-false}" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $*"
    fi
}

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}================================================${NC}"
}

# Get the path to the binary
get_binary_path() {
    local binary_path=""
    
    # First priority: explicitly provided BINARY_PATH
    if [[ -n "$MI_BINARY_PATH" ]]; then
        binary_path="$MI_BINARY_PATH"
        if [[ ! -f "$binary_path" ]]; then
            log_error "MI_BINARY_PATH is set but file does not exist:" >&2
            log_error "  Path: $binary_path" >&2
            return 1
        fi
    # Second priority: derive from MI_PROJECT_ROOT
    elif [[ -n "$MI_PROJECT_ROOT" ]]; then
        binary_path="$MI_PROJECT_ROOT/target/$MI_CARGO_PROFILE/$MI_BINARY_NAME"
        if [[ ! -f "$binary_path" ]]; then
            log_error "Binary not found in MI_PROJECT_ROOT:" >&2
            log_error "  Expected: $binary_path" >&2
            log_error "  MI_PROJECT_ROOT: $MI_PROJECT_ROOT" >&2
            log_error "  Profile: $MI_CARGO_PROFILE" >&2
            return 1
        fi
    else
        log_error "Cannot locate '$MI_BINARY_NAME' binary:" >&2
        log_error "  Checked locations:" >&2
        log_error "    - MI_BINARY_PATH: ${MI_BINARY_PATH:-<not set>}" >&2
        log_error "    - MI_PROJECT_ROOT: ${MI_PROJECT_ROOT:-<not set>}" >&2
        return 1
    fi
    
    echo "$binary_path"
}

# Check if the process is running
is_running() {
    if [[ -f "$MI_PID_FILE" ]]; then
        local pid
        pid=$(cat "$MI_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            log_warn "PID file exists but process is not running"
            rm -f "$MI_PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Get process PID
get_pid() {
    if [[ -f "$MI_PID_FILE" ]]; then
        cat "$MI_PID_FILE"
    fi
}

################################################################################
# Node Management Functions
################################################################################

check_node() {
    log_info "Checking node connection at: $MI_NODE_URL"
    
    if ! command -v curl > /dev/null 2>&1; then
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "MISSING DEPENDENCY: curl is required but not installed"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "Install with: sudo apt install curl (Linux) or brew install curl (macOS)"
        return 1
    fi
    
    # Convert ws:// to http:// for curl
    local node_rpc_url="${MI_NODE_URL/ws:/http:}"
    node_rpc_url="${node_rpc_url/wss:/https:}"
    
    local response
    response=$(curl -s --connect-timeout 5 -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"system_health","params":[],"id":1}' \
        "$node_rpc_url" 2>/dev/null) || {
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "NODE CONNECTION FAILED: Cannot connect to $MI_NODE_URL"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        log_info "The indexer requires a running Midnight node to index blocks."
        echo ""
        log_info "Possible solutions:"
        log_info "  1. Start a node with the node operator script:"
        log_info "     cd ../midnight-dev-node-operator"
        log_info "     ./midnight-operator.sh start --node alice"
        echo ""
        log_info "  2. Or specify a different node URL:"
        log_info "     ./manage-indexer.sh --node-url ws://192.168.1.100:9944 start"
        echo ""
        log_info "  3. Check if the node is running and accessible:"
        log_info '     curl -s '"$node_rpc_url"' -d '\''{"jsonrpc":"2.0","method":"system_health","params":[],"id":1}'\'''
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    }
    
    if echo "$response" | jq -e '.result' > /dev/null 2>&1; then
        log_info "Node connection: ${GREEN}OK${NC}"
        return 0
    else
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "NODE RETURNED INVALID RESPONSE"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "URL: $MI_NODE_URL"
        log_info "Response: $response"
        echo ""
        log_info "The node responded but with an unexpected format."
        log_info "This may indicate:"
        log_info "  - The node is still initializing (try again in a few seconds)"
        log_info "  - The endpoint is not a Midnight/Substrate node"
        log_info "  - RPC methods are disabled on the node"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
}

get_node_version() {
    local node_rpc_url="${NODE_URL/ws:/http:}"
    
    local version
    version=$(curl -s -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"system_version","params":[],"id":1}' \
        "$node_rpc_url" 2>/dev/null | jq -r '.result') || {
        log_error "Cannot get node version"
        return 1
    }
    
    echo "$version"
}

check_node_version() {
    print_header "Checking Node Version Compatibility"
    
    local node_version
    node_version=$(get_node_version) || return 1
    
    log_info "Running node version: $node_version"
    
    if [[ -f "$MI_NODE_VERSION_FILE" ]]; then
        local expected_version
        expected_version=$(cat "$MI_NODE_VERSION_FILE")
        log_info "Expected node version: $expected_version"
        
        if [[ "$node_version" != "$expected_version" ]]; then
            log_warn "Node version mismatch!"
            log_warn "Running: $node_version"
            log_warn "Expected: $expected_version"
            echo ""
            log_error "The indexer requires node version $expected_version"
            log_info "Please upgrade your Midnight node to version $expected_version"
            log_info "Then run: ./manage-indexer.sh check-version"
            return 1
        else
            log_info "Node version matches: ${GREEN}OK${NC}"
        fi
    else
        log_warn "NODE_VERSION file not found at: $MI_NODE_VERSION_FILE"
        log_info "Current node version: $node_version"
    fi
}

generate_metadata() {
    print_header "Generating Metadata from Running Node"
    
    if [[ -z "$MI_PROJECT_ROOT" ]]; then
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "CANNOT GENERATE METADATA: MI_PROJECT_ROOT is not set"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "Metadata needs to be saved to the project directory."
        log_info "Set MI_PROJECT_ROOT to the midnight-indexer repository path."
        return 1
    fi
    
    # Check if subxt-cli is installed
    if ! command -v subxt > /dev/null 2>&1; then
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "MISSING DEPENDENCY: subxt-cli is not installed"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        log_info "subxt-cli is required to download metadata from the node."
        log_info "The version must match the subxt version in the indexer's Cargo.toml."
        echo ""
        log_info "Install with:"
        log_info "  cargo install subxt-cli"
        echo ""
        log_info "Check the Cargo.toml for the exact version if this fails."
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
    
    # Get node version
    local node_version
    node_version=$(get_node_version) || return 1
    log_info "Node version: $node_version"
    
    # Create directory for metadata
    local metadata_dir="$MI_PROJECT_ROOT/.node/$node_version"
    mkdir -p "$metadata_dir"
    
    # Download metadata
    log_info "Downloading metadata from: $MI_NODE_URL"
    subxt metadata --url "$MI_NODE_URL" -o "$metadata_dir/metadata.scale" || {
        log_error "Failed to download metadata"
        return 1
    }
    
    log_info "Metadata saved to: $metadata_dir/metadata.scale"
    
    # Update NODE_VERSION file
    echo "$node_version" > "$MI_NODE_VERSION_FILE"
    log_info "Updated NODE_VERSION file: $MI_NODE_VERSION_FILE"
    
    log_info "Metadata generated successfully!"
    
    # Automatically rebuild the indexer with new metadata
    echo ""
    log_info "Rebuilding indexer with new metadata..."
    build_binary
}

################################################################################
# Build Functions
################################################################################

build_binary() {
    print_header "Building Midnight Indexer"
    
    if [[ -z "$MI_PROJECT_ROOT" ]]; then
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "CANNOT BUILD: MI_PROJECT_ROOT is not set"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        log_info "The script cannot find the midnight-indexer repository."
        log_info "This script should be placed inside the midnight-indexer project directory,"
        log_info "or you need to specify the project root explicitly."
        echo ""
        log_info "Solutions:"
        log_info "  1. Copy this script to the midnight-indexer repository:"
        log_info "     cp manage-indexer.sh /path/to/midnight-indexer/"
        log_info "     cd /path/to/midnight-indexer && ./manage-indexer.sh build"
        echo ""
        log_info "  2. Set MI_PROJECT_ROOT environment variable:"
        log_info "     MI_PROJECT_ROOT=/path/to/midnight-indexer ./manage-indexer.sh build"
        echo ""
        log_info "  3. Or use --project-root option:"
        log_info "     ./manage-indexer.sh --project-root /path/to/midnight-indexer build"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
    
    if [[ ! -d "$MI_PROJECT_ROOT" ]]; then
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "MI_PROJECT_ROOT DIRECTORY NOT FOUND: $MI_PROJECT_ROOT"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "The specified project root directory does not exist."
        log_info "Please verify the path and try again."
        return 1
    fi
    
    log_info "Build profile: $MI_CARGO_PROFILE"
    log_info "Features: ${FEATURES:-standalone}"
    
    pushd "$MI_PROJECT_ROOT" > /dev/null || {
        log_error "Failed to change to project root: $MI_PROJECT_ROOT"
        return 1
    }
    
    local cargo_args=(
        "build"
        "--package" "indexer-standalone"
    )
    
    if [[ "$MI_CARGO_PROFILE" == "release" ]]; then
        cargo_args+=("--release")
    fi
    
    if [[ -n "$MI_FEATURES" ]]; then
        cargo_args+=("--features" "$MI_FEATURES")
    fi
    
    log_info "Running: cargo ${cargo_args[*]}"
    cargo "${cargo_args[@]}"
    local build_result=$?
    
    popd > /dev/null
    
    if [[ $build_result -ne 0 ]]; then
        log_error "Build failed"
        return 1
    fi
    
    log_info "Build completed successfully"
    local binary_path
    binary_path=$(get_binary_path)
    log_info "Binary location: $binary_path"
}

################################################################################
# Database Management Functions
################################################################################

reset_database() {
    print_header "Resetting Indexer Database"
    
    if is_running; then
        log_error "Cannot reset database while indexer is running"
        log_info "Stop the indexer first: ./manage-indexer.sh stop"
        return 1
    fi
    
    if [[ -d "$MI_DATA_DIR" ]]; then
        log_warn "This will DELETE all indexed data!"
        log_warn "Data directory: $MI_DATA_DIR"
        read -rp "Are you sure? (yes/NO): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Cancelled"
            return 0
        fi
        
        rm -rf "$MI_DATA_DIR"
        log_info "Data directory removed: $MI_DATA_DIR"
        log_info "The indexer will re-index from genesis on next start"
    else
        log_info "Data directory does not exist: $MI_DATA_DIR"
    fi
}

show_database_info() {
    print_header "Database Information"
    
    if [[ ! -f "$MI_DB_FILE" ]]; then
        log_warn "Database file does not exist: $MI_DB_FILE"
        return 0
    fi
    
    log_info "Database file: $MI_DB_FILE"
    
    if command -v sqlite3 > /dev/null 2>&1; then
        local size
        size=$(du -h "$MI_DB_FILE" | cut -f1)
        log_info "Database size: $size"
        
        echo ""
        echo "Tables:"
        sqlite3 "$MI_DB_FILE" ".tables"
        
        echo ""
        echo "Row counts:"
        sqlite3 "$MI_DB_FILE" "SELECT 'blocks', COUNT(*) FROM blocks UNION ALL SELECT 'transactions', COUNT(*) FROM transactions;" 2>/dev/null || log_warn "Cannot query database"
    else
        log_warn "sqlite3 command not available for detailed inspection"
        local size
        size=$(du -h "$MI_DB_FILE" | cut -f1)
        log_info "Database size: $size"
    fi
}

################################################################################
# Server Management Functions
################################################################################

start_server() {
    print_header "Starting Midnight Indexer"
    
    if is_running; then
        log_warn "Indexer is already running (PID: $(get_pid))"
        return 0
    fi
    
    # Check node connection first
    if ! check_node; then
        log_error "Cannot start indexer: node is not accessible"
        log_info "Please ensure the Midnight node is running before starting the indexer."
        return 1
    fi
    
    local binary_path
    if ! binary_path=$(get_binary_path 2>&1); then
        # get_binary_path already printed detailed error messages
        echo ""
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "BINARY NOT FOUND: Cannot locate '$MI_BINARY_NAME'"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        log_info "Possible solutions:"
        log_info "  1. Build the indexer first:"
        log_info "     ./manage-indexer.sh build"
        echo ""
        log_info "  2. Or set the binary path explicitly:"
        log_info "     MI_BINARY_PATH=/path/to/$MI_BINARY_NAME ./manage-indexer.sh start"
        echo ""
        log_info "See the Build section in INDEXER_MANAGEMENT_GUIDE.md for details."
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
    
    # Create data directory
    mkdir -p "$MI_DATA_DIR"
    
    log_info "Starting indexer with configuration:"
    log_info "  Node URL: $MI_NODE_URL"
    log_info "  Database: $MI_DB_FILE"
    log_info "  API Port: $MI_API_PORT"
    log_info "  Log Level: $MI_RUST_LOG"
    log_info "  Log File: $MI_LOG_FILE"
    
    # Set up environment variables
    export RUST_LOG="$MI_RUST_LOG"
    export RUST_BACKTRACE="$MI_RUST_BACKTRACE"
    export APP__INFRA__NODE__URL="$MI_NODE_URL"
    export APP__INFRA__STORAGE__CNN_URL="$MI_DB_FILE"
    export APP__INFRA__SECRET="$MI_APP_SECRET"
    export CONFIG_FILE="$MI_CONFIG_FILE"
    
    # Start the indexer in background from project root (if set)
    log_info "Launching: $binary_path"
    if [[ -n "$MI_PROJECT_ROOT" ]]; then
        pushd "$MI_PROJECT_ROOT" > /dev/null || {
            log_error "Failed to change to project root: $MI_PROJECT_ROOT"
            return 1
        }
        nohup "$binary_path" > "$MI_LOG_FILE" 2>&1 &
        local pid=$!
        popd > /dev/null
    else
        nohup "$binary_path" > "$MI_LOG_FILE" 2>&1 &
        local pid=$!
    fi
    echo "$pid" > "$MI_PID_FILE"
    
    # Wait a moment and check if it's still running
    sleep 3
    if ps -p "$pid" > /dev/null 2>&1; then
        log_info "Indexer started successfully (PID: $pid)"
        log_info "GraphQL API will be available at: http://localhost:$MI_API_PORT"
        log_info "Logs: tail -f $MI_LOG_FILE"
        
        # Show initial log output
        echo ""
        log_info "Initial output:"
        tail -n 10 "$MI_LOG_FILE"
    else
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "INDEXER FAILED TO START: Process exited immediately"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        if [[ -f "$MI_LOG_FILE" ]]; then
            log_info "Last 20 lines of the log:"
            echo "----------------------------------------"
            tail -20 "$MI_LOG_FILE" 2>/dev/null || echo "  (unable to read log)"
            echo "----------------------------------------"
        fi
        echo ""
        log_info "Common issues:"
        log_info "  - Node metadata mismatch: Run './manage-indexer.sh generate-metadata'"
        log_info "  - Port $MI_API_PORT already in use: Check with 'lsof -i :$MI_API_PORT'"
        log_info "  - Database corruption: Try './manage-indexer.sh reset-db'"
        log_info "  - Missing config: Check if config file exists at $MI_CONFIG_FILE"
        log_info "  - Node not running: Verify node at $MI_NODE_URL"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        rm -f "$MI_PID_FILE"
        return 1
    fi
}

stop_server() {
    print_header "Stopping Midnight Indexer"
    
    if ! is_running; then
        log_warn "Indexer is not running"
        return 0
    fi
    
    local pid
    pid=$(get_pid)
    log_info "Stopping indexer (PID: $pid)"
    
    # Send SIGTERM
    kill -TERM "$pid" 2>/dev/null || true
    
    # Wait for graceful shutdown
    local timeout=30
    local count=0
    while ps -p "$pid" > /dev/null 2>&1 && [[ $count -lt $timeout ]]; do
        sleep 1
        ((count++))
    done
    
    # Force kill if still running
    if ps -p "$pid" > /dev/null 2>&1; then
        log_warn "Graceful shutdown failed, forcing kill"
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
    fi
    
    rm -f "$MI_PID_FILE"
    log_info "Indexer stopped successfully"
}

restart_server() {
    print_header "Restarting Midnight Indexer"
    stop_server
    sleep 2
    start_server
}

status_server() {
    print_header "Midnight Indexer Status"
    
    if is_running; then
        local pid
        pid=$(get_pid)
        log_info "Status: ${GREEN}RUNNING${NC}"
        log_info "PID: $pid"
        
        # Get process info
        echo ""
        echo "Process Information:"
        ps -p "$pid" -o pid,ppid,user,%cpu,%mem,vsz,rss,etime,command | tail -n +2
        
        # Show recent logs
        echo ""
        log_info "Recent logs:"
        if [[ -f "$MI_LOG_FILE" ]]; then
            tail -n 5 "$MI_LOG_FILE"
        fi
        
        # Check API
        echo ""
        check_api
    else
        log_error "Status: ${RED}NOT RUNNING${NC}"
        return 1
    fi
}

################################################################################
# API Functions
################################################################################

check_api() {
    log_info "Checking GraphQL API at http://localhost:$MI_API_PORT..."
    
    if ! command -v curl > /dev/null 2>&1; then
        log_warn "curl not available, skipping API check"
        return 0
    fi
    
    local api_url="http://localhost:$MI_API_PORT/api/v3/graphql"
    
    # Try a simple query
    local response
    response=$(curl -s --connect-timeout 5 -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -d '{"query": "{ block { height } }"}' 2>/dev/null) || {
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "API NOT RESPONDING at $api_url"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "Possible causes:"
        log_info "  - Indexer is not running: ./manage-indexer.sh status"
        log_info "  - Indexer is still starting up (wait a few seconds)"
        log_info "  - Different port: Check MI_API_PORT setting"
        log_info "  - Firewall blocking port $MI_API_PORT"
        return 1
    }
    
    if echo "$response" | jq -e '.data' > /dev/null 2>&1; then
        local height
        height=$(echo "$response" | jq -r '.data.block.height' 2>/dev/null)
        log_info "API Status: ${GREEN}OK${NC}"
        log_info "Current block height: $height"
    else
        log_error "API Status: ${RED}ERROR${NC}"
        log_info "URL: $api_url"
        log_info "Response: $response"
        log_info ""
        log_info "The API responded but with an error. Check the indexer logs:"
        log_info "  tail -50 $MI_LOG_FILE"
        return 1
    fi
}

test_api() {
    print_header "Testing GraphQL API"
    
    if ! is_running; then
        log_error "Indexer is not running"
        return 1
    fi
    
    if ! command -v curl > /dev/null 2>&1 || ! command -v jq > /dev/null 2>&1; then
        log_error "curl and jq are required for API testing"
        return 1
    fi
    
    local api_url="http://localhost:$MI_API_PORT/api/v3/graphql"
    
    echo "Testing: Get latest block"
    curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -d '{"query": "{ block { hash height protocolVersion timestamp } }"}' | jq
    
    echo ""
    echo "Testing: Get genesis block"
    curl -s -X POST "$api_url" \
        -H "Content-Type: application/json" \
        -d '{"query": "{ block(offset: {height: 0}) { hash height transactions { hash } } }"}' | jq
    
    echo ""
    log_info "API tests completed"
}

################################################################################
# Monitoring Functions
################################################################################

monitor_server() {
    print_header "Monitoring Midnight Indexer"
    log_info "Press Ctrl+C to stop monitoring"
    log_info "Health check interval: ${MI_HEALTH_CHECK_INTERVAL}s"
    
    local failures=0
    
    while true; do
        if ! is_running; then
            log_error "Indexer is not running!"
            ((failures++))
            
            if [[ $failures -ge $MI_MAX_RESTART_ATTEMPTS ]]; then
                log_error "Maximum restart attempts reached ($MI_MAX_RESTART_ATTEMPTS)"
                return 1
            fi
            
            log_warn "Attempting to restart indexer (attempt $failures/$MI_MAX_RESTART_ATTEMPTS)"
            sleep "$MI_RESTART_DELAY"
            start_server || continue
            failures=0
        else
            if check_api > /dev/null 2>&1; then
                log_info "$(date '+%Y-%m-%d %H:%M:%S') - Indexer is healthy (PID: $(get_pid))"
                failures=0
            else
                log_warn "$(date '+%Y-%m-%d %H:%M:%S') - Health check failed"
                ((failures++))
                
                if [[ $failures -ge 3 ]]; then
                    log_error "Multiple consecutive health check failures, restarting indexer"
                    restart_server
                    failures=0
                fi
            fi
        fi
        
        sleep "$MI_HEALTH_CHECK_INTERVAL"
    done
}

watch_logs() {
    print_header "Watching Midnight Indexer Logs"
    
    if [[ ! -f "$MI_LOG_FILE" ]]; then
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "LOG FILE NOT FOUND: $MI_LOG_FILE"
        log_error "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_info "The indexer may not have been started yet, or it was started"
        log_info "in a different session with a different log file location."
        echo ""
        log_info "To start the indexer: ./manage-indexer.sh start"
        log_info "To check status:      ./manage-indexer.sh status"
        return 1
    fi
    
    tail -f "$MI_LOG_FILE"
}

show_metrics() {
    print_header "Midnight Indexer Metrics"
    
    if ! is_running; then
        log_error "Indexer is not running"
        return 1
    fi
    
    local pid
    pid=$(get_pid)
    
    echo "System Resources:"
    ps -p "$pid" -o pid,ppid,user,%cpu,%mem,vsz,rss,etime,command | head -2
    
    echo ""
    echo "Database Information:"
    show_database_info
    
    echo ""
    echo "API Status:"
    check_api
    
    echo ""
    echo "Open Files:"
    lsof -p "$pid" 2>/dev/null | wc -l || echo "N/A (requires lsof)"
    
    echo ""
    echo "Network Connections:"
    ss -tnp 2>/dev/null | grep "$pid" || netstat -tnp 2>/dev/null | grep "$pid" || echo "N/A"
}

################################################################################
# Help and Usage
################################################################################

show_usage() {
    cat <<EOF
Midnight Indexer Management Script

Usage: $0 [COMMAND] [OPTIONS]

COMMANDS:
  Node Management:
    check-node         Check connection to Midnight node
    check-version      Check node version compatibility
    generate-metadata  Generate metadata from running node

  Build:
    build              Build the indexer binary

  Server Management:
    start              Start the indexer
    stop               Stop the indexer
    restart            Restart the indexer
    status             Show indexer status
    monitor            Monitor indexer with auto-restart
    logs               Watch indexer logs
    metrics            Show indexer metrics

  Database:
    reset-db           Reset the database (delete and re-index)
    db-info            Show database information

  API:
    check-api          Check GraphQL API status
    test-api           Test API with sample queries

  Other:
    help               Show this help message

OPTIONS:
  Binary Configuration:
    --binary-path PATH          Direct path to indexer binary
    --project-root PATH         Project root directory (for building)

  Node Configuration:
    --node-url URL              Substrate node WebSocket URL
                                (default: ws://127.0.0.1:9944)

  Database Configuration:
    --data-dir DIR              Data directory for database
                                (default: target/data)
    --db-file PATH              SQLite database file path

  API Configuration:
    --api-port PORT             GraphQL API port (default: 8088)

  Build Configuration:
    --profile PROFILE           Set cargo build profile (default: release)
    --features FEATURES         Set cargo features (default: standalone)

  Other:
    --log-level LEVEL           Set RUST_LOG level (default: info)
    --verbose                   Enable verbose logging

ENVIRONMENT VARIABLES:
  Binary/Project:
    BINARY_PATH                 Direct path to indexer binary
    MI_PROJECT_ROOT                Project root directory

  Node:
    APP__INFRA__NODE__URL       Node WebSocket URL

  Database:
    DATA_DIR                    Data directory
    APP__INFRA__STORAGE__CNN_URL  Database file path

  API:
    API_PORT                    GraphQL API port

  Security:
    APP__INFRA__SECRET          32-byte hex secret for encryption

EXAMPLES:
  # Check node connection
  $0 check-node

  # Build the indexer
  $0 build

  # Start indexer with custom node URL
  $0 --node-url ws://192.168.1.100:9944 start

  # Reset database and restart
  $0 stop
  $0 reset-db
  $0 start

  # Monitor indexer with auto-restart
  $0 monitor

  # Test the GraphQL API
  $0 test-api

  # Generate metadata from running node
  $0 generate-metadata
  $0 build

TROUBLESHOOTING:
  - Node version mismatch: Run 'generate-metadata' then 'build'
  - Connection refused: Ensure node is running on ws://127.0.0.1:9944
  - Unexpected block errors: Run 'reset-db' to clear database
  - Check logs with: tail -f $MI_LOG_FILE

EOF
}

################################################################################
# Main Function
################################################################################

main() {
    # Parse command line options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --binary-path)
                BINARY_PATH="$2"
                shift 2
                ;;
            --project-root)
                MI_PROJECT_ROOT="$2"
                shift 2
                ;;
            --node-url)
                NODE_URL="$2"
                shift 2
                ;;
            --data-dir)
                DATA_DIR="$2"
                DB_FILE="$MI_DATA_DIR/indexer.sqlite"
                shift 2
                ;;
            --db-file)
                DB_FILE="$2"
                shift 2
                ;;
            --api-port)
                API_PORT="$2"
                shift 2
                ;;
            --profile)
                CARGO_PROFILE="$2"
                shift 2
                ;;
            --features)
                FEATURES="$2"
                shift 2
                ;;
            --log-level)
                RUST_LOG="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            build|start|stop|restart|status|monitor|logs|metrics|check-node|check-version|generate-metadata|reset-db|db-info|check-api|test-api|help)
                COMMAND="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Execute command
    case "${COMMAND:-}" in
        # Node management
        check-node)
            check_node
            ;;
        check-version)
            check_node_version
            ;;
        generate-metadata)
            generate_metadata
            ;;
        # Build
        build)
            build_binary
            ;;
        # Server management
        start)
            start_server
            ;;
        stop)
            stop_server
            ;;
        restart)
            restart_server
            ;;
        status)
            status_server
            ;;
        monitor)
            monitor_server
            ;;
        logs)
            watch_logs
            ;;
        metrics)
            show_metrics
            ;;
        # Database
        reset-db)
            reset_database
            ;;
        db-info)
            show_database_info
            ;;
        # API
        check-api)
            check_api
            ;;
        test-api)
            test_api
            ;;
        # Help
        help|"")
            show_usage
            ;;
        *)
            log_error "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
