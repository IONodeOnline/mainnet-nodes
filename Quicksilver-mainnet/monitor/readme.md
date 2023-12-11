# Monitoring Quicksilver node

To have automatic monitoring of your Quicksilver Node & Validator enabled one can follow this guide.

## Script nodemonitor.sh

To monitor the status of the Quicksilver Node & Validator it's possible to run the script **nodemonitor.sh** available in this repository.
This script is based/build on the <https://github.com/stakezone/nodemonitorgaiad> version already available.
When the script is started it will create a file with log entries that monitors the most important stuff of the node.

Since the script creates it's own logfile, it's advised to run it in a separate directory, e.g. **_monitoring_**.

## What is monitored by the script

The script creates a log entry in the following format

```bash
2023-12-06 02:35:56+00:00 status=synced blockheight=1557207 node_stuck=NO tfromnow=7 npeers=12 npersistentpeersoff=1 isvalidator=yes pctprecommits=1.00 pcttotcommits=1.0  mpc_eligibility=OK
```

The log line entries are:

* **status** can be {scriptstarted | error | catchingup | synced} 'error' can have various causes
* **blockheight** blockheight from lcd call
* **node_stuck** YES when last block read is the same as the last iteration, if not then NO
* **tfromnow** time in seconds since blockheight
* **npeers** number of connected peers
* **npersistentpeersoff** number of disconnected persistent peers
* **isvalidator** if validator metrics are enabled, can be {yes | no}
* **pctprecommits** if validator metrics are enabled, percentage of last n precommits from blockheight as configured in nodemonitor.sh
* **pcttotcommits** if validator metrics are enabled, percentage of total commits of the validator set at blockheight
* **mpc_eligibility** OK if MPC eligibility test suceed (ie stake % above min_eligible_threshold), else NOK. ERR will occurs if curl fails

## Telegram Alerting

for telegram alerts, update :

```text
#TELEGRAM
BOT_ID="bot<ENTER_YOURBOT_ID>"
CHAT_ID="<ENTER YOUR CHAT_ID>"
```

you can create your telegram bot following this : <https://core.telegram.org/bots#6-botfather> and obtain the chat_id <https://stackoverflow.com/a/32572159>

## Running the script as a service

To have the script monitor the node constantly and have active alerting available it's possible to run it as a service.
The following example shows how the service file will look like when running in Ubuntu 20.04.

The service assumes:

* you have the script placed in your **_$HOME/quicksilver/monitoring_** directory
* run chmod +x /home/$USER/Quicksilver-tools/monitoring/nodemonitor.sh
* you used the rootless docker installation in the same repo

Please be aware to run the service as the user that has sufficient right to access this directory (normally this will be the user that one used to logon to the system). Best practice would be to create a separate user for the monitoring service, but this guide doesn't cover that!

Create a file called **Quicksilver-nodemonitor.service** in the **~/.config/systemd/user/** by following the commands:

```bash
mkdir -p ~/.config/systemd/user
cat<<-EOF > ~/.config/systemd/user/Quicksilver-nodemonitor.service
[Unit]
Description=Quicksilver NodeMonitor
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
Restart=always
RestartSec=1
ExecStart=/bin/bash -c '. "\$0" && exec "\$@"' /home/$USER/.profile /home/$USER/quicksilver/monitoring/nodemonitor.sh

[Install]
WantedBy=multi-user.target
EOF
```

Now the service file is created it can be started by the following command:

```bash
systemctl --user start Quicksilver-nodemonitor
```

To make sure the service will be active even when a reboot takes place, use:

```bash
systemctl --user enable Quicksilver-nodemonitor
```

Check the status of the service with:

```bash
systemctl --user status Quicksilver-nodemonitor
```

If doing any changes to the files after it was first started do:

```bash
systemctl --user daemon-reload
```

check the nodemonitor log

```bash
journalctl --user -fu Quicksilver-nodemonitor
```

Update the nodemonitor.sh

```bash
git stash
git pull
git stash pop
systemctl --user stop Quicksilver-nodemonitor
systemctl --user start Quicksilver-nodemonitor
```
