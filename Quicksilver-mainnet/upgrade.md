## Upgrade v1.4.7 : pre-build
```bash
mkdir -p $HOME/.quicksilverd/cosmovisor/upgrades/v1.4.7/bin/
wget https://github.com/quicksilver-zone/quicksilver/releases/download/v1.4.7/quicksilverd-v1.4.7-amd64
chmod +x quicksilverd-v1.4.7-amd64
mv quicksilverd-v1.4.7-amd64 $HOME/.quicksilverd/cosmovisor/upgrades/v1.4.7/bin/quicksilverd
```
## Upgrade v1.4.7 : build
### Install go v1.21.5
```bash
sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go1.21.5.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
```
### Clone project repository
```bash
cd $HOME
rm -rf quicksilver
git clone https://github.com/ingenuity-build/quicksilver.git
cd quicksilver
git checkout v1.4.7
```
### Prepare binaries for Cosmovisor
```bash
mkdir -p $HOME/.quicksilverd/cosmovisor/upgrades/v1.4.7/bin/
mv build/quicksilverd $HOME/.quicksilverd/cosmovisor/upgrades/v1.4.7/bin/
```
