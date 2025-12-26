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
./start-validator.sh
# OR for production: sudo systemd/install-service.sh && sudo systemctl start solana-validator

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
./start-validator.sh         # Start validator
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
# Stop validator to clear ledger
./stop-validator.sh
rm -rf ~/solana-local-ledger
./start-validator.sh
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

**For Public Access:** 
- **Azure VM** (recommended): Deploy on Azure VM and use the VM's public IP
- **ngrok** (quick testing): `ngrok http 8899` (temporary URL)
- **Router Port Forwarding**: Forward port 8899 to your private IP

## Azure VM Deployment

### Step-by-Step Guide

**1. Create Azure VM:**
- Ubuntu 22.04 LTS
- Size: Standard_B2s (2 vCPU, 4GB RAM) minimum
- **Important**: Assign a public IP address
- Note your VM's public IP (from Azure Portal → VM → Overview)

**2. Configure Network Security Group (NSG):**
- Go to Azure Portal → Your VM → **Networking**
- Click **Add inbound rule**
- Configure:
  - Name: `solana-rpc`
  - Priority: `1000`
  - Port: `8899`
  - Protocol: `TCP`
  - Action: `Allow`
- Click **Add**

**3. Connect to Azure VM:**
```bash
ssh azureuser@<your-azure-public-ip>
```

**4. Deploy Validator:**
```bash
# Clone repository
git clone <repo-url>
cd Solana-Validator-Node

# Make scripts executable
chmod +x *.sh scripts/*.sh systemd/*.sh

# Run Azure setup (auto-detects IPs and configures everything)
./azure-setup.sh

# Install dependencies
./install.sh
source ~/.bashrc

# Setup validator
./setup-validator.sh

# Install as systemd service (production)
sudo systemd/install-service.sh
sudo systemctl start solana-validator
sudo systemctl enable solana-validator
```

**5. Verify:**
```bash
./verify-setup.sh
```

### RPC URLs to Use

**After deployment, use these URLs:**

| Access From | RPC URL | Example |
|------------|---------|---------|
| **Azure VM itself** | `http://127.0.0.1:8899` | `http://127.0.0.1:8899` |
| **Internet (reqbin.com, Postman Web)** | `http://<azure-public-ip>:8899` | `http://20.123.45.67:8899` ← **Use this!** |
| **Azure network** | `http://<azure-private-ip>:8899` | `http://10.0.0.5:8899` |

**To find your Azure public IP:**
- Azure Portal: VM → Overview → Public IP address
- Or run on VM: `curl -s https://api.ipify.org`

**Example:**
If your Azure VM public IP is `20.123.45.67`, use:
```
http://20.123.45.67:8899
```

**Test from reqbin.com:**
- URL: `http://20.123.45.67:8899`
- Method: `POST`
- Headers: `Content-Type: application/json`
- Body: `{"jsonrpc":"2.0","id":1,"method":"getHealth"}`

## Project Structure

```
Solana-Validator-Node/
├── README.md               # Documentation
├── config.env              # Configuration file
├── install.sh              # Install dependencies
├── setup-validator.sh      # Initial setup
├── start-validator.sh     # Start validator
├── stop-validator.sh      # Stop validator
├── configure-rpc-public.sh # Enable public RPC
├── configure-rpc-local.sh  # Local-only RPC
├── azure-setup.sh         # Azure VM quick setup
├── verify-setup.sh        # Verify installation
├── scripts/               # Utility scripts
│   ├── firewall-setup.sh  # Firewall config
│   └── download-metaplex-program.sh  # Download Metaplex
└── systemd/               # Systemd service
    ├── install-service.sh  # Install systemd service
    └── solana-validator.service
```

## Troubleshooting

**Validator won't start:**
- Check if already running: `pgrep -f solana-test-validator`
- Verify port: `sudo lsof -i :8899`
- Check config: `grep RPC_BIND_ADDRESS config.env`
- Check logs: `sudo journalctl -u solana-validator -f` (if using systemd)

**RPC not accessible:**
- Wait 30+ seconds after start
- Check firewall: `sudo ufw status`
- Verify bind address: Use `./configure-rpc-public.sh`
- Check if validator is running: `pgrep -f solana-test-validator`

**Public IP not responding:**
This is common and has several causes:

1. **Testing from same network** (most common)
   - Public IP (27.61.56.229) is your router's IP
   - Routers often don't allow "hairpin NAT" (accessing public IP from inside network)
   - **Solution**: Use private IP (172.20.10.14) when testing from same network
   - **OR**: Test from external network (mobile data, different location)

2. **Port forwarding not configured** (local network)
   - Router needs to forward port 8899 to your private IP
   - Access router admin (usually 192.168.1.1)
   - Configure: Port 8899 → 172.20.10.14

3. **Azure NSG not configured** (Azure VM)
   - Go to Azure Portal → VM → Networking
   - Add inbound rule: Port 8899 (TCP)

4. **Firewall blocking**
   - Check: `sudo ufw status`
   - Allow port: `sudo ufw allow 8899/tcp`

**Quick Check:**
```bash
# Check if validator is running
pgrep -f solana-test-validator

# Test local RPC
curl -X POST http://127.0.0.1:8899 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
```

**Connection refused:**
- Ensure validator is running: `pgrep -f solana-test-validator`
- Check firewall rules: `sudo ufw status`
- Verify Azure NSG allows port 8899 (if on Azure)
- Check if port is in use: `sudo lsof -i :8899`

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
- Configure firewall: `sudo scripts/firewall-setup.sh`
- Use VPN for remote access
- Monitor access logs regularly
- Keep system updated

## Production Deployment

**Quick Setup:**
```bash
./azure-setup.sh  # Auto-configures IPs, firewall, and config
./install.sh && ./setup-validator.sh
sudo systemd/install-service.sh
sudo systemctl start solana-validator && sudo systemctl enable solana-validator
```

**Production Checklist:**
- [ ] Azure VM created with public IP
- [ ] NSG configured (port 8899 allowed)
- [ ] `./azure-setup.sh` executed
- [ ] `./install.sh` completed
- [ ] `./setup-validator.sh` completed
- [ ] Systemd service installed and enabled
- [ ] Validator running: `sudo systemctl status solana-validator`
- [ ] RPC accessible: `curl http://<public-ip>:8899`
- [ ] Port available: `sudo lsof -i :8899` (should be empty if not running)

## Requirements

- Ubuntu 22.04 LTS (or compatible)
- 4GB+ RAM (8GB+ recommended for production)
- 50GB+ disk space (SSD recommended)
- sudo/root access (for systemd service)

## Isolation & Safety

✅ **Safe for production** - No impact on other services:
- User-specific directories only
- Port conflict checking
- Resource limits configured
- Non-intrusive firewall rules
- Isolated data storage

## License

MIT License
