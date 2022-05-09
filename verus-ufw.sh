#!/bin/bash
USER=verus
VERUS=/home/verus/bin/verus
JQ=$(which jq)

CHAIN_DEFINITIONS=$(su "${USER}" -c "${VERUS} -chain=vrsctest listcurrencies '{\"systemtype\":\"pbaas\"}'")
CHAINS=$(echo $CHAIN_DEFINITIONS | $JQ -r '.[] | .currencydefinition.name')

for i in $CHAINS
do
  CHAIN_INFO=$(su "${USER}" -c "${VERUS} -chain=${i} getinfo")
  shopt -s nocasematch
  if [[ "${CHAIN_INFO}" == *"${i}"* ]]
  then
    CHAIN_PORT=$(echo $CHAIN_INFO | $JQ .p2pport)
    VERSION=$(echo $CHAIN_INFO | $JQ -r .VRSCversion)
    ufw allow from any to any port $CHAIN_PORT proto tcp comment "${i} P2P port (version v$VERSION)"
  fi
done

#EOF
