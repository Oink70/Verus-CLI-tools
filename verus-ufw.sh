#!/bin/bash
USER=verus
VERUS=/home/verus/bin/verus
MAIN_CHAIN=VRSC
JQ=$(which jq)

## Remove all PBAAS chains from UFW
REG=$(ufw status numbered | grep 'P2P port (version' | awk -F" " '{print $1}' | sed -E 's/\[//g; s/\]//g' | sort -nr)
for i in $REG; do
  echo 'y' | ufw delete $i
done

## Retrieve chain names for all vrsctest + PBAAS chains
CHAIN_DEFINITIONS=$(su "${USER}" -c "${VERUS} -chain=$MAIN_CHAIN listcurrencies '{\"systemtype\":\"pbaas\"}'")
CHAINS=$(echo $CHAIN_DEFINITIONS | $JQ -r '.[] | .currencydefinition.name')

## add standard ports for all chains to UFW
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

## show current UFW status
ufw status
#EOF
