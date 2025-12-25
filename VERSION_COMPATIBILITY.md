# Solana Version Compatibility Guide

This document specifies the Solana CLI version, Anchor framework version, and program compatibility for each Solana version. Update this document when upgrading Solana.

## Current Version: 3.0.13

### Solana CLI Version

**Current Version**: `1.18.26` (stable)

**Installation**: Solana CLI is installed via the official installer which uses the latest stable version.

### Anchor Framework Version

**Current Version**: `0.32.1` (via Anchor Version Manager - AVM)

**Installation**: Anchor is installed via AVM (Anchor Version Manager) which manages multiple Anchor versions. Use `avm install latest && avm use latest` to get the latest version.

**Installation**: Anchor is installed via AVM (Anchor Version Manager) which manages multiple Anchor versions.

### Program Compatibility

**Token Program**: 
- Standard Token Program: `TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA`
- Token-2022 Program: `TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb`

**Metaplex Token Metadata Program**:
- Program ID: `metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s`
- Version: Compatible with Solana 1.18.x

**Anchor Framework**:
- Latest version via AVM
- Compatible with Solana 1.18.x

### Development Tools

**Rust Version**: `1.70.0` or higher

**Required System Packages**:
- `build-essential`
- `pkg-config`
- `libudev-dev`
- `libssl-dev`

### Configuration in Development

1. **Solana CLI**:
   - Version: Check with `solana --version`
   - Update: `sh -c "$(curl -sSfL https://release.solana.com/stable/install)"`

2. **Anchor Framework**:
   - Install: `cargo install --git https://github.com/coral-xyz/anchor avm --locked --force`
   - Use: `avm install latest && avm use latest`

3. **Program Deployment**:
   - Use Anchor for program development
   - Deploy with `anchor deploy`
   - Or use `solana program deploy` for BPF programs

## Version History

| Solana Version | Anchor Version | Token Program | Metaplex | Notes |
|----------------|----------------|---------------|----------|-------|
| 3.0.13 | latest (AVM) | Token + Token-2022 | Compatible | Current version |
| 3.0.13 | latest (AVM) | Token + Token-2022 | Compatible | Current version |
| 1.18.26 | latest (AVM) | Token + Token-2022 | Compatible | Previous version |
| 1.17.x | latest (AVM) | Token + Token-2022 | Compatible | Previous stable |
| 1.16.x | latest (AVM) | Token + Token-2022 | Compatible | Previous stable |

## Upgrade Notes

When upgrading Solana:

1. **Check Solana Version**: Verify which Solana version you're upgrading to
2. **Update Anchor**: Ensure Anchor version is compatible (usually latest via AVM)
3. **Test Programs**: Recompile and test all programs with new Solana version
4. **Update Metaplex**: Check if Metaplex program needs updating
5. **Update Dependencies**: Update `@solana/web3.js` and other npm packages if needed

## Testing Compatibility

After upgrading, verify compatibility:

```bash
# 1. Check Solana version
solana --version

# 2. Check Anchor version
anchor --version

# 3. Test program compilation
anchor build

# 4. Test program deployment
anchor deploy

# 5. Test API interactions
# Use Solana Interactor API to test FT/NFT operations
```

## References

- [Solana Releases](https://github.com/solana-labs/solana/releases)
- [Anchor Documentation](https://www.anchor-lang.com/)
- [Solana Web3.js](https://solana-labs.github.io/solana-web3.js/)
- [Metaplex Documentation](https://docs.metaplex.com/)

