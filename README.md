# Solana Validator Node

Production-ready setup for deploying a private Solana validator node with RPC access.

## Quick Start

```bash
# 1. Install dependencies
./install.sh
source ~/.bashrc

# 2. Setup validator
./setup-validator.sh

# 3. Configure for public access (optional)
./configure-rpc-public.sh

# 4. Start validator
./start-validator-tmux.sh

# 5. Verify
./verify-setup.sh
```

## Configuration

### RPC Access

**Public Access (Network):**
```bash
./configure-rpc-public.sh
# RPC accessible at: http://<your-ip>:8899
```

**Local Only:**
```bash
./configure-rpc-local.sh
# RPC accessible at: http://127.0.0.1:8899
```

### Firewall Setup

```bash
sudo scripts/firewall-setup.sh
```

## Management

**Start/Stop:**
```bash
./start-validator-tmux.sh    # Start in tmux
./stop-validator.sh          # Stop validator
```

**Production (systemd):**
```bash
sudo systemd/install-service.sh
sudo systemctl start solana-validator
sudo systemctl enable solana-validator
```

**Maintenance:**
```bash
scripts/maintenance.sh       # Interactive menu
scripts/monitor.sh           # Continuous monitoring
scripts/reset-validator.sh   # Clear ledger data
```

## Testing RPC

**⚠️ Postman Web Limitation:** Postman Web cannot access private IPs (192.168.x.x). Use Postman Desktop, browser console, or curl instead.

**Command Line (Recommended):**
```bash
curl -X POST http://192.168.29.170:8899 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
```

**Browser Console (F12):**
```javascript
fetch('http://192.168.29.170:8899', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({jsonrpc:'2.0', id:1, method:'getHealth'})
}).then(r=>r.json()).then(console.log);
```

**Postman Desktop:** Download from postman.com - can access private IPs

**For Public Access:** Deploy on Azure VM and use the VM's public IP

## Azure VM Deployment

**Quick Setup:**
```bash
git clone <repo-url>
cd Solana-Validator-Node
chmod +x *.sh scripts/*.sh
./azure-setup.sh          # Auto-configures for Azure
./install.sh
./setup-validator.sh
./start-validator-tmux.sh
```

**Before starting:**
1. Create Azure VM with Ubuntu 22.04 LTS
2. Configure NSG - Add inbound rule for port 8899 (TCP)
3. Get VM's public IP from Azure Portal

**See `AZURE_DEPLOYMENT.md` for complete guide**

## Project Structure

```
Solana-Validator-Node/
├── install.sh              # Install dependencies
├── setup-validator.sh       # Initial setup
├── start-validator.sh        # Start validator (generated)
├── start-validator-tmux.sh  # Start in tmux
├── stop-validator.sh        # Stop validator
├── configure-rpc-public.sh  # Enable public RPC
├── configure-rpc-local.sh   # Local-only RPC
├── azure-setup.sh           # Azure VM quick setup
├── verify-setup.sh          # Verify installation
├── config.env               # Configuration
├── scripts/                 # Utility scripts
│   ├── maintenance.sh       # Maintenance menu
│   ├── monitor.sh           # Monitoring
│   ├── upgrade-solana.sh    # Upgrade Solana
│   ├── reset-validator.sh  # Reset ledger
│   ├── firewall-setup.sh    # Firewall config
│   ├── security-setup.sh   # Security config
│   └── download-metaplex-program.sh  # Download Metaplex
└── systemd/                 # Systemd service
```

## Troubleshooting

**Validator won't start:**
- Check logs: `tmux attach -t solana-validator`
- Verify port: `sudo lsof -i :8899`
- Check config: `grep RPC_BIND_ADDRESS config.env`

**RPC not accessible:**
- Wait 30+ seconds after start
- Check firewall: `sudo ufw status`
- Verify bind address: Use `./configure-rpc-public.sh`
- **Public IP timeout?** Configure router port forwarding (see PORT_FORWARDING.md)

**Connection refused:**
- Ensure validator is running: `pgrep -f solana-test-validator`
- Check firewall rules
- Verify Azure NSG allows port 8899

## Common RPC Methods

```bash
# Health check
curl -X POST http://<ip>:8899 -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'

# Get version
curl -X POST http://<ip>:8899 -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getVersion"}'

# Get slot
curl -X POST http://<ip>:8899 -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}'
```

## Security Notes

⚠️ **Public RPC Access:**
- Consider IP whitelisting: `scripts/security-setup.sh`
- Use VPN for remote access
- Monitor access logs regularly
- Keep system updated

## Requirements

- Ubuntu 22.04 LTS (or compatible)
- 4GB+ RAM
- 20GB+ disk space
- sudo/root access

## License

MIT License
