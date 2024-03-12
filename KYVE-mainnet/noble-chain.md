|   Chain ID	 |Custom Port|
|--------------|-----------|
| noble-1      |    150    |
## Documents
https://docs.kyve.network/validators/protocol_nodes/pools/noble/run_noble_node
https://github.com/noble-assets/networks/tree/main/mainnet/noble-1
```bash
  chain_id="noble-1"
  CUSTOM_PORT=150
  name_all=nobled
```
## Install dependencies
```bash
sudo apt -q update
sudo apt -qy install curl git jq lz4 build-essential
sudo apt-get install build-essential
sudo apt -qy upgrade
```
## INSTALL GO
### v1.0.0, v2.0.0, v3.0.0 -> go19
```bash
sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go1.19.2.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
go version
```
### v4.0.1 => go21
sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go1.21.7.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
go version
## Download and build binaries
```bash
# Clone project repository
cd $HOME
rm -rf noble
git clone https://github.com/noble-assets/noble.git
cd noble
git checkout v1.0.0 => go19 
git checkout v2.0.0 => go19 
git checkout v3.0.0 => go19 
git checkout v3.1.0 => go19 
git checkout v4.0.1 => go21

# Build binaries
make build

# Prepare binaries for Cosmovisor
mkdir -p /root/.noble/cosmovisor/upgrades
mkdir -p $HOME/.noble/cosmovisor/genesis/bin
mv bin/nobled $HOME/.noble/cosmovisor/genesis/bin/
rm -rf bin
# v2.0.0
mkdir -p /root/.noble/cosmovisor/upgrades/neon/bin/
mv bin/nobled /root/.noble/cosmovisor/upgrades/neon/bin/

# v3.0.0
mkdir -p /root/.noble/cosmovisor/upgrades/radon/bin/
mv bin/nobled /root/.noble/cosmovisor/upgrades/radon/bin/

# v3.1.0
mkdir -p /root/.noble/cosmovisor/upgrades/v3.1.0/bin/
mv bin/nobled /root/.noble/cosmovisor/upgrades/v3.1.0/bin/

# v4.0.1
mkdir -p /root/.noble/cosmovisor/upgrades/argon/bin/
mv bin/nobled /root/.noble/cosmovisor/upgrades/argon/bin/

# Create application symlinks
sudo ln -s $HOME/.noble/cosmovisor/genesis $HOME/.noble/cosmovisor/current -f
sudo ln -s $HOME/.noble/cosmovisor/current/bin/nobled /usr/local/bin/nobled -f
```
## Install Cosmovisor and create a service
```bash
# Download and install Cosmovisor
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.4.0
#go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0
# Create service 
sudo tee /etc/systemd/system/nobled.service > /dev/null << EOF
[Unit]
Description=$name_all node service
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start --x-crisis-skip-assert-invariants
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.noble"
Environment="DAEMON_NAME=nobled"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:$HOME/.noble/cosmovisor/current/bin"

[Install]
WantedBy=multi-user.target
EOF
```
## Initialize the node 
```bash
# Set node configuration
$name_all config chain-id $chain_id
$name_all config node tcp://localhost:${CUSTOM_PORT}57

# Initialize the node
MONIKER="YOUR_MONIKER_GOES_HERE"
$name_all init $MONIKER --chain-id $chain_id

# Download genesis and addrbook
curl -Ls https://raw.githubusercontent.com/strangelove-ventures/noble-networks/main/mainnet/noble-1/genesis.json > $HOME/.noble/config/genesis.json
curl -Ls https://snapshots.polkachu.com/addrbook/noble/addrbook.json > $HOME/.noble/config/addrbook.json

# Disable indexer
sed -i -e 's|^indexer *=.*|indexer = "null"|' $HOME/.noble/config/config.toml

# Set custom ports
sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:${CUSTOM_PORT}58\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:${CUSTOM_PORT}57\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:${CUSTOM_PORT}60\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:${CUSTOM_PORT}56\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":${CUSTOM_PORT}66\"%" $HOME/.noble/config/config.toml
sed -i -e "s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:${CUSTOM_PORT}17\"%; s%^address = \":8080\"%address = \":${CUSTOM_PORT}80\"%; s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:${CUSTOM_PORT}90\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:${CUSTOM_PORT}91\"%" $HOME/.noble/config/app.toml

# Set config
nano ~/.noble/config/config.toml
\\ timeout_broadcast_tx_commit = "120s"
nano ~/.noble/config/app.toml
\\ pruning = "everything"
\\ index-events = [""]
```
## Start service and check the logs 
```bash
sudo systemctl daemon-reload
sudo systemctl enable $name_all
sudo systemctl start $name_all && sudo journalctl -u $name_all -f --no-hostname -o cat
# GET SYNC INFO
$name_all status 2>&1 | jq .SyncInfo
curl -s localhost:${CUSTOM_PORT}57/status | jq .result.sync_info
```
