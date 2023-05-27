#!/bin/bash

VERUS=~/bin/verus
VERUSD=~/bin/verusd
PARENT_NAME=VRSC
JQ=$(which jq)

CHAIN_DEFINITIONS=$(${VERUS} -chain=${PARENT_NAME} listcurrencies '{"systemtype":"pbaas"}')
CHILD_NAME=$(echo $CHAIN_DEFINITIONS | $JQ -r '.[] | .currencydefinition.name' | sed 's/VRSCTEST//')

printf "\nNotarizations\n=============\n\n"
for i in $CHILD_NAME
do
  verus -chain=$i getblockcount 1>/dev/null 2>&1
  [ $? -ne 0 ] && continue
  printf "${i} notarized into ${PARENT_NAME} at ${PARENT_NAME}-height: "
  verus -chain=$PARENT_NAME getnotarizationdata "${i}" | jq '.notarizations | .[-1].notarization.proofroots | .[-1].height'
  printf "${PARENT_NAME} notarized into ${i} at ${i}-height: "
  verus -chain=$i getnotarizationdata "${PARENT_NAME}" | jq '.notarizations | .[0].notarization.proofroots | .[0].height';printf "Current height $i: "
  verus -chain=$i getblockcount
  printf "\n"
done
printf "Current height $PARENT_NAME: "; verus -chain=$PARENT_NAME getblockcount
