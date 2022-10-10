#!/bin/bash
## © Oink 2022
## This script checks addresses from a file being present in any send transaction
## present in the block passed through the command line parameter.
## The script is intended to run through `-blocknotify=/path/address-monitor.sh`
## of the Verus daemon
## If an address is detected, it will send a message to the Discord webhook configured
## in line 13

## location of the address file containing the addresses to monitor
ADDRESS_FILE=/home/verus/bin/addresses.txt
## URL of the discord webhook, used to send a notification
WEBHOOK="YOUR-DISCORD-WEBHOOK"
## location of the verus binary
VERUS="/home/verus/bin/verus"



## Check if the configured address file exists
if [ ! -f "$ADDRESS_FILE" ]
then
  echo "${ADDRESS_FILE} does not exist."
  echo "Configure line 11 of this script to point to a valid file."
  echo "The fileshould contain a single address per line."
  exit 1
fi

## Check if the Verus binary is found and verusd is running.
## If Verus exists in the PATH environment, use it.
## If not, fall back to predefined location in this script.
if command -v verus &>/dev/null
then
  VERUS=$(which verus)
elif command -v $VERUS &>/dev/null
then
  break
else
  echo "verus not found in your PATH environment or line 15 in this script."
  echo "Exiting..."
  exit 1
fi

## Dependencies: jq
if ! command -v jq &>/dev/null ; then
    echo "jq not found. please install using your package manager."
    exit 1
else
    JQ=$(which jq)
fi

## check if a there's a value passed to the script.
BLOCKHASH=$1
if [ "$BLOCKHASH" == "" ]
then
  echo "No blockhash or blockheight received."
  echo "Please pass the blockheight or blockhash as a paramater to the script."
  echo "Example 1: ./address-monitor.sh 2234624"
  echo "Example 2: ./address-monitor.sh 000000000008263f8382f888aeb50e60470f0878fa6d77b549e7e2505a5e0a30"
  echo "Example 3: -blocknotify=/path/address-monitor.sh %s"
  echo "Exiting..."
  exit 1
fi

## Retrieve all transactions from the block.
TRANSACTIONS=$($VERUS getblock $BLOCKHASH | ${JQ} '.tx')

## Start preparing the message with Blocktime and Blockheight
MESSAGE="**BlockTime: \`$(date --date=@$($VERUS getblock ${BLOCKHASH} | ${JQ} -r .time))\`**\n"
MESSAGE+="BlockHeight: **\`$($VERUS getblock ${BLOCKHASH} | ${JQ} -r .height)\`**\n"

## Count the number of transactions in the block
TRANSACTIONS_NUMBER=$(echo $TRANSACTIONS | ${JQ} '. | length')

## Loop through every transaction
i=0
while [ $i -lt $TRANSACTIONS_NUMBER ]
do
  ## Get the TXID
  TXID=$(echo $TRANSACTIONS | ${JQ} -r .[$i])
  ((i++))
  ## Retrieve the addresses from the TXID
  ADDRESSES=$($VERUS getrawtransaction ${TXID} 1 | ${JQ} -c '.vin | [.[].addresses] | unique')
  TEMP_MESSAGE=""
  ADD_TO_MESSAGE=false
  ## loop through addresses in the address file
  while read -r line; do
    ## Skip empty lines
    if [ "$line" == "" ]
    then
      break
    fi
    ## check if addresses in the TXID are present in the address file
    if [ $(echo $ADDRESSES | grep $line) ]
    then
      ## Add to the prepared message that an address is found
      TEMP_MESSAGE+="Address: **\`${line}\`** is sending funds\n"
      ## set a flag that an address is found
      FOUND=true
      ADD_TO_MESSAGE=true
    fi
  done < "$ADDRESS_FILE"
  ## Add TXID and address details to message if one or more matches are found
  if [ "$ADD_TO_MESSAGE" == "true" ]
  then
    MESSAGE+="TXID ${i}: https://insight.verus.io/tx/$TXID\n"
    MESSAGE+=$TEMP_MESSAGE
  fi
done

## If an address is found, send a notification to Discord
if [ ${FOUND} ]
then
  curl -H "Content-Type: application/json" -X POST -d '{"content":"'"${MESSAGE}"'"}'  $WEBHOOK
fi
