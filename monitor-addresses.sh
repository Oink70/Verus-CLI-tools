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
WEBHOOK="<YOUR_ADDRESS_HOOK>"
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

## Retrieve the block.
BLOCK=$($VERUS getblock $BLOCKHASH 2)
TRANSACTIONS=$(echo $BLOCK | ${JQ} '.tx')

## Start preparing the message with Blocktime and Blockheight
TITLE="BlockHeight: **\`$($VERUS getblock ${BLOCKHASH} | ${JQ} -r .height)\`**"
DESCRIPTION="BlockTime: \`$(date --date=@$($VERUS getblock ${BLOCKHASH} | ${JQ} -r .time))\`"

## Loop through relevant transactions

declare -i TRANSACTIONS_NUMBER=$(echo $TRANSACTIONS | ${JQ} '. | length')

## Determine what type of proof produced a block, in order to ignore Coinbase reward and staker transactions
VALIDATION_TYPE=$(echo $BLOCK | ${JQ} -r '.validationtype')
if [ "$VALIDATION_TYPE" == "work" ]
then
  # ignore coinbase transaction
  i=1
elif [ "$VALIDATION_TYPE" == "stake" ]
then
  # ignore coinbase transaction
  i=1
  # ignore staking stransction (last transaction in the block
  TRANSACTIONS_NUMBER=$(echo $TRANSACTIONS | ${JQ} '. | length')-1
else
  # should never happen, but if a block is neither work or stake, consider all transactions
  i=0
fi

## after determination of stransactions to ignore, start looping through remaining transactions
FIELDS=""
while [ $i -lt $TRANSACTIONS_NUMBER ]
do
  ## Get the TXID
  TXID=$(echo $TRANSACTIONS | ${JQ} -r .[$i].txid)
  ## Retrieve the addresses from the TXID
  ADDRESSES=$(echo $TRANSACTIONS | ${JQ} -r .[$i] | ${JQ} -c '.vin | [.[].address | @sh] | unique' | tr -d \' | jq -r .[])
  TEMP_MESSAGE=""
  ADD_TO_MESSAGE=false
  ((i++))
  ## loop through addresses in the address file
  while read -r line; do
    ## Skip empty lines
    if [ "$line" == "" ]
    then
      break
    fi
    ## check if addresses in the TXID are present in the address file
    if [ $(echo "$ADDRESSES" | grep $line) ]
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
    if [ ! "$FIELDS" == "" ]
    then
      FIELDS+=","
    fi
    FIELDS+="{\"name\":\"TXID ${i}: \`${TXID:0:10}...${TXID:59:5}\`: https://insight.verus.io/tx/${TXID}\","
    FIELDS+="\"value\":\"$TEMP_MESSAGE\",\"inline\":false}"
  fi
done

## Compose the embed
MESSAGE="{\"embeds\":[{\"color\": 1127128,\"author\":{\"name\":\"Suspicious Address Check Bot\"},\"title\":\"${TITLE}\",\"description\":\"${DESCRIPTION}\",\"fields\":[${FIELDS}],\"footer\":{\"icon_url\":\"https://cdn.discordapp.com/avatars/454786445702463507/b9ad0b74a4968e5a77930d0a180dd0bd.png?size=4096\",\"text\":\"© Oink 2022\"}}]}"


## If an address is found, send a notification to Discord
if [ ${FOUND} ]
then
#  echo $MESSAGE | jq .
  curl -H "Content-Type: application/json" -X POST -d "$(echo ${MESSAGE})"  $WEBHOOK
fi
