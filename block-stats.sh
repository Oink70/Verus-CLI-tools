#!/bin/bash
## © Oink 2022
## This script retrieves and displays chain statistics
## during the specified period.

# Set locations of the Verus binary. This location will be used if verus was not found in the PATH environment.
VERUS=/opt/verus-cli/verus2

## check if the Verus binary is found and verusd is running.
## If Verus exists in the PATH environment, use it.
## If not, fall back to predefined location in this script.
#if ! command -v verus &>/dev/null
#then
#  echo "verus not found in your PATH environment. Using location from line 9 in this script."
  if ! command -v $VERUS &>/dev/null
  then
    echo "Verus could not be found. Make sure it's in your path and/or in line 9 of this script."
    echo "exiting..."
    exit 1
  fi
#else
#  VERUS=$(which verus)
#fi

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
    -h|--help)
      printf "\nUsage:\n\PoW-rewards [options]\n\n"
      printf "Options:\n\n"
      printf "\t-t #\t--time-window # :\tSet an arbitrary time window (default 24hours). This amount will be deducted from the end date to determine the start date.\n"
      printf "\t\t\t\t\tRequires #minute/#hour/#day/#week/#month/#year.\n"
      printf "\t-s #\t--start # :\t\tSet a start date (00:00 UTC). Overrides the time window. Requires time in YYYY-MM-DD format.\n"
      printf "\t-e #\t--end # :\t\tSet an end date (00:00 UTC). if not set, it uses the current time. Requires time in YYYY-MM-DD format.\n"
      printf "\t-h\t--help :\t\tShows this message on the console.\n"
      printf "\nExamples:\n\n"
      printf "PoW-rewards -t 1week\t\t\tCheck the past week.\n"
      printf "PoW-rewards -s 2022-07-13\t\tCheck statistics from 2022-07-13, 00:00 to now.\n"
      printf "PoW-rewards -e 2022-07-14\t\tCheck statistics from 2022-07-13, 00:00 to 2022-07-14, 00:00.\n"
      printf "PoW-rewards -e 2022-07-14 -t 2day\tCheck statistics from two days prior of 2022-07-14, 00:00 up to 2022-07-14, 00:00.\n"
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
else
  TIME_START=$(date -d "$(date -ud @${TIME_END}) - ${TIME_WINDOW}" +"%s")
fi

## set filename for the CSV export (based on start and end)
EXPORT_CSV="${TIME_START}-${TIME_END}_stats.csv"

## Create a temporary file
temp_file=$(mktemp)

## Determine the blocknumbers that need to be scanned.
## D etermine the first block that happens after $TIME_START
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
printf "From %s to %s,\n" "$(date -d@${TIME_START} +'%F %H:%M %Z')" "$(date -d@${TIME_END} +'%F %H:%M %Z')"
printf "from block $c to block $e \n\n"

## Retrieving every block in the time window, storing each block in a json,
while [ $c -le $e ]; do
  printf "block: %s       \r" $c
  ($VERUS getblock "$c" 2 | $JQ '{ height: .height, blocktype: .blocktype, difficulty: .difficulty, blockreward: [.tx[0].vout[].value] | add }';\
  ($VERUS getblocksubsidy "$c" | $JQ -c '{blocksubsidy: .miner}');\
  printf '{"networksolps": %s}\n ' $($VERUS getnetworksolps -1 $c)) |\
  jq -s '[reduce .[] as $item ({}; . * $item)]' >> $temp_file
  c+=1
done
printf "                            \r"
JSON=$($JQ -s 'add' $temp_file)
rm $temp_file

## Calculate BASIC statistics from JSON
MAX_DIFF=$(echo $JSON | $JQ -c '[.[].difficulty] | max')
MIN_DIFF=$(echo $JSON | $JQ -c '[.[].difficulty] | min')
AVG_DIFF=$(echo $JSON | $JQ -c '[.[].difficulty] | add/length')

MAX_NET_HASH=$( echo $JSON | $JQ -c '[.[].networksolps] | max')
MIN_NET_HASH=$(echo $JSON | $JQ -c '[.[].networksolps] | min')
AVG_NET_HASH=$( echo $JSON | $JQ -c '[.[].networksolps] | add/length')

TOT_BLOCKS=$(echo $JSON | $JQ -c '. | length')
POW_BLOCKS=$(echo $JSON | $JQ -c '[.[] | select(.blocktype=="mined")] | length')
POS_BLOCKS=$(echo $JSON | $JQ -c '[.[] | select(.blocktype=="minted")] | length')

TOT_BLOCK_REWARDS=$(echo $JSON | $JQ -c '[.[] | .blockreward] | add')
TOT_COINB_REWARDS=$(echo $JSON | $JQ -c '[.[] | .blocksubsidy] | add')
TOT_FEES=$(echo "scale=8; $TOT_BLOCK_REWARDS - $TOT_COINB_REWARDS" | $BC)
TOT_FEES_AVG=$(echo "scale=8; $TOT_FEES / $TOT_BLOCKS" | $BC)
TOT_FEES_PERC=$(echo "scale=8; ( $TOT_FEES * 100) / $TOT_BLOCK_REWARDS" | $BC)

POW_BLOCK_REWARDS=$(echo $JSON | $JQ -c '[.[] | select(.blocktype=="mined") | .blockreward] | add')
POW_COINB_REWARDS=$(echo $JSON | $JQ -c '[.[] | select(.blocktype=="mined") | .blocksubsidy] | add')
POW_FEES=$(echo "scale=8; $POW_BLOCK_REWARDS - $POW_COINB_REWARDS" | $BC)
POW_FEES_AVG=$(echo "scale=8; $POW_FEES / $POW_BLOCKS" | $BC)
POW_FEES_PERC=$(echo "scale=8; ($POW_FEES * 100) / $POW_BLOCK_REWARDS" | $BC)

POS_BLOCK_REWARDS=$(echo $JSON | $JQ -c '[.[] | select(.blocktype=="minted") | .blockreward] | add')
POS_COINB_REWARDS=$(echo $JSON | $JQ -c '[.[] | select(.blocktype=="minted") | .blocksubsidy] | add')
POS_FEES=$(echo "scale=8; $POS_BLOCK_REWARDS - $POS_COINB_REWARDS" | $BC)
POS_FEES_AVG=$(echo "scale=8; $POS_FEES / $POS_BLOCKS" | $BC)
POS_FEES_PERC=$(echo "scale=8; ($POS_FEES * 100) /$POS_BLOCK_REWARDS" | $BC)

## export data to a CSV file
echo "Block, BlockType, Difficulty, NetworkHash, BlockSubsidy, BlockReward" > $EXPORT_CSV
echo $JSON | jq -r '.[] | [.height,.blocktype,.difficulty,.networksolps,.blocksubsidy,.blockreward] | @csv' >> $EXPORT_CSV

## Display statistics
printf "Maximum Difficulty:\t\t %s\n" $MAX_DIFF
printf "Minimum Difficulty:\t\t %s\n" $MIN_DIFF
printf "Average Difficulty:\t\t %s\n" $AVG_DIFF

printf "\nMaximum Network Hash:\t\t %s\n" $MAX_NET_HASH
printf "Minimum Network Hash:\t\t %s\n" $MIN_NET_HASH
printf "Average Network Hash:\t\t %s\n" $AVG_NET_HASH

printf "\nAmount of blocks:\t\t %s\n" $TOT_BLOCKS
printf "Amount of PoW blocks:\t\t %s\n" $POW_BLOCKS
printf "Amount of PoS blocks:\t\t %s\n" $POS_BLOCKS

printf "\nTotal Block rewards:\t\t %1.8f\n" $TOT_BLOCK_REWARDS
printf "Total Coinbase rewards:\t\t %1.8f\n" $TOT_COINB_REWARDS
printf "Total fees included:\t\t %1.8f\n" $TOT_FEES
printf "Average fees per block:\t\t %1.8f\n" $TOT_FEES_AVG
printf "fee %% wrt total block reward:\t %1.2f%%\n" $TOT_FEES_PERC

printf "\nTotal PoW rewards:\t\t %1.8f\n" $POW_BLOCK_REWARDS
printf "Total PoW Coinbase rewards:\t %1.8f\n" $POW_COINB_REWARDS
printf "Total PoW fees included:\t %1.8f\n" $POW_FEES
printf "Average fees per PoW block:\t %1.8f\n" $POW_FEES_AVG
printf "fee %% wrt PoW block reward:\t %1.2f%%\n" $POW_FEES_PERC

printf "\nTotal PoS rewards:\t\t %1.8f\n" $POS_BLOCK_REWARDS
printf "Total PoS Coinbase rewards:\t %1.8f\n" $POS_COINB_REWARDS
printf "Total PoS fees included:\t %1.8f\n" $POS_FEES
printf "Average fees per PoS block:\t %1.8f\n" $POS_FEES_AVG
printf "fee %% wrt PoS block reward:\t %1.2f%%\n" $POS_FEES_PERC
