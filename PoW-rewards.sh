#!/bin/bash
## © Oink 2022
## This script retrieves and displays the addresses that received a Proof-of-Work reward
## during the specified period. It counts the award per address and displays them
## starting with the largest number of rewards to the least number.
## It also identifies known addresses and colorizes the ones it knows about.

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
FILTER_FILE=KnownPoolAddresses.sed

## process command line parameters
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
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
    -f|--filter-file)
      FILTER_FILE=$2
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      printf "\nUsage:\n\PoW-rewards [options]\n\n"
      printf "Options:\n\n"
      printf "\t-t #\t--time-window # :\tSet an arbitrary time window (default 24hours). This amount will be deducted from the end date to determine the start date.\n"
      printf "\t\t\t\t\tRequires $minute/#hour/#day/#week/#month/#year.\n"
      printf "\t-s #\t--start # :\t\tSet a start date (00:00 midnight). Overrides the time window. Requires time in YYYY-MM-DD format.\n"
      printf "\t-e #\t--end # :\t\tSet an end date (00:00 midnight). if not set, it uses the current time. Requires time in YYYY-MM-DD format.\n"
      printf "\t-t #\t--filter-file # :\tSpecify a custum filterfile for the sed function to identify known addresses.\n"
      printf "\nExamples:\n\n"
      printf "PoW-rewards -t 1week\t\t\tCheck the past week.\n"
      printf "PoW-rewards -s 2022-07-13\t\tCheck PoW rewards from 2022-07-13, 00:00 to now.\n"
      printf "PoW-rewards -e 2022-07-14\t\tCheck PoW rewards from 2022-07-13, 00:00 to 2022-07-14, 00:00.\n"
      printf "PoW-rewards -e 2022-07-14 -t 2day\tCheck PoW from two days prior of 2022-07-14, 00:00 up to 2022-07-14, 00:00.\n"
      printf "PoW-rewards -t private-list\t\tUse the file private-list to identify addresses.\n"
      printf "\n"
      exit 0
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

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
#clear
echo -e "Showing PoW reward addresses from block $c to block $e"

## Retrieving every block in the time window, determine for each block if it was a mined block,
## then pipe the result through sorting, counting the amount of blocks per address and
## sorting the result from high to low.
## Finally identify known addresses and add that (colored) info to the output
## known pool addresses are green (\x1B[32m).
## known hidden pool addresses are red (\x1B[31m).
## unknown addresses stay the standard terminal color.
while [ $c -le $e ]; do 
  $VERUS getblock "$c" 2 | $JQ -r '. | select(.validationtype=="work") | .tx | .[0].vout | .[0].scriptPubKey | .addresses| .[0]'
  c+=1
done | \
sort | \
uniq -c | \
sort -bgr | \
sed -f $FILTER_FILE
#sed 's/RWyCyhLW4koEXs5ZaJabeBQ4LHuSYearod/\x1B[32m& <-- Luckpool\x1B[0m/g
#s/RLSed6KVEkT6nEoipn4NqKHzLupUXk9Rou/\x1B[32m& <-- Zergpool\x1B[0m/g
#s/RYMPmGZEkX5TNcouypSXszM6CMRkLteKoo/\x1B[32m& <-- Community pool\x1B[0m/g
#s/R9ZBLh1nCyQKLn4EYLKzhAFowJDDhCZ9vM/\x1B[32m& <-- Popablock\x1B[0m/g
#s/RBMmSC4w1FUjLtEPNS7J2NfKj23xwNdZo3/\x1B[32m& <-- AiH\x1B[0m/g
#s/RDiZSEYuT8G5brv538He2mgFrjtCNMJ1CV/\x1B[32m& <-- Verus.farm\x1B[0m/g
#s/R9Q9v3i6TgtFjx33UKEmxUtS5m6ri6rZDw/\x1B[32m& <-- zpool\x1B[0m/g
#s/RXTQnEiivwjvxwiwFDH39xX9yrf8VmPMmt/\x1B[32m& <-- 011data\x1B[0m/g
#s/RPqYBReGEnPPRpVF9eJBNBvCDwv7XxQnyS/\x1B[32m& <-- Quickpool\x1B[0m/g
#s/RQEFyoSmiYbdhCfR3o6G6PLoauRR6tU5cq/\x1B[32m& <-- ciscotech\x1B[0m/g
#s/RQvauDKH4ivDY9uCMvv8LpfdVUw35roxyC/\x1B[32m& <-- daemoncoins\x1B[0m/g
#s/RKNfKXfyffwngQZqJLYUsWJ8JMNb7FR7f1/\x1B[32m& <-- wattpool\x1B[0m/g
#s/RBBxnQZyPhAwcejNK25wdQEpp6JgTkfbww/\x1B[32m& <-- AOD-tech\x1B[0m/g
#s/RQMWiWk7DgPuYfVSP4aa3P2edDFY5bmbz3/\x1B[31m& <-- !!! UNKOWN ADDRESS !!!(also mining on popablock)\x1B[0m/g
#s/RNpxYCGpJthvPGpL7K2pYrQUH8tuw1CFje/\x1B[31m& <-- !!! HIDDEN POOL !!!\x1B[0m/g'

