#!/bin/bash
## © Oink 2023 for verus.io
## This script craetes a new R-address
## and signs the identity specified in 
## the command line parameters over to
## that new address.

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

## check if the verus daemon is running
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

## check if all dependencies are installed
if ! command -v jq &>/dev/null ; then
    echo "jq not found. Please install using your package manager."
    exit 1
else
    JQ=$(which jq)
fi

## process command line parameters
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -i|--identity)
      identity="$2"
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      printf "\nUsage:\n\update-id.sh [options]\n\n"
      printf "Options:\n\n"
      printf "\t-id #\t--identity # :\tidentity to modify. Friendly name or i-address.\n"
      printf "\nExamples:\n\n"
      printf "update-id.sh -i \"Oink@\"\t\t\tAssign a newly created R-address to Oink@.\n"
      printf "update-id.sh -i iBSUZSgXHEGGz65GTT6BGgchtkTHoFBs57\tAssign a newly created R-address to Oink@.\n"
	  printf "update-id.sh --identity \"Oink@\"\t\t\tAssign a newly created R-address to Oink@.\n"
	  printf "update-id.sh --identity iBSUZSgXHEGGz65GTT6BGgchtkTHoFBs57\tAssign a newly created R-address to Oink@.\n"
      printf "\n"
      exit 0
      ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

if [[ "$identity" == "" ]]
then
  printf "\nNo identity received. Try update-id.sh --help for usage instructions/\n\n"
  exit 1
fi

## get a new R-address
new_address=$($VERUS getnewaddress)


## get current identity json
current_indentity_json=$(${VERUS} getidentity "$identity" | ${JQ} .identity)

## change the primary address
new_identity_json=$(echo $current_indentity_json | ${JQ} --arg new_address $new_address '.primaryaddresses = [$new_address]')


## update the identity
TXID=$($VERUS updateidentity "$new_identity_json")
## note: some check if the command was successful would be nice.

printf '\nVerusID %s updated to primary address %s.\n' "$identity" $new_address
printf 'Transaction ID is: %s\n\n' $TXID
