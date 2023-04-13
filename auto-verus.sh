#!/bin/bash

## © Oink 2021, released under MIT license
##
## Required binaries:
## jq, curl

## This script will install or upgrade the latest released Verus-CLI binaries from
## the official VerusCoin Github repository (https://github.com/VerusCoin/VerusCoin)

## Determine current path
SCRIPT_PATH=$(dirname $(realpath $0))
cd $SCRIPT_PATH

## determine if the needed dependencies are available
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

# --verus-- (if multiple  instances are found, the first is selected)
if ! command -v verus &>/dev/null ; then
    if ! command -v ./verus &>/dev/null ; then
                VERUS_BINARY=0
        else
                VERUS_BINARY=1
                VERUS=$SCRIPT_PATH/verus
        fi
else
    VERUS=$(which verus)
        VERUS_BINARY=1
fi

# --verusd-- (if multiple  instances are found, the first is selected)
if ! command -v verusd &>/dev/null ; then
    if ! command -v ./verusd &>/dev/null ; then
                VERUSD_BINARY=0
        else
                VERUSD_BINARY=1
                VERUSD=$SCRIPT_PATH/verusd
        fi
else
    VERUSD=$(which verusd)
        VERUSD_BINARY=1
fi

## Check if the daemon is running.
DAEMON_ACTIVE=0
if [[ "${VERUS_BINARY}" == "1" ]]; then
	count=$(${VERUS} getconnectioncount 2>/dev/null)
	case $count in
		''|*[!0-9]*) DAEMON_ACTIVE=0 ;;
		*) DAEMON_ACTIVE=1 ;;
	esac
fi

## determine processor Architecture
lscpu | grep "Architecture" | grep "aarch64"
lscpu | grep "Architecture" | grep "x68_64"

## determine OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="MacOS"
	## Remove next 3 lines if tested successfully on MacOS
	echo "${OS} is not tested yet."
	echo "Exiting..."
	exit 0
else
    OS="Linux"
	if [[ "$(lscpu | grep "Architecture")" == *"aarch64"* ]]; then
		ARCHITECTURE="arm64"
	else
		ARCHITECTURE="x86_64"
	fi
fi

## determine latest Github version
echo "Determining last version on GitHub..."
GITHUB_RELEASE_JSON=$(${CURL} --silent "https://api.github.com/repos/VerusCoin/VerusCoin/releases?per_page=1")
GITHUB_LATEST_RELEASE=$(echo $GITHUB_RELEASE_JSON | ${JQ} -r .[0].name)
GITHUB_DOWNLOAD_URL=$(echo $GITHUB_RELEASE_JSON | ${JQ} ".[0].assets | .[] | select ( .browser_download_url | contains (\"${OS}\"))" | ${JQ} -r "select (.browser_download_url | contains (\"${ARCHITECTURE}\")) | .browser_download_url")
GITHUB_DOWNLOAD_NAME=$(echo $GITHUB_RELEASE_JSON | ${JQ} ".[0].assets | .[] | select ( .name | contains (\"${OS}\"))" | ${JQ} -r "select (.browser_download_url | contains (\"${ARCHITECTURE}\")) | .name")

## check version of running daemon
echo "Checking if daemon is running..."
if [[ "${DAEMON_ACTIVE}" == "1" ]]; then
	CURRENT_VERSION=$(${VERUS} getinfo | ${JQ} -r .VRSCversion)

	## compare running version (if any) to github version
	if [ ${GITHUB_LATEST_RELEASE} = v${CURRENT_VERSION} ]; then
        	echo "You are already running ${GITHUB_LATEST_RELEASE}"
        	echo "No further actions are needed."
        	echo "Exiting now..."
        	sleep 3s
        	exit 0
	fi

	## Check if the node is forked, exit if forking is detected
	echo "Checking if chain is forked..."
	CHECK_FORK="UNKNOWN"
	while [[ ! "$CHECK_FORK" == "OK" ]]; do
		# collect data
		HASH_LOCAL=$(${VERUS} getbestblockhash)
		HEIGHT_LOCAL=$(${VERUS} getblock ${HASH_LOCAL} 1 | jq -r .height)
		HASH_REMOTE=$(${CURL} --silent "https://explorer.verus.io/api/getblockhash?index=${HEIGHT_LOCAL}" | ${JQ} -r .)
		# determine status
		# either output empty = unknown
		if [ -z "${HASH_LOCAL}" ] || [ -z "${HASH_REMOTE}" ]; then
			CHECK_FORK="UNKNOWN"
			echo "Chain state could not be determined. Using local chain."
		# equal output = OK
		elif [ "${HASH_LOCAL}" == "${HASH_REMOTE}" ]; then
			CHECK_FORK="OK"
			echo "The chain is not on a fork."
		# nonequal output = critical
		else
			CHECK_FORK="CRIT"
			echo "The chain seems to be forked. Bootstrap will be activated."
			break
		fi
		sleep 5s
	done
else
	CHECK_FORK="UNKNOWN"
	CURRENT_VERSION=unknown
fi

## Download the latest release binary for this system
echo "Downloading latest version..."
${CURL} --silent --output "$SCRIPT_PATH/${GITHUB_DOWNLOAD_NAME}" -# -L -C - "${GITHUB_DOWNLOAD_URL}"

## Unpack the downloaded archive and get the signature data.
echo "Extracting downloaded version..."
FILELIST=$(tar -xvf "$SCRIPT_PATH/${GITHUB_DOWNLOAD_NAME}")
for i in $FILELIST; do
  if [[ $i = *signature* ]]; then
    SIGNATURE_FILE=$i
  else
    SIGNED_BINARY=$i
  fi
done

printf "Verifying downloaded version"
SIGNATURE_JSON=$(cat "$SCRIPT_PATH/${SIGNATURE_FILE}")
SIGNATURE=$(echo "${SIGNATURE_JSON}" | ${JQ} '.signature')
SIGNER=$(echo "${SIGNATURE_JSON}" | ${JQ} '.signer')
SHA256=$(echo "${SIGNATURE_JSON}" | ${JQ} -r '.hash')

## Verify the signature or sha256, depending on if chain is running and not forked or not running.
if [[ ( "${DAEMON_ACTIVE}" == "0" ) || ( "${CHECK_FORK}" == "CRIT" ) ]]; then
  printf ", using SHA256 checksum method...\n"
  if [[ $(shasum -a256 $SCRIPT_PATH/${SIGNED_BINARY}) == ${SHA256}* ]]; then
    CHECK_RESULT=true
  else
    CHECK_RESULT=false
  fi
else
  echo ", using the VerusID signature..."
  CHECK_RESULT=$(bash -c "${VERUS} verifyfile ${SIGNER} ${SIGNATURE} ${SCRIPT_PATH}/${SIGNED_BINARY}")
fi

if [[ "${CHECK_RESULT}" == "true" ]]; then
        echo "Download verified: OK"
	if [[ -d $SCRIPT_PATH/verus-cli ]]; then
		rm -rf $SCRIPT_PATH/verus-cli
	fi
	tar -xf "$SCRIPT_PATH/${SIGNED_BINARY}"
	rm -f $SCRIPT_PATH/${GITHUB_DOWNLOAD_NAME} $SCRIPT_PATH/${FILELIST}
else
	echo "The integrity check of ${SIGNED_BINARY} failed."
	echo "Removing downloaded files..."
	rm -f $SCRIPT_PATH/${GITHUB_DOWNLOAD_NAME} $SCRIPT_PATH/${FILELIST}
	echo "The upgrade procedure is stopped for security reasons."
	echo "Exiting now..."
	sleep 3s
	exit 1
fi


## Rename daemon and RCP-client, new name depending on conditions.
if [[ "${DAEMON_ACTIVE}" == "1" ]]; then
	mv ${VERUSD} ${VERUSD}-v${CURRENT_VERSION}
	mv ${VERUS} ${VERUS}-v${CURRENT_VERSION}
	cp ${SCRIPT_PATH}/verus-cli/verusd ${VERUSD}
	cp ${SCRIPT_PATH}/verus-cli/verus ${VERUS}
	NEW_INSTALL=false
elif [[ "${VERUS_BINARY}" == "1" ]]; then
	mv ${VERUSD} ${VERUSD}-old
	mv ${VERUS} ${VERUS}-old
        cp ${SCRIPT_PATH}/verus-cli/verusd ${VERUSD}
        cp ${SCRIPT_PATH}/verus-cli/verus ${VERUS}
	NEW_INSTALL=false
else
        ## ask if this is a virgin install
        read -t 30 -p "Is this a new installation of Verus? [Y/n] " FEEDBACK
        case ${FEEDBACK} in
                '')
                        NEW_INSTALL=true
                        printf "\n"
                        ;;
                [yY][eE][sS]|[yY])
                        NEW_INSTALL=true
                        ;;
                *)
                        NEW_INSTALL=false
                        ;;
        esac
fi

## Stop active daemon
if [[ "${DAEMON_ACTIVE}" == "1" ]]; then
        ${VERUS} stop
  ## Monitoring if the daemon is still running, before continuing
  while ps -u "${USER}" x | grep "${VERUSD} " | grep -v "grep"; do
    sleep 2s
  done
fi

## in case of a new install, download zcashparams & bootstrap files
START_PARAMETERS=""
if [[ "${NEW_INSTALL}" == "true" ]]; then
        START_PARAMETERS="-bootstrapinstall"
		#verus-cli/fetch-params
fi

## in case of a forked chain, bootstrap the wallet.
if [[ ("${CHECK_FORK}" == "CRIT") ]]; then
        START_PARAMETERS="-bootstrap -zapwallettxes=2 -rescan"
		#verus-cli/fetch-bootstrap
fi

## start daemon normally, except for forked chain.
## Forked chain will start with `-zapwallettxes=2 -rescan`
if [[ "${DAEMON_ACTIVE}" == "1" ]]; then
    cd ~/.komodo/VRSC
	${VERUSD} ${START_PARAMETERS} -daemon 1>/dev/null 2>&1 &
else
	cp ${SCRIPT_PATH}/verus-cli/verusd .
	cp ${SCRIPT_PATH}/verus-cli/verus .
	cd ~/.komodo/VRSC
	${SCRIPT_PATH}/verusd ${START_PARAMETERS} -daemon 1>/dev/null 2>&1 &
fi

if [[ "${NEW_INSTALL}" == "true" ]]; then
	echo "Verus ${GITHUB_LATEST_RELEASE} is installed."
	echo "Required network parameters will be downloaded by the daemon."
	echo "Bootstrap archive will be downloaded and extracted by the daemon."
	echo "Verus daemon is starting up now."
else
	echo "Verus is upgraded to ${GITHUB_LATEST_RELEASE}."
	if [[ "${CHECK_FORK}" == "CRIT" ]]; then
		echo "Your chain was forked."
		echo "Bootstrap archive has been downloaded and extracted."
		echo "your wallet will be rescanned."
	fi
	echo "Verus daemon is starting up now."
fi

sleep 2s

( tail -f -n0 ~/.komodo/VRSC/debug.log & ) | while IFS= read -r line; do
    echo "${line}"
    if $(echo "${line}" | grep -q "init message: Done loading") ; then
        break
    fi
done

echo "Your Verus daemon has started and is connecting to peers..."

#EOF
