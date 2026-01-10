# Wallet Funding & DUST Registration Guide

This guide explains how to fund wallets and register for DUST generation on a Midnight development network.

## Prerequisites

- Midnight node built and running (see [Node Operator Guide](../midnight-dev-node-operator/NODE_OPERATOR_GUIDE.md))
- `midnight-node-toolkit` binary built from the midnight-node repository
- Node accessible at `ws://127.0.0.1:9944`

## Quick Start: Running a Dev Node

**Using the node operator script** (recommended):
```bash
# From midnight-infra-dev-tools repository
./midnight-operator.sh start --node alice

# Check status
./midnight-operator.sh status

# View logs
./midnight-operator.sh logs alice
```

**Manual method**:
```bash
cd midnight-node
CFG_PRESET=dev ./target/release/midnight-node --dev --name alice --base-path /tmp/midnight-dev
```

**Verify the node is running:**
```bash
# Using the operator script (recommended)
./midnight-operator.sh status

# Or manually using curl (optional)
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"system_health","params":[],"id":1}' \
  http://127.0.0.1:9944
```

**RPC Endpoint:** `ws://127.0.0.1:9944`


# Midnight Wallet Funding & DUST Registration Guide

This guide explains how to fund a new wallet and register for DUST generation using the pre-funded Alice wallet (`..01`) on a local development node.

## Prerequisites

- Midnight node running in dev mode.
- `midnight-node-toolkit` binary available at `target/release/midnight-node-toolkit`
- Node accessible at `ws://127.0.0.1:9944`

## Key Concepts

| Concept | Description |
|---------|-------------|
| **NIGHT** | The native token on Midnight |
| **DUST** | Gas token required to pay transaction fees |
| **Shielded Coins** | Private tokens (ZK-protected) |
| **Unshielded UTXOs** | Public tokens (transparent) |
| **DUST Registration** | Links your NIGHT holdings to generate DUST |
| **DUST Delegation** | Using another wallet's DUST to pay your fees |

## Pre-funded Dev Wallets

| Wallet | Seed | Purpose |
|--------|------|---------|
| **Alice (Funding)** | `..01` | Pre-funded with NIGHT and DUST in genesis |
| **Dev Wallet** | `..00` | Additional dev wallet |

> **Note:** `..01` is lazy hex notation for `0000000000000000000000000000000000000000000000000000000000000001`

---

## Step-by-Step: Fund a New Wallet

### Step 1: Get Your Wallet Addresses

First, get the addresses for your new wallet:

```bash
./target/release/midnight-node-toolkit show-address \
    --network undeployed \
    --seed "YOUR_WALLET_SEED_OR_MNEMONIC"
```

This outputs:
- `shielded` - Your private address (for receiving shielded tokens)
- `unshielded` - Your public address (for receiving unshielded tokens)
- `dust` - Your DUST address

**Example with mnemonic:**
```bash
./target/release/midnight-node-toolkit show-address \
    --network undeployed \
    --seed "word1 word2 word3..."
```
---

## Token Units Reference

| Unit | Value | Description |
|------|-------|-------------|
| 1 NIGHT | 1,000,000,000,000 tNIGHT | 10^12 base units |
| 100 NIGHT | 100,000,000,000,000 tNIGHT | Our funding amount |

---

### Step 2: Send Unshielded NIGHT Tokens

Send **unshielded** NIGHT from Alice to your wallet. This is required for DUST registration.

```bash
./target/release/midnight-node-toolkit generate-txs single-tx \
    --source-seed "..01" \
    --destination-address "YOUR_UNSHIELDED_ADDRESS" \
    --unshielded-amount 100000000000000
```

**Parameters:**
- `--source-seed "..01"` - Alice's wallet (the funder)
- `--destination-address` - Your `unshielded` address from Step 1
- `--unshielded-amount` - Amount in tNIGHT (100000000000000 = 100 NIGHT)

**Example:**
```bash
./target/release/midnight-node-toolkit generate-txs single-tx \
    --source-seed "..01" \
    --destination-address "mn_addr_undeployed1en2rn2grc8aqeap5rqvasghre0266qew3lj0h7u46qfys8jcn0hs4q0qq9" \
    --unshielded-amount 100000000000000
```

---

### Step 3: Register for DUST (with Fee Delegation)

Register your DUST address using Alice's wallet to pay the DUST fees:

```bash
./target/release/midnight-node-toolkit generate-txs register-dust-address \
    --wallet-seed "YOUR_WALLET_SEED" \
    --funding-seed "..01"
```

**Parameters:**
- `--wallet-seed` - Your wallet seed (the wallet being registered)
- `--funding-seed "..01"` - Alice pays the DUST transaction fees

> **Key Insight:** The `--funding-seed` parameter enables **DUST fee delegation**. Alice's DUST pays for your registration transaction.

**Example:**
```bash
./target/release/midnight-node-toolkit generate-txs register-dust-address \
    --wallet-seed "word1 word2 word3 ..." \
    --funding-seed "..01"
```

---

### Step 4: Verify Your Wallet

Check your wallet balance:

```bash
./target/release/midnight-node-toolkit show-wallet \
    --seed "YOUR_WALLET_SEED"
```

You should see:
- `coins` - Shielded tokens (if any)
- `utxos` - Unshielded tokens
- `dust_utxos` - Your DUST registration entries

---

### Step 5: Check DUST Balance

Verify DUST is being generated:

```bash
./target/release/midnight-node-toolkit dust-balance \
    --seed "YOUR_WALLET_SEED"
```

You should see:
- `generation_infos` - Your DUST generation entries
- `source` - DUST sources
- `total` - Total DUST available

---

## Optional: Send Shielded Tokens

To send private (shielded) tokens:

```bash
./target/release/midnight-node-toolkit generate-txs single-tx \
    --source-seed "..01" \
    --destination-address "YOUR_SHIELDED_ADDRESS" \
    --shielded-amount 100000000000000
```

**Example:**
```bash
./target/release/midnight-node-toolkit generate-txs single-tx \
    --source-seed "..01" \
    --destination-address "mn_shield-addr_undeployed1rejryyjpye2gd5xskh8z8g5mps536q5x65mtmknn0cw4jwavac7ta0ren8skwqxz52gzumnt0s9rpda6p3y53psvgxz9vwa5myhvghcrkrx3q" \
    --shielded-amount 100000000000000
```

---

## Summary

1. **Get addresses** with `show-address`
2. **Send unshielded NIGHT** with `single-tx --unshielded-amount`
3. **Register for DUST** with `register-dust-address --funding-seed "..01"`
4. **Verify** with `show-wallet` and `dust-balance`

