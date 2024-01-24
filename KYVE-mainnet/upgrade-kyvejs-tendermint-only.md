# 1.1.0
```bash
apt install unzip
```
## 1.cosmoshub
```bash
wget https://github.com/KYVENetwork/kyvejs/releases/download/%40kyvejs%2Ftendermint-bsync%401.1.3/kyve-linux-x64.zip
unzip kyve-linux-x64.zip
chmod +x kyve-linux-x64
rm kyve-linux-x64.zip
systemctl stop cosmoshubd
mv kyve-linux-x64 ~/.kysor/upgrades/pool-0/1.1.0/bin/
systemctl start cosmoshubd && journalctl -fu cosmoshubd -o cat
```
## 2.osmosisd, archway, cronos, axelar
```bash
wget https://github.com/KYVENetwork/kyvejs/releases/download/%40kyvejs%2Ftendermint%401.1.3/kyve-linux-x64.zip
unzip kyve-linux-x64.zip
chmod +x kyve-linux-x64
rm kyve-linux-x64.zip
```
### 2.1 osmosisd
```bash
systemctl stop osmosispoold
cp kyve-linux-x64 ~/.kysor/upgrades/pool-1/1.1.0/bin/kyve-linux-x64
systemctl start osmosispoold && sudo journalctl -u osmosispoold -f -o cat
```
### 2.2 archway
```bash
systemctl stop archwaypoold
mv kyve-linux-x64 ~/.kysor/upgrades/pool-2/1.1.0/bin/kyve-linux-x64
systemctl start archwaypoold && sudo journalctl -u archwaypoold -f -o cat
```
### 2.3 axelar
```bash
systemctl stop axelarpoold
mv kyve-linux-x64 ~/.kysor/upgrades/pool-3/1.1.0/bin/kyve-linux-x64
systemctl start axelarpoold && sudo journalctl -u axelarpoold -f -o cat
```
### 2.4 cronos
```bash
systemctl stop cronospoold
mv kyve-linux-x64 ~/.kysor/upgrades/pool-5/1.1.0/bin/kyve-linux-x64
systemctl start cronospoold && sudo journalctl -u cronospoold -f -o cat
```
## 3. Sync-state
```bash
wget https://github.com/KYVENetwork/kyvejs/releases/download/%40kyvejs%2Ftendermint-ssync%401.1.3/kyve-linux-x64.zip
unzip kyve-linux-x64.zip
chmod +x kyve-linux-x64
rm kyve-linux-x64.zip
```
### 3.1 archway-sync
```bash
sudo systemctl stop archway-ssyncd
cp kyve-linux-x64 ~/.kysor/upgrades/pool-4/1.1.0/bin/kyve-linux-x64
sudo systemctl start archway-ssyncd && sudo journalctl -u archway-ssyncd -f -o cat
```
### 3.2 cronos-sync
```bash
sudo systemctl stop cronos-ssyncd 
cp kyve-linux-x64 ~/.kysor/upgrades/pool-6/1.1.0/bin/kyve-linux-x64
systemctl start cronos-ssyncd && sudo journalctl -u cronos-ssyncd -f -o cat
```
