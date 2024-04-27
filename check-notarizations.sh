#!/bin/bash -x
## © Oink 2022-2024
## This script retrieves and displays the most recent notarization of running PBaaS chains.

# Set locations of the Verus binary. This location will be used if verus was not found in the PATH environment.
VERUS=/home/verus/bin/verus
# set the main chain. Until fractal scalability is fully implemented (PbaaS chains spinning up PBaaS chains) this will be VRSC.
PARENT_NAME=VRSC

## process command line parameters
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -t|--testnet)
      PARENT_NAME=vrsctest
      shift # past argument
      ;;
  esac
done

## check if the Verus binary is found and verusd is running.
## If Verus exists in the PATH environment, use it.
## If not, fall back to predefined location in this script.
if ! command -v verus &>/dev/null
then
  echo "verus not found in your PATH environment. Using location from line 6 in this script."
  if ! command -v $VERUS &>/dev/null
  then
    echo "Verus could not be found. Make sure it's in your path and/or in line 6 of this script."
    echo "exiting..."
    exit 1
  fi
else
  VERUS=$(which verus)
fi

## add the switch '-testnet' to $VERUS if the chain is "vrsctest".
if [[ "$PARENT_NAME" == "vrsctest" ]]
then
  VERUS=$VERUS" -testnet"
fi

count=$(${VERUS} -chain=$PARENT_NAME getconnectioncount 2>/dev/null)
case $count in
  ''|*[!0-9]*) DAEMON_ACTIVE=0 ;;
  *) DAEMON_ACTIVE=1 ;;
esac
if [[ "$DAEMON_ACTIVE" != "1" ]]
then
  echo "verus daemon is not running and connected. Start your verus daemon and wait for it to be connected"
  exit 1
fi

#Dependencies: jq (command-line json parser/editor), sed (search and replace)
if ! command -v jq &>/dev/null ; then
    echo "jq not found. please install using your package manager."
    exit 1
else
    JQ=$(which jq)
fi
if ! command -v sed &>/dev/null ; then
    echo "sed not found. please install using your package manager."
    exit 1
else
    SED=$(which sed)
fi


CHAIN_DEFINITIONS=$(${VERUS} -chain=$PARENT_NAME listcurrencies '{"systemtype":"pbaas"}')
CHILD_NAME=$(echo $CHAIN_DEFINITIONS | $JQ -r '.[] | .currencydefinition.name' | $SED "s/$PARENT_NAME//I")


printf "\nNotarizations\n=============\n\n"
for i in $CHILD_NAME
do
  $VERUS -chain=$i getblockcount 1>/dev/null 2>&1
  [ $? -ne 0 ] && continue
  printf "${i} block notarized into ${PARENT_NAME}: "
  $VERUS -chain=$PARENT_NAME getnotarizationdata "${i}" | $JQ '.notarizations | .[0].notarization.notarizationheight'
  printf "${i} current height: "
  $VERUS -chain=$i getblockcount
  printf "${PARENT_NAME} block notarized into ${i}: "
  $VERUS -chain=$i getnotarizationdata "${PARENT_NAME}" | $JQ '.notarizations | .[0].notarization.notarizationheight'
  printf "$PARENT_NAME current height: "
  $VERUS -chain=$PARENT_NAME getblockcount
  printf "\n"
done