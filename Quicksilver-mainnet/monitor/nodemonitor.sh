#!/bin/bash

###    packages required: jq, bc
REQUIRED_PKG="bc"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
fi

REQUIRED_PKG="jq"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
    echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
    sudo apt-get --yes install $REQUIRED_PKG
fi

###    if suppressing error messages is preferred, run as './nodemonitor.sh 2> /dev/null'

###    CONFIG    ##################################################################################################
CONFIG=""                # config.toml file for node, eg. $HOME/.gaia/config/config.toml
### optional:            #
NAME=""                  # enter the name off the validator key
KEYRINGPW=""             # enter keyring password
NPRECOMMITS="20"         # check last n precommits, can be 0 for no checking
VALIDATORADDRESS=""      # if left empty default is from status call (validator)
QuicksilverVALIDATORADDRESS="" #if left empty default is from status call (Quicksilver validator)
CHECKPERSISTENTPEERS="1" # if 1 the number of disconnected persistent peers is checked (when persistent peers are configured in config.toml)
VALIDATORMETRICS="on"    # metrics for validator node
LOGNAME=""               # a custom log file name can be chosen, if left empty default is nodecheck-<username>.log
LOGPATH="$(pwd)"         # the directory where the log file is stored, for customization insert path like: /my/path
LOGSIZE=200              # the max number of lines after that the log will be trimmed to reduce its size
LOGROTATION="1"          # options for log rotation: (1) rotate to $LOGNAME.1 every $LOGSIZE lines;  (2) append to $LOGNAME.1 every $LOGSIZE lines; (3) truncate $logfile to $LOGSIZE every iteration
SLEEP1="15s"             # polls every SLEEP1 sec
###  internal:           #
colorI='\033[0;32m'      # black 30, red 31, green 32, yellow 33, blue 34, magenta 35, cyan 36, white 37
colorD='\033[0;90m'      # for light color 9 instead of 3
colorE='\033[0;31m'      #
colorW='\033[0;33m'      #
noColor='\033[0m'        # no color
###  END CONFIG  ##################################################################################################

################### NOTIFICATION CONFIG ###################
enable_notification="true" #true of false
# TELEGRAM
enable_telegram="false"
BOT_ID="bot<ENTER_YOURBOT_ID>"
CHAT_ID="<ENTER YOUR CHAT_ID>"
# DISCORD
enable_discord="false"
DISCORD_URL="<ENTER YOUR DISCORD WEBHOOK>"

#variable below avoid spams for the same notification state along with their notification message
#catchup
synced_n="catchingup"  # notification state either synced of catchingup (value possible catchingup/synced)
nmsg_synced="Your Quicksilver node is now in synced"
nmsg_unsynced="Your Quicksilver node is no longer in synced"

#node stuck
lastblockheight=0
node_stuck_n="false" # true or false indicating the notification state of a node stuck
nmsg_nodestuck="Your Quicksilver node is now stuck"
nmsg_node_no_longer_stuck="Your Quicksilver node is no longer stuck, Yeah !"
node_stuck_status="NA" #node stucktest status to print out to log file

#Quicksilver validator run (Quicksilverd)
Quicksilverd_run_n="true" # true or false indicating whether Quicksilverd is running or not
nmsg_Quicksilverd_run_ok="$HOSTNAME: Your Quicksilverd is running ok now"
nmsg_Quicksilverd_run_nok="@here $HOSTNAME: Your Quicksilverd has just stop running, fix it !"
Quicksilverd_run_status="NA" #Quicksilverd test status to print out to log file 

################### END NOTIFICATION CONFIG ###################

echo "Notification enabled on telegram : ${enable_telegram} / on discord : ${enable_discord}"

send_notification() {
    if [ "$enable_notification" == "true" ]; then
        message=$1
        
        if [ "$enable_telegram" == "true" ]; then
            curl -s -X POST https://api.telegram.org/${BOT_ID}/sendMessage -d parse_mode=html -d chat_id=${CHAT_ID=} -d text="<b>$(hostname)</b> - $(date) : ${message}" > /dev/null 2>&1
        fi
        if [ "$enable_discord" == "true" ]; then
            curl -s -X POST $DISCORD_URL -H "Content-Type: application/json" -d "{\"content\": \"${message}\"}" > /dev/null 2>&1
        fi
    fi
}

if [ -z $CONFIG ]; then
        CONFIG=~/.quicksilverd/config/config.toml;
fi

if [ -z $CONFIG ]; then
    echo "please configure config.toml in script"
    exit 1
fi

url=$(sudo sed '/^\[rpc\]/,/^\[/!d;//d' $CONFIG | grep "^laddr\b" | awk -v FS='("tcp://|")' '{print $2}')
chainid=$(jq -r '.result.node_info.network' <<<$(curl -s "$url"/status))
if [ -z $url ]; then
    send_telegram_notification "nodemonitor exited : please configure config.toml in script correctly"
    echo "please configure config.toml in script correctly"
    exit 1
fi
url="http://${url}"

if [ -z $LOGNAME ]; then LOGNAME="nodemonitor-${USER}.log"; fi

logfile="${LOGPATH}/${LOGNAME}"
touch $logfile

echo "log file: ${logfile}"
echo "rpc url: ${url}"
echo "chain id: ${chainid}"

if [ -z $VALIDATORADDRESS ]; then VALIDATORADDRESS=$(jq -r ''.result.validator_info.address'' <<<$(curl -s "$url"/status)); fi
if [ -z $VALIDATORADDRESS ]; then
    echo "rpc appears to be down, start script again when data can be obtained"
    exit 1
fi

if [ -z $QuicksilverVALIDATORADDRESS ];
then 
        if [ -z $NAME ];
        then
        read -p "The name of your validator address :" NAME
        fi
        if [ -z $KEYRINGPW ];
        then
        read -p "Please enter your keyring password :" KEYRINGPW
        fi
        QuicksilverVALIDATORADDRESS=$(echo $KEYRINGPW | quicksilverd keys show $NAME --bech val -a);

fi

# Checking validator RPC endpoints status
consdump=$(curl -s "$url"/dump_consensus_state)
validators=$(jq -r '.result.round_state.validators[]' <<<$consdump)
isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$validators)

echo "validator address: $QuicksilverVALIDATORADDRESS"

if [ "$CHECKPERSISTENTPEERS" -eq 1 ]; then
    persistentpeers=$(sudo sed '/^\[p2p\]/,/^\[/!d;//d' $CONFIG | grep "^persistent_peers\b" | awk -v FS='("|")' '{print $2}')
    persistentpeerids=$(sed 's/,//g' <<<$(sed 's/@[^ ^,]\+/ /g' <<<$persistentpeers))
    totpersistentpeerids=$(wc -w <<<$persistentpeerids)
    npersistentpeersmatchcount=0
    netinfo=$(curl -s "$url"/net_info)
    if [ -z "$netinfo" ]; then
        echo "lcd appears to be down, start script again when data can be obtained"
        exit 1
    fi
    for id in $persistentpeerids; do
        npersistentpeersmatch=$(grep -c "$id" <<<$netinfo)
        if [ $npersistentpeersmatch -eq 0 ]; then
            persistentpeersmatch="$id $persistentpeersmatch"
            npersistentpeersmatchcount=$(expr $npersistentpeersmatchcount + 1)
        fi
    done
    npersistentpeersoff=$(expr $totpersistentpeerids - $npersistentpeersmatchcount)
    echo "$totpersistentpeerids persistent peer(s): $persistentpeerids"
    echo "$npersistentpeersmatchcount persistent peer(s) off: $persistentpeersmatch"
fi

if [ $NPRECOMMITS -eq 0 ]; then echo "precommit checks: off"; else echo "precommit checks: on"; fi
if [ $CHECKPERSISTENTPEERS -eq 0 ]; then echo "persistent peer checks: off"; else echo "persistent peer checks: on"; fi
echo ""

status=$(curl -s "$url"/status)
blockheight=$(jq -r '.result.sync_info.latest_block_height' <<<$status)
blockinfo=$(curl -s "$url"/block?height="$blockheight")
if [ $blockheight -gt $NPRECOMMITS ]; then
    if [ "$(grep -c 'precommits' <<<$blockinfo)" != "0" ]; then versionstring="precommits"; elif [ "$(grep -c 'signatures' <<<$blockinfo)" != "0" ]; then versionstring="signatures"; else
        echo "json parameters of this version not recognised"
        exit 1
    fi
else
    echo "wait for $NPRECOMMITS blocks and start again..."
    exit 1
fi

nloglines=$(wc -l <$logfile)
if [ $nloglines -gt $LOGSIZE ]; then sed -i "1,$(expr $nloglines - $LOGSIZE)d" $logfile; fi # the log file is trimmed for logsize

date=$(date --rfc-3339=seconds)
echo "$date status=scriptstarted chainid=$chainid" >>$logfile

    # Checking Quicksilverd process running
    if pgrep quicksilverd >/dev/null; then
        echo "Is Quicksilverd binary running: Yes";
        Quicksilverd_run_status="OK"
        if [ $Quicksilverd_run_n == "false" ]; then #Quicksilverd process was not ok
        send_notification "$nmsg_Quicksilverd_run_ok"
        Quicksilverd_run_n="true"
        fi
    else
        echo "Is Quicksilverd binary running: No, please restart it;"
        Quicksilverd_run_status="NOK"
        if [ $Quicksilverd_run_n == "true" ]; then #Quicksilverd process was ok
        send_notification "$nmsg_Quicksilverd_run_nok"
        Quicksilverd_run_n="false"
        fi
    fi

        # Checking validator status
        consdump=$(curl -s "$url"/dump_consensus_state)
        validators=$(jq -r '.result.round_state.validators[]' <<<$consdump)
        isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$validators)

    echo

    # testing machine/host resource
    free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }'
    df -h | awk '$NF=="/"{printf "Disk Usage: %d/%dGB (%s)\n", $3,$2,$5}'
    top -bn1 | grep load | awk '{printf "CPU Load: %.2f\n", $(NF-2)}'

    echo
    # TBD Alert on resource monitoring 

    status=$(curl -s "$url"/status)
    result=$(grep -c "result" <<<$status)
    if [ "$result" != "0" ]; then
        npeers=$(curl -s "$url"/net_info | jq -r '.result.n_peers')
        if [ -z $npeers ]; then npeers="na"; fi
        blockheight=$(jq -r '.result.sync_info.latest_block_height' <<<$status)
        blocktime=$(jq -r '.result.sync_info.latest_block_time' <<<$status)
        catchingup=$(jq -r '.result.sync_info.catching_up' <<<$status)
        if [ $catchingup == "false" ]; then 
            catchingup="synced";
            if [ $synced_n == "catchingup" ]; then #it was previously synching
                send_notification "$nmsg_synced"
                synced_n="synced" #change notification state
            fi
        elif [ $catchingup == "true" ]; then 
            catchingup="catchingup";
            if [ $synced_n == "synced" ]; then #it was previously synced
                send_notification $nmsg_unsynced 
                synced_n="catchingup" #change notification state
            fi
        fi

        if [ "$CHECKPERSISTENTPEERS" -eq 1 ]; then
            npersistentpeersmatch=0
            netinfo=$(curl -s "$url"/net_info)
            for id in $persistentpeerids; do
                npersistentpeersmatch=$(expr $npersistentpeersmatch + $(grep -c "$id" <<<$netinfo))
            done
            npersistentpeersoff=$(expr $totpersistentpeerids - $npersistentpeersmatch)
        else
            npersistentpeersoff=0
        fi
        if [ "$VALIDATORMETRICS" == "on" ]; then
            #isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$(curl -s "$url"/block?height="$blockheight"))
            consdump=$(curl -s "$url"/dump_consensus_state)
            validators=$(jq -r '.result.round_state.validators[]' <<<$consdump)
            isvalidator=$(grep -c "$VALIDATORADDRESS" <<<$validators)
            pcttotcommits=$(jq -r '.result.round_state.last_commit.votes_bit_array' <<<$consdump)
            pcttotcommits=$(grep -Po "=\s+\K[^ ^]+" <<<$pcttotcommits)
            if [ "$isvalidator" != "0" ]; then
                isvalidator="yes"
                precommitcount=0
                for ((i = $(expr $blockheight - $NPRECOMMITS + 1); i <= $blockheight; i++)); do
                    validatoraddresses=$(curl -s "$url"/block?height="$i")
                    validatoraddresses=$(jq ".result.block.last_commit.${versionstring}[].validator_address" <<<$validatoraddresses)
                    validatorprecommit=$(grep -c "$VALIDATORADDRESS" <<<$validatoraddresses)
                    precommitcount=$(expr $precommitcount + $validatorprecommit)
                done
                if [ $NPRECOMMITS -eq 0 ]; then pctprecommits="1.0"; else pctprecommits=$(echo "scale=2 ; $precommitcount / $NPRECOMMITS" | bc); fi
             
                validatorinfo="isvalidator=$isvalidator pctprecommits=$pctprecommits pcttotcommits=$pcttotcommits"
            else
                isvalidator="no"
                validatorinfo="isvalidator=$isvalidator"
            fi
        fi

        # test if last block saved and new block height are the same
        if [ $lastblockheight -eq $blockheight ]; then #block are the same
            node_stuck_status="YES"
            if [ $node_stuck_n == "false" ]; then # node_stuck notification state was false
                node_stuck_n="true"
                send_telegram_notification "$nmsg_nodestuck"
            fi
        else #new node block is different
            node_stuck_status="NO"
            if [ $node_stuck_n == "true" ]; then # mean it was previously stuck
                node_stuck_n="false"
                send_telegram_notification "$nmsg_node_no_longer_stuck"                
            fi
            lastblockheight=$blockheight
        fi

        #finalize the log output
        status="$catchingup"
        now=$(date --rfc-3339=seconds)
        blockheightfromnow=$(expr $(date +%s -d "$now") - $(date +%s -d $blocktime))
        variables="status=$status blockheight=$blockheight node_stuck=$node_stuck_status tfromnow=$blockheightfromnow npeers=$npeers npersistentpeersoff=$npersistentpeersoff $validatorinfo"
    else
        status="error"
        now=$(date --rfc-3339=seconds)
        variables="status=$status"
    fi

    logentry="[$now] $variables"
    echo "$logentry" >>$logfile

    nloglines=$(wc -l <$logfile)
    if [ $nloglines -gt $LOGSIZE ]; then
        case $LOGROTATION in
        1)
            mv $logfile "${logfile}.1"
            touch $logfile
            ;;
        2)
            echo "$(cat $logfile)" >>${logfile}.1
            >$logfile
            ;;
        3)
            sed -i '1d' $logfile
            if [ -f ${logfile}.1 ]; then rm ${logfile}.1; fi # no log rotation with option (3)
            ;;
        *) ;;

        esac
    fi

    case $status in
    synced)
        color=$colorI
        ;;
    error)
        color=$colorE
        ;;
    catchingup)
        color=$colorW
        ;;
    *)
        color=$noColor
        ;;
    esac

    pctprecommits=$(awk '{printf "%f", $0}' <<<"$pctprecommits")
    if [[ "$isvalidator" == "yes" ]] && [[ "$pctprecommits" < "1.0" ]]; then color=$colorW; fi
    if [[ "$isvalidator" == "no" ]] && [[ "$VALIDATORMETRICS" == "on" ]]; then color=$colorW; fi

    logentry="$(sed 's/[^ ]*[\=]/'\\${color}'&'\\${noColor}'/g' <<<$logentry)"
    echo -e $logentry
    echo -e "${colorD}sleep ${SLEEP1}${noColor}"
    echo

    variables_=""
    for var in $variables; do
        var_=$(grep -Po '^[0-9a-zA-Z_-]*' <<<$var)
        var_="$var_=\"\""
        variables_="$var_; $variables_"
    done
    #echo $variables_
    eval $variables_

    sleep $SLEEP1
done
