#!/bin/bash 
## © Oink 2023
## This script checks for any ID update/creation transaction
## present in the block passed through the command line parameter.
## The script is intended to run through `-blocknotify=/path/monitor-VerusID.sh`
## of the Verus daemon.
## If a mutation is detected, store the ID-name and i-address in a file
## specified in line 14.

## default variable definitions
## location of the Verus ID file to store detected IDs
## The name will be appended by `-new.txt`, `-unlock.txt` or
## `-update.txt`, depending on what is detected.
export VERUSID_FILE="/home/verus/bin/VerusIDs"
## location of the verus binary
export VERUS="/home/verus/bin/verus"
## location of jq binary
export JQ=$(which jq)

## Set script folder
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

## Retrieve parameters passed through CLI command
if [ $# = 1 ]
then
  BLOCKHASH="$1"
elif [ $# = 2 ]
then
  BLOCKHASH="$1"
  VERUSID_FILE="$2"
elif [ $# = 3 ]
then
  BLOCKHASH="$1"
  VERUSID_FILE="$2"
  JQ="$3"
elif [ $# = 4 ]
then
  BLOCKHASH="$1"
  VERUSID_FILE="$2"
  JQ="$3"
  VERUS="$4"
fi

## check if a there's a value passed to the script.
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
TRANSACTIONS=$(echo "$BLOCK" | ${JQ} -c '.tx')

## Loop through transactions
declare -i TRANSACTIONS_NUMBER=$(echo "$TRANSACTIONS" | ${JQ} '. | length')
printf "Checking block %s with %s transactions.                \r" "$BLOCKHASH" "$TRANSACTIONS_NUMBER"

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
  TRANSACTION_VOUTS=$(echo "$CURRENT_TRANSACTION" | ${JQ} -c '.vout')
  ## Determine if the amount of vouts > 0 and <= 250
  if (( VOUTS_NUMBER >= 1 && VOUTS_NUMBER <= 250 ))
  then
    VOUTS="0"
    j=0
    while [ $j -lt $VOUTS_NUMBER ]
    do
      ((j++))
      VOUTS="$VOUTS\n$j"
    done
    echo -e "$VOUTS" | xargs -I{} -P $(nproc) $SCRIPT_DIR/.check-vouts.sh "$TRANSACTION_VOUTS" {}
  ## if the number of vouts exceeds 250, the json is too big for xargs.
  ## cut the amount of vouts up in chuncks of 250 for processing.
  elif (( VOUTS_NUMBER > 250 ))
  then
    CHUNKS=$(seq 0 250 $VOUTS_NUMBER)
    for k in $CHUNKS;
    do
      if (( k < (VOUTS_NUMBER-250) ))
      then
        l=$(( k + 250 ))
        VOUTS_CHUNK=$(echo "$TRANSACTION_VOUTS" | jq -c ".[$k:$l]")
      else
        VOUTS_CHUNK=$(echo "$TRANSACTION_VOUTS" | jq -c ".[$k:$VOUTS_NUMBER]")
      fi
      VOUTS="0"
      j=0
      while [ $j -lt $VOUTS_NUMBER ]
      do
        ((j++))
        VOUTS="$VOUTS\n$j"
      done
      echo -e "$VOUTS" | xargs -I{} -P $(nproc) $SCRIPT_DIR/.check-vouts.sh "$VOUTS_CHUNK" {}
    done
  fi
  ((i++))
done
