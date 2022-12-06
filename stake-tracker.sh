#!/bin/bash
## © Oink 2022
## Over the past 24 hours, this script counts the amount of:
## - orphaned stakes ($ORPHANS)
## - accepted stakes with 100 or more confirmations ($STAKES)
## - Total value of accepted stakes with 100 or more confirmations ($OUTAMOUNT)
## Adds thise figures to the file set in the $EXPORT variable

# Set locations of the Verus binary and export file(change to suit your own situation)
VERUS=/home/verus/bin/verus
EXPORT=/home/verus/export/stakes.log

#Dependencies: jq & bc:
if ! command -v jq &>/dev/null ; then
    echo "jq not found. please install using your package manager."
    exit 1
else
    JQ=$(which jq)
fi
if ! command -v bc &>/dev/null ; then
    echo "bc not found. please install using your package manager."
    exit 1
else
    BC=$(which bc)
fi

# Set current time minus 1 day
TIME=$(date -d "now - 1 day" +"%s")
# Set current time
TIME_NOW=$(date +"%s")
# determine the amount of blocks in the time interval

## Iterate 24 hours based on 1395 average blocks per day
ITERATE_BLOCK=$(echo $($VERUS getblockcount)-1395 | $BC)
ITERATE_TIME=$($VERUS getblock $ITERATE_BLOCK | $JQ '.time')

## First decrease the blocknumber to get before the 24 hour boundary
while [[ $ITERATE_TIME > $TIME ]]
do
    ((ITERATE_BLOCK-=1))
    ITERATE_TIME=$($VERUS getblock $ITERATE_BLOCK | $JQ '.time')
done

## Second increase the blocknumber to get to the first block in the 24 hour window
while [[ $ITERATE_TIME < $TIME ]]
do
    ((ITERATE_BLOCK+=1))
    ITERATE_TIME=$($VERUS getblock $ITERATE_BLOCK | $JQ '.time')
done
BLOCKS=$(echo "$($VERUS getblockcount)-$ITERATE_BLOCK" | $BC)

## Development break
exit

# Determine the amount of orphans in the time interval
ORPHANS=$($VERUS listtransactions "" 999 | $JQ "[.[] | select(.confirmations==-1) | select(.amount==0) | select(.time>=$TIME)]" | $JQ -s ".[] | length")
# Add 100 to BLOCKS to account for maturation time
BLOCKS=$(echo "$BLOCKS + 100" | $BC)
# Determine the amount of stakes in the time interval
STAKES=$($VERUS listunspent 1 $BLOCKS | $JQ "[.[] | select(.generated==true) | select (.confirmations>=100)]" | $JQ -s ".[] | length")
# sum up the individual stakes to a total
OUTAMOUNT=$($VERUS listunspent 1 $BLOCKS | $JQ "[.[] | select(.generated==true) | select (.confirmations>=100)]" | $JQ '[.[].amount | tonumber] | add')
# Add a line with date and data to the comma delimited export file
printf "%s   \"Staked Value\": %3.8f, \"valid stakes\": %1.0f, \"orphans\": %1.0f\n" "$(date '+%F %T')" $OUTAMOUNT $STAKES $ORPHANS | tee -a $EXPORT

