#!/bin/bash
## © Oink 2023
## This script checks for any ID update/creation transaction
## present in the block passed through the command line parameter.
## The script is intended to run through `-blocknotify=/path/monitor-VerusID.sh`
## of the Verus daemon.
## If a mutation is detected, store the ID-name and i-address in a file
## specified in line 11

## location of the Verus ID file to store detected IDs
VERUSID_FILE="/home/verus/bin/VerusIDs.txt"
## location of the verus binary
VERUS="/home/verus/bin/verus"


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
  echo "verus not found in your PATH environment or in the location specified in line 13 of this script."
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
  echo "Example 1: ./monitor-VerusID.sh 2234624"
  echo "Example 2: ./monitor-VerusID.sh 000000000008263f8382f888aeb50e60470f0878fa6d77b549e7e2505a5e0a30"
  echo "Example 3: -blocknotify=/path/monitor-VerusID.sh %s"
  echo "Exiting..."
  exit 1
fi

## Retrieve the block.
BLOCK=$($VERUS getblock $BLOCKHASH 2)
TRANSACTIONS=$(echo "$BLOCK" | ${JQ} '.tx')

## Loop through transactions
declare -i TRANSACTIONS_NUMBER=$(echo "$TRANSACTIONS" | ${JQ} '. | length')

## Determine what type of proof produced a block, in order to ignore Coinbase reward and staker transactions
VALIDATION_TYPE=$(echo "$BLOCK" | ${JQ} -r '.validationtype')
if [ "$VALIDATION_TYPE" == "work" ]
then
  # ignore coinbase transaction
  i=1
elif [ "$VALIDATION_TYPE" == "stake" ]
then
  # ignore coinbase transaction
  i=1
  # ignore staking stransaction (last transaction in the block)
  TRANSACTIONS_NUMBER=$(echo "$TRANSACTIONS" | ${JQ} '. | length')-1
else
  # should never happen, but if a block is neither work or stake, consider all transactions
  i=0
  exit 1
fi

## after determination of stransactions to ignore, start looping through remaining transactions
while [ $i -lt $TRANSACTIONS_NUMBER ]
do
  ## Retrieve any ID mutation from the TXID
  CURRENT_TRANSACTION=$(echo "$TRANSACTIONS" | ${JQ} -r .[$i])
  declare -i VOUTS_NUMBER=$(echo "$CURRENT_TRANSACTION" | ${JQ} '.vout | length')
  j=0
  while [ $j -lt $VOUTS_NUMBER ]
  do
    # check the current vout for a identity transaction
	# if found pass the i-address and identity name into the $ID parameter
    ID=$(echo "$CURRENT_TRANSACTION" | ${JQ} .vout[$j].scriptPubKey | $JQ -c -r '[select (.identityprimary != null ) | .identityprimary.name,.identityprimary.identityaddress] | select ( (. | length) > 1 )')
    if [[ ${#ID} > 1 ]]
    then
	  # Store the found info in a file.
	  # If you want other/more actions, change this section.
      echo "$ID" >>$VERUSID_FILE
    fi
    ((j++))
  done
  ((i++))
done

