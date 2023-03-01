#!/bin/bash
## © Oink 2023
## This script checks for any ID update/creation transaction
## present in the block passed through the command line parameter.
## start en end blocks are specified on lines 14-15.
## If a mutation is detected, store the ID-name and i-address in a file
## specified in line 10

## location of the Verus ID file to store detected IDs
VERUSID_FILE="/home/verus/bin/VerusIDs.txt"
## location of the verus binary
VERUS="/home/verus/bin/verus"
## start block enabling VerusIDs
START_BLOCK=800200
END_BLOCK=800210
THREADS=$(nproc)

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
if ! command -v jq &>/dev/null
then
  echo "jq not found. please install using your package manager."
  exit 1
else
  JQ=$(which jq)
fi

echo "Crawling blockchain with parallel processes."
BLOCKLIST=$(seq $START_BLOCK $END_BLOCK)
echo "$BLOCKLIST" | xargs -I "{}" -P $THREADS ./monitor-VerusID.sh {} "$VERUSID_FILE" "$JQ" "$VERUS"
echo "Done....                                                             "
