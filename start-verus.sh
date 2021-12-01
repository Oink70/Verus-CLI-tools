#!/bin/bash +x

## © Oink 2021, released under MIT license
##
## Required binaries:
## jq, curl, bc, tr

## Determine current path
SCRIPT_PATH=$(dirname $(realpath $0))

## check if needed binaries are present
# --curl--
if ! command -v curl &>/dev/null ; then
    echo "curl not found. Please install using your package manager."
    exit 1
else
    CURL=$(which curl)
fi

# --jq--
if ! command -v jq &>/dev/null ; then
    echo "jq not found. Please install using your package manager."
    exit 1
else
    JQ=$(which jq)
fi

# --bc--
if ! command -v bc &>/dev/null ; then
    echo "tr not found. Please install using your package manager."
    exit 1
else
    BC=$(which bc)
fi

# --tr--
if ! command -v bc &>/dev/null ; then
    echo "tr not found. Please install using your package manager."
    exit 1
else
    TR=$(which tr)
fi

## Start VRCS Daemon as verus user
echo "$(date +%F', '%T): Starting VRSC daemon." >${SCRIPT_PATH}/start-verus.log
${SCRIPT_PATH}/verusd -daemon "$@" 1>/dev/null 2>&1

## check if the daemon has started in a loop
## If false wait 15 seconds and repeat loop
## If true proceed to next daemon
dstat=0
until [ $dstat == 1 ]; do
  sleep 15s
  count=$(${SCRIPT_PATH}/verus getconnectioncount)
  case $count in
    ''|*[!0-9]*) dstat=0 ;;
    *) dstat=1 ;;
  esac
done
echo "$(date +%F', '%T): VRSC daemon started and connected." >>${SCRIPT_PATH}/start-verus.log

## Check if the node is fully synchronized

CHECK_STATUS="UNKNOWN"
while [[ ! "$CHECK_STATUS" == "OK" ]]; do
  # collect data
  HEIGHT_LOCAL=$(${SCRIPT_PATH}/verus getinfo | ${JQ} .blocks)
  HEIGHT_REMOTE=$(${CURL} --silent https://explorer.verus.io/api/getblockcount)
  HEIGHT_DISTANCE=$(echo "${HEIGHT_LOCAL}-${HEIGHT_REMOTE}" | ${BC} | ${TR} -d -)
  # determine status
  # either output empty = unknown
  if [ -z "${HEIGHT_LOCAL}" ] || [ -z "${HEIGHT_REMOTE}" ]; then
    CHECK_STATUS="UNKNOWN"
  # equal output = OK
  elif [ "${HEIGHT_LOCAL}" -eq "${HEIGHT_REMOTE}" ]; then
    CHECK_STATUS="OK"
  else
  # distance < 3 = warning
    if [ "${HEIGHT_DISTANCE}" -lt "3" ]; then
      CHECK_STATUS="WARN"
      # distance > 3 = critical
    else
      CHECK_STATUS="CRIT"
    fi
  fi
  sleep 15s
done
echo "$(date +%F', '%T): VRSC daemon is synchronized. Block: "$HEIGHT_LOCAL >>${SCRIPT_PATH}/start-verus.log

## Check if the node is forked

CHECK_STATUS="UNKNOWN"
while [[ ! "$CHECK_STATUS" == "OK" ]]; do
  # collect data
  HASH_LOCAL=$(${SCRIPT_PATH}/verus getbestblockhash)
  HEIGHT_REMOTE=$(${CURL} --silent "https://explorer.verus.io/api/getblockcount")
  HASH_REMOTE=$(${CURL} --silent "https://explorer.verus.io/api/getblockhash?index=${HEIGHT_REMOTE}" | ${JQ} -r .)

  # determine status
  # either output empty = unknown
  if [ -z "${HASH_LOCAL}" ] || [ -z "${HASH_REMOTE}" ]; then
    CHECK_STATUS="UNKNOWN"
  # equal output = OK
  elif [ "${HASH_LOCAL}" == "${HASH_REMOTE}" ]; then
    CHECK_STATUS="OK"
  # nonequal output = critical
  else
    CHECK_STATUS="CRIT"
  fi
  sleep 5s
done
echo "$(date +%F', '%T): VRSC hash matches remote: not on a fork. Hash: "$HASH_LOCAL >>${SCRIPT_PATH}/start-verus.log
