## ONLY UPGRADE KYVEJS TENDERMINE SSYNC ##

## Download: V1.1.1 ##
```bash
wget https://github.com/KYVENetwork/kyvejs/releases/download/%40kyvejs%2Ftendermint-ssync%401.1.1/kyve-linux-x64.zip
unzip kyve-linux-x64.zip
chmod +x kyve-linux-x64
rm kyve-linux-x64.zip
```
## archway-ssync
```bash
mv kyve-linux-x64 ~/.kysor/upgrades/pool-4/1.1.0/bin/kyve-linux-x64
sudo systemctl restart archway-ssyncd && sudo journalctl -u archway-ssyncd -f -o cat
```
## cronos-ssync
```bash
mv kyve-linux-x64 ~/.kysor/upgrades/pool-6/1.1.0/bin/kyve-linux-x64
sudo systemctl restart cronos-ssyncd && sudo journalctl -u cronos-ssyncd -f -o cat
```
