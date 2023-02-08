#!/bin/bash
## © Oink 2023
## This script checks for any ID update/creation transaction
## present in the block passed through the command line parameter.
## start en end blocks are specified on lines 14-15.
## If a mutation is detected, store the ID-name and i-address in a file
## specified in line 10

## location of the Verus ID file to store detected IDs
VERUSID_FILE="/home/coins/bin/VerusIDs.txt"
## location of the verus binary
VERUS="/home/verus/bin/verus"
## start block enabling VerusIDs
START_BLOCK=800200
END_BLOCK=2402979

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
  echo "verus not found in your PATH environment or line 12 in this script."
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

BLOCKHASH=${START_BLOCK}
while [ ${END_BLOCK} -gt ${BLOCKHASH} ]
do
  ## Retrieve the block.
  BLOCK=$($VERUS getblock $BLOCKHASH 2)
  TRANSACTIONS=$(echo $BLOCK | ${JQ} '.tx')

  ## Loop through transactions

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
    # ignore staking stransaction (last transaction in the block)
    #echo "ignoring staking transaction..."
    TRANSACTIONS_NUMBER=$(echo $TRANSACTIONS | ${JQ} '. | length')-1
  else
    # should never happen, but if a block is neither work or stake, consider all transactions
    i=0
    exit 1
  fi

  ## after determination of stransactions to ignore, start looping through remaining transactions
  while [ $i -lt $TRANSACTIONS_NUMBER ]
  do
    printf 'Block: %s                                                                         \r' ${BLOCKHASH}
    ## Retrieve any ID mutation from the TXID
    CURRENT_TRANSACTION=$(echo $TRANSACTIONS | ${JQ} -r .[$i])
    declare -i VOUTS_NUMBER=$(echo $CURRENT_TRANSACTION | ${JQ} '.vout | length')
    j=0
    while [ $j -lt $VOUTS_NUMBER ]
    do
	  # detection and extraction of data from the vout in the block
	  # $ID will receive the identities name and i-address.
	  # If other data is required the JQ paramaters should be adjusted for that.
      ID=$(echo $CURRENT_TRANSACTION | ${JQ} .vout[$j].scriptPubKey | $JQ -c -r '[select (.identityprimary != null ) | .identityprimary.name,.identityprimary.identityaddress] | select ( (. | length) > 1 )')
      if [[ ${#ID} > 1 ]]
      then
	    # Action section:
		# If a different action is required, the line between this comment and the `fi` should be adjusted/replaced.
        echo $ID >>$VERUSID_FILE
      fi
      ((j++))
    done
    ((i++))
  done
  ((BLOCKHASH++))
done
 printf 'Done......                                                                         \n'
