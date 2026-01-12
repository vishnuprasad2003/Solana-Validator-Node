# Essential Programs Setup for Production Cluster

This document describes how essential SPL and Metaplex programs are included in the private Solana cluster.

## Included Programs

The following programs are automatically included during genesis creation:

1. **SPL Token Program** (`TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA`)
   - Standard token operations (create, mint, transfer, burn)
   - Required for `spl-token` CLI and token operations

2. **SPL Token-2022 Program** (`TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb`)
   - Enhanced token program with additional features
   - Transfer hooks, transfer fees, confidential transfers

3. **Associated Token Account Program** (`ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL`)
   - Creates associated token accounts (PDA-based)
   - Required for token operations

4. **Metaplex Token Metadata Program** (`metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s`)
   - NFT metadata and standards
   - Required for NFT creation and management

## How It Works

### Automatic Setup (Recommended)

When you run `make init-genesis`, the script will:

1. **Download Programs**: Automatically downloads all programs from mainnet
2. **Include in Genesis**: Adds programs to genesis using `--upgradeable-program` flag
3. **Set Upgrade Authority**: Uses faucet account as upgrade authority

### Manual Setup

If programs are not included in genesis, they can be deployed after bootstrap starts:

```bash
# After bootstrap is running
make deploy-programs
```

Or manually:

```bash
# Setup programs (downloads from mainnet)
make setup-programs

# Deploy to cluster
make deploy-programs
```

## Usage

Once programs are deployed, you can use standard Solana tools:

```bash
# Create a token
spl-token create-token

# Create token account
spl-token create-account <MINT_ADDRESS>

# Mint tokens
spl-token mint <MINT_ADDRESS> 1000

# Transfer tokens
spl-token transfer <MINT_ADDRESS> 100 <RECIPIENT>

# Approve delegate
spl-token approve <MINT_ADDRESS> 50 <DELEGATE>
```

## Verification

Check if programs are deployed:

```bash
# Check Token program
solana program show TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA --url http://localhost:8899

# Via curl
curl http://localhost:8899 -X POST -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getAccountInfo","params":["TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",{"encoding":"base64"}]}'
```

## Program Files

Programs are stored in `programs/` directory:

- `spl_token.so` - SPL Token program
- `spl_token_2022.so` - Token-2022 program
- `spl_associated_token_account.so` - Associated Token Account program
- `mpl_token_metadata.so` - Metaplex Token Metadata program

## Troubleshooting

### Programs not found

If you get "Program not found" errors:

1. **Check if programs are in genesis**:
   ```bash
   solana program show TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA --url http://localhost:8899
   ```

2. **If not, deploy them**:
   ```bash
   make deploy-programs
   ```

3. **If deployment fails**, ensure:
   - Bootstrap validator is running
   - Faucet has sufficient balance
   - Programs directory exists with program files

### Programs not in genesis

If programs weren't included during genesis creation:

1. **Recreate genesis** (will lose existing data):
   ```bash
   make stop
   rm -rf data/bootstrap/*
   make init-genesis
   make start-cluster
   ```

2. **Or deploy after bootstrap starts**:
   ```bash
   make start-bootstrap
   # Wait for bootstrap to be ready
   make deploy-programs
   ```

## Production Notes

- **Upgrade Authority**: Programs are deployed with faucet as upgrade authority
- **Program IDs**: Uses standard mainnet program IDs for compatibility
- **Download Source**: Programs are downloaded from mainnet for authenticity
- **Genesis Inclusion**: Programs are included in genesis for faster startup

## Additional Programs

To add more programs:

1. Download program:
   ```bash
   solana program dump <PROGRAM_ID> programs/<name>.so --url https://api.mainnet-beta.solana.com
   ```

2. Add to `init-genesis.sh`:
   ```bash
   GENESIS_ARGS+=(--upgradeable-program "<PROGRAM_ID>" "$BPF_LOADER" "${PROGRAMS_DIR}/<name>.so" "$UPGRADE_AUTHORITY")
   ```

3. Or deploy after cluster starts:
   ```bash
   solana program deploy programs/<name>.so --program-id <PROGRAM_ID> --keypair keys/identity/faucet.json --url http://localhost:8899
   ```
