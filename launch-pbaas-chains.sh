#!/bin/bash
USER=verus
VERUS=/home/verus/bin/verus
VERUSD=/home/verus/bin/verusd
JQ=$(which jq)

CHAIN_DEFINITIONS=$(su "${USER}" -c "${VERUS} -chain=vrsctest listcurrencies '{\"systemtype\":\"pbaas\"}'")
CHAINS=$(echo $CHAIN_DEFINITIONS | $JQ -r '.[] | .currencydefinition.name')

for i in $CHAINS
do
  CHAIN_INFO=$(su "${USER}" -c "${VERUS} -chain=${i} getinfo")
  shopt -s nocasematch
  if [[ "${CHAIN_INFO}" == *"${i}"* ]]
  then
    echo "chain ${i} is already running"
  else
    su "${USER}" -c "${VERUSD} -chain=${i}  1>/dev/null 2>&1"
  fi
done

#EOF
