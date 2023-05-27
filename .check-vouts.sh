#!/bin/bash
## © Oink 2023
## This script checks for any ID update/creation transaction prenet in the
## vout number and transaction json passed through as a command line option.
## The script is intended to called by `monitor-VerusID.sh`
## If a mutation is detected, store the ID-name and i-address in a file
## specified through the command line option.

# pull in command line arguments (no checks)
TRANSACTION_VOUTS="$1"
VOUT="$2"

# check the current vout for a identity transaction
# if found pass the i-address and identity name into the $ID parameter
ID=$(echo "$TRANSACTION_VOUTS" |\
 ${JQ} .[$VOUT].scriptPubKey | $JQ -c -r '[select (.identityprimary != null ) | .identityprimary.name,.identityprimary.identityaddress,.identityprimary.parent] | select ( (. | length) > 1 )')
if [[ ${#ID} > 1 ]]
then
  # determine if it is a new ID, an ID update or an ID delay-unlock
  CURRENCY=$($VERUS getcurrency $(echo "$ID" | $JQ -r '.[2]') | $JQ -r '.name')
  VERUS_ID=$(echo "$(echo $ID | $JQ -r '.[0]').$CURRENCY")
  ID_ADDRESS=$(echo "$ID" | $JQ -r '.[1]')
  ID_HISTORY=$($VERUS getidentityhistory $(echo "$ID_ADDRESS") | jq '.history')
  ID_HISTORY_LENGTH=$(echo $ID_HISTORY | $JQ '. | length')
  # If history length is one, it's a newly created ID
  if [[ $ID_HISTORY_LENGTH == 1 ]]
  then
    # Log the new ID in a file
    echo "$ID" >>$VERUSID_FILE-new.txt
    # Discord messaging needs work. If a lot of IDs are created in a single block, you'll be rate limited.
    # The lines below act as an example of how one could send messages to notify about the new IDs.
    # WEBHOOK_URL="https://discord.com/api/webhooks/<YOUR_OWN_WEBHOOK>"
    # PAYLOAD="{ \"content\": \"VerusID **\`$VERUS_ID@\`** (\`$ID_ADDRESS\`) has just been **created**.\" }"
  # If the 2nd to last history entry contains `"flags": 2` and
  # the last history entry contains `"flags": 0`,
  # the delay locked identity is being unlocked.
  elif [[ ($(echo "$ID_HISTORY" | jq '.[-2].identity.flags') == 2) && ($(echo "$ID_HISTORY" | jq '.[-1].identity.flags') == 0) ]]
  then
    # log the unlocked ID in a file
    echo "$ID" >>$VERUSID_FILE-unlock.txt
    # Discord messaging needs work. If a lot of IDs are unlocked in a single block, you'll be rate limited.
    # The lines below act as an example of how one could send messages to notify about the new IDs.
    # TIMELOCK=$(echo "$ID_HISTORY" | jq '.[-1].identity.timelock')
    # WEBHOOK_URL="https://discord.com/api/webhooks/<YOUR_OWN_WEBHOOK>"
    # DISCORDUSER="<@DISCORD-LONG-ID01><@DISCORD-LONG-ID02>" # multiple ping IDs possible. This example has 2.
    # PAYLOAD="{ \"content\": \"$DISCORDUSER: VerusID **\`$VERUS_ID@\`** (\`$ID_ADDRESS\`) is unlocking at block \`$TIMELOCK\`.\" }"
  else
    # log the updated ID in a file
    echo "$ID" >>$VERUSID_FILE-update.txt
    # Discord messaging needs work. If a lot of IDs are updated in a single block, you'll be rate limited.
    # The lines below act as an example of how one could send messages to notify about the new IDs.
    # WEBHOOK_URL="https://discord.com/api/webhooks/<YOUR_OWN_WEBHOOK>"
    # PAYLOAD="{ \"content\": \"VerusID **\`$VERUS_ID@\`** (\`$ID_ADDRESS\`) has just been **updated**.\" }"
  fi
  # If a payload exists fire webhook to Discord.
  if [ -n "$PAYLOAD" ]
  then
    curl -X POST -H 'Content-Type: application/json' -d "$PAYLOAD" "$WEBHOOK_URL"
  fi
fi
