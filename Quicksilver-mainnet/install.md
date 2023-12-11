|   Chain ID	 | Latest Version Tag| Custom Port|
|--------------|-------------------|------------|
| quicksilver-2|      v1.2.17      |     110    |

chain-id=quicksilver-2

CUSTOM_PORT=110

**Install dependencies**
```bash
sudo apt -q update
sudo apt -qy install curl git jq lz4 build-essential
sudo apt -qy upgrade
```
**INSTALL GO**
```bash
sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go1.20.12.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
```
**Download and build binaries**
```bash
# Clone project repository
cd $HOME
rm -rf quicksilver
git clone https://github.com/ingenuity-build/quicksilver.git
cd quicksilver
git checkout v1.2.17

# Build binaries
make build

# Prepare binaries for Cosmovisor
mkdir -p $HOME/.quicksilverd/cosmovisor/genesis/bin
mv build/quicksilverd $HOME/.quicksilverd/cosmovisor/genesis/bin/
rm -rf build

# Create application symlinks
sudo ln -s $HOME/.quicksilverd/cosmovisor/genesis $HOME/.quicksilverd/cosmovisor/current -f
sudo ln -s $HOME/.quicksilverd/cosmovisor/current/bin/quicksilverd /usr/local/bin/quicksilverd -f
```
**Install Cosmovisor and create a service**
```bash
# Download and install Cosmovisor
go install cosmossdk.io/tools/cosmovisor/cmd/cosmovisor@v1.5.0

# Create service
sudo tee /etc/systemd/system/quicksilverd.service > /dev/null << EOF
[Unit]
Description=quicksilver node service
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) run start
Restart=on-failure
RestartSec=10
LimitNOFILE=65535
Environment="DAEMON_HOME=$HOME/.quicksilverd"
Environment="DAEMON_NAME=quicksilverd"
Environment="UNSAFE_SKIP_BACKUP=true"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:$HOME/.quicksilverd/cosmovisor/current/bin"

[Install]
WantedBy=multi-user.target
EOF
```
**Initialize the node**
```bash
# Set node configuration
quicksilverd config chain-id $chain-id
quicksilverd config keyring-backend file
quicksilverd config node tcp://localhost:${CUSTOM_PORT}57

# Initialize the node
MONIKER="YOUR_MONIKER_GOES_HERE"
quicksilverd init $MONIKER --chain-id $chain-id

# Download genesis and addrbook
curl -Ls https://snapshots.kjnodes.com/quicksilver/genesis.json > $HOME/.quicksilverd/config/genesis.json
curl -Ls https://snapshots.kjnodes.com/quicksilver/addrbook.json > $HOME/.quicksilverd/config/addrbook.json

# Set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.0001uqck\"|" $HOME/.quicksilverd/config/app.toml

# Set pruning
sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "10"|' \
  $HOME/.quicksilverd/config/app.toml
# Disable indexer
sed -i -e 's|^indexer *=.*|indexer = "null"|' $HOME/.quicksilverd/config/config.toml

# Set custom ports
sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:${CUSTOM_PORT}58\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:${CUSTOM_PORT}57\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:${CUSTOM_PORT}60\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:${CUSTOM_PORT}56\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":${CUSTOM_PORT}66\"%" $HOME/.quicksilverd/config/config.toml
sed -i -e "s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:${CUSTOM_PORT}17\"%; s%^address = \":8080\"%address = \":${CUSTOM_PORT}80\"%; s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:${CUSTOM_PORT}90\"%; s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:${CUSTOM_PORT}91\"%" $HOME/.quicksilverd/config/app.toml

```
**Start service and check the logs**
```bash
sudo systemctl daemon-reload
sudo systemctl enable quicksilverd
sudo systemctl start quicksilverd && sudo journalctl -u quicksilverd -f --no-hostname -o cat
# GET SYNC INFO
quicksilverd status 2>&1 | jq .SyncInfo
curl -s localhost:${CUSTOM_PORT}/status | jq .result.sync_info
```
**Key management**
```bash
# ADD NEW KEY
archwayd keys add wallet
# RECOVER EXISTING KEY
archwayd keys add wallet --recover
# LIST ALL KEYS
archwayd keys list
# EXPORT KEY TO A FILE
archwayd keys export wallet
```
**CREATE NEW VALIDATOR**
```bash
quicksilverd tx staking create-validator \
--amount 1000000uqck \
--pubkey $(quicksilverd tendermint show-validator) \
--moniker "YOUR_MONIKER_NAME" \
--identity "YOUR_KEYBASE_ID" \
--details "YOUR_DETAILS" \
--website "YOUR_WEBSITE_URL" \
--chain-id $chain-id \
--commission-rate 0.05 \
--commission-max-rate 0.20 \
--commission-max-change-rate 0.01 \
--min-self-delegation 1 \
--from wallet \
--gas-adjustment 1.4 \
--gas auto \
--gas-prices 0.0001uqck \
-y
```
**EDIT EXISTING VALIDATOR**
```bash
quicksilverd tx staking edit-validator \
--new-moniker "YOUR_MONIKER_NAME" \
--identity "YOUR_KEYBASE_ID" \
--details "YOUR_DETAILS" \
--website "YOUR_WEBSITE_URL" \
--chain-id $chain-id \
--commission-rate 0.05 \
--from wallet \
--gas-adjustment 1.4 \
--gas auto \
--gas-prices 0.0001uqck \
-y
```
**RESET CHAIN DATA**
```bash
quicksilverd tendermint unsafe-reset-all --keep-addr-book --home $HOME/.quicksilverd --keep-addr-book
```
**REMOVE NODE: Make sure you have backed up your priv_validator_key.json**
```bash
cd $HOME
sudo systemctl stop quicksilverd
sudo systemctl disable quicksilverd
sudo rm /etc/systemd/system/quicksilverd
sudo systemctl daemon-reload
rm -f $(which quicksilverd)
rm -rf $HOME/.quicksilverd
rm -rf $HOME/quicksilver
```
**Token management**
```bash
# WITHDRAW REWARDS FROM ALL VALIDATORS
quicksilverd tx distribution withdraw-all-rewards --from wallet --chain-id $chain-id --gas-adjustment 1.4 --gas auto --gas-prices 0.0001uqck -y
# WITHDRAW COMMISSION AND REWARDS FROM YOUR VALIDATOR
quicksilverd tx distribution withdraw-rewards $(quicksilverd keys show wallet --bech val -a) --commission --from wallet --chain-id $chain-id --gas-adjustment 1.4 --gas auto --gas-prices 0.0001uqck -y
# Unjail Validator
quicksilverd tx slashing unjail --from wallet --chain-id $chain-id --gas-adjustment 1.4 --gas auto --gas-prices 0.0001uqck -y
```
