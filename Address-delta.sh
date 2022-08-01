#!/bin/bash
## © Oink 2022
## This script retrieves and displays the address delta ovewr a specified period.

# Set locations of the Verus binary. This location will be used if verus was not found in the PATH environment.
VERUS=/home/verus/bin/verus

## check if the Verus binary is found and verusd is running.
## If Verus exists in the PATH environment, use it.
## If not, fall back to predefined location in this script.
if ! command -v verus &>/dev/null
then
  echo "verus not found in your PATH environment. Using location from line 9 in this script."
  if ! command -v $VERUS &>/dev/null
  then
    echo "Verus could not be found. Make sure it's in your path and/or in line 9 of this script."
    echo "exiting..."
    exit 1
  fi
else
  VERUS=$(which verus)
fi

count=$(${VERUS} getconnectioncount 2>/dev/null)
case $count in
  ''|*[!0-9]*) DAEMON_ACTIVE=0 ;;
  *) DAEMON_ACTIVE=1 ;;
esac
if [[ "$DAEMON_ACTIVE" != "1" ]]
then
  echo "verus daemon is not running and connected. Start your verus daemon and wait for it to be connected"
  exit 1
fi

## Dependencies: jq, bc
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


## set defaults
TIME_NOW=$(date +"%s")
TIME_END=$TIME_NOW
TIME_WINDOW=24hour
TIME_START=$(date -d "$(date -ud @${TIME_END}) - ${TIME_WINDOW}" +"%s")
ADDRESS_SET=0

## process command line parameters
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -a|--address)
      address=$2
      ADDRESS_SET=1
      shift # past argument
      shift # past value
      ;;
    -t|--time-window)
      TIME_WINDOW_SET=1
      TIME_WINDOW=$2
      shift # past argument
      shift # past value
      ;;
    -e|--end-date)
      TIME_END_SET=1
      TIME_END=$(date -d "$2" +"%s")
      shift # past argument
      shift # past value
      ;;
    -s|--start-date)
      TIME_START_SET=1
      TIME_START=$(date -d "$2" +"%s")
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      printf "\nUsage:\nAddress-delta [options]\n\n"
      printf "Options:\n\n"
      printf "\t-a #\t--address # :\tMANDATORY: specify an R-address, i-address or VerusID"
      printf "\t-t #\t--time-window # :\tSet an arbitrary time window (default 24hours). This amount will be deducted from the end date to determine the start date.\n"
      printf "\t\t\t\t\tRequires $minute/#hour/#day/#week/#month/#year.\n"
      printf "\t-s #\t--start # :\t\tSet a start date. Overrides the time window. Requires time in YYYY-MM-DD or \"YYYY-MM-DD hh:mm:ss\" format\n"
      printf "\t-e #\t--end # :\t\tSet an end date (00:00 midnight). if not set, it uses the current time. Requires time in YYYY-MM-DD or \"YYYY-MM-DD hh:mm:ss\" format.\n"
      printf "\nExamples:\n\n"
      printf "Address-delta -a "VCF@" -t 1week\t\t\tCheck the past week.\n"
      printf "Address-delta -a "Oink@" -s 2022-07-13\t\tCheck from 2022-07-13, 00:00 to now.\n"
      printf "Address-delta -a "REpxm9bCLMiHRNVPA9unPBWixie7uHFA5C" -e 2022-07-14\t\tCheck from 2022-07-13, 00:00 to 2022-07-14, 00:00.\n"
      printf "Address-delta -a "REpxm9bCLMiHRNVPA9unPBWixie7uHFA5C" -e \"2022-07-14 06:31\" -t 2day\tCheck from two days prior of 2022-07-14, 06:31 up to 2022-07-14, 06:31.\n"
      printf "\n"
      exit 0
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

if [ ! $ADDRESS_SET == 1 ]
then
  printf "\nmissing address:\nAddress-delta --help for help\n\n"
  exit 1
fi

## process the values from the command line parameters
if [ "$TIME_START_SET" == "1" ]
then
  TIME_WINDOW=""
#  echo "Start time is set manually, ignoring time-window (if any)" # enable to verify if the check (if-then condition) works as intended.
else
#  echo "start time not specified, calculating using and time and time-window." # enable to verify if the check (if-then condition) works as intended.
  TIME_START=$(date -d "$(date -ud @${TIME_END}) - ${TIME_WINDOW}" +"%s")
fi

## determine the blocknumbers that need to be scanned.
## Determine the first block that happens after $TIME_START
## To do this, we take an hour time window, retrieve the list of blockhashes
## between $TIME_START and $TIME_START+1hour, to account for an occasional long blocktime
declare -i b=$($VERUS getblock $($VERUS getblockhashes $((TIME_START+3600)) $TIME_START | jq -r '.[0]') | jq -r '.height')

## Determine the last block that happens before $TIME_END
## To do this, we take an hour time window, retrieve the list of blockhashes
## between $TIME_END+1hour and $TIME_END, to account for an occasional long blocktime
declare -i e=$($VERUS getblock $($VERUS getblockhashes $TIME_END $((TIME_END-3600)) | jq -r '.[-1]') | jq -r '.height')

## declaring variables
declare -i c=$b

## Start with the payload
printf "Showing from \t%s\t(block %s).\n" "$(date -d @$(verus getblock ${b} | jq -r .time))" $c
printf "Showing to \t%s\t(block %s).\n\n" "$(date -d @$(verus getblock $e | jq -r .time))" $e

## Retrieving address deltas in the time window,
json=$(echo "{\"addresses\": [\"$address\"], \"start\":$b, \"end\":$e}")
## Add all the deltas to a total amount of sotoshis.
satoshis=$(verus getaddressdeltas "$json" | jq '[.[].satoshis] | add')
## convert satoshis to VRSC.
delta=$(echo "scale=8; $satoshis / 100000000" | bc)
## display the result.
printf "%s:\t%s VRSC.\n" "$address" "$delta"
