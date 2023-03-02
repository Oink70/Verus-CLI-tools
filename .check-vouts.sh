#!/bin/bash
## © Oink 2023
## This script checks for any ID update/creation transaction prenet in the
## vout number and transaction json passed through as a command line option.
## The script is intended to called by `monitor-VerusID.sh`
## If a mutation is detected, store the ID-name and i-address in a file
## specified through the command line option.

# pull in command line arguments (no checks)
JQ="$1"
VERUSID_FILE="$2"
TRANSACTION_VOUTS="$3"
VOUT="$4"

# check the current vout for a identity transaction
# if found pass the i-address and identity name into the $ID parameter
ID=$(echo "$TRANSACTION_VOUTS" | ${JQ} .[$VOUT].scriptPubKey | $JQ -c -r '[select (.identityprimary != null ) | .identityprimary.name,.identityprimary.identityaddress] | select ( (. | length) > 1 )')
if [[ ${#ID} > 1 ]]
then
  # Store the found info in a file.
  # If you want other/more actions, change this section.
  echo "$ID" >>$VERUSID_FILE
fi
