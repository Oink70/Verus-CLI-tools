# Verus-CLI-tools
A collection of scripts to simplify life on CLI.
These tools are tested on Linux Ubuntu 20.04LTS, Debian 10 and Debian 11
Some of these scripts are based on code written by Alex English (https://github.com/alexenglish/VerusExtras)

## Content suitable for mainnet:
 - `auto-verus.sh`: install or upgrade Verus binaries
 - `start-verus.sh`: Start Verus with fork and height checks
 - `stake-tracker.sh`: Counts all stakes in the past 24 hours. Differntiates between orphans and successful stakes.
 - `consolidate.sh`: consolidates UTXOs in your wallet below the treshold value.
 ## content only usable on testnet:
 - `launch-pbaas-chains.sh`: launches all PBaaS chains known on the VRSCTEST network.
 - `verus-ufw.sh`: Opens UFW ports for all testnet chains that are running.

## auto-verus.sh
### Description
1) if no `verusd` binary is found in the path or local folder:
  - Download the latest official version from the VerusCoin Github repository, based on OS and processor architecture (yes, it works on ARM-linux as well).
  - Check the download using SHA256.
  - Call the `fetch-params` script from the downloaded release (downloads *Zcash parameters* to the required location).
  - Call the `fetch-bootstrap` script from the downloaded release (downloads, verifies and extracts *bootstrap archive*).
  - Start the Verus wallet (CLI).
2) if `verusd` binaries are found, but not running:
  - download the latest official version from the VerusCoin Github repository, based on OS and processor architecture.
  - Check the download using SHA256.
  - Rename the existing binaries to `*-old`.
  - Start the Verus wallet (CLI).
3) if `verusd` is found running and the local chain is not forked:
  - download the latest official version from the VerusCoin Github repository, based on OS and processor architecture.
  - Check the download using Verus signatures.
  - Rename the existing binaries with the suffix of the current running version.
  - Start the Verus wallet (CLI).
4) if `verusd` is found running, but the built-in checks determine the chain is forked:
  - download the latest official version from the VerusCoin Github repository, based on OS and processor architecture.
  - Check the download using SHA256.
  - Rename the existing binaries to `*-old`.
  - Call the `fetch-bootstrap` script from the downloaded release (downloads, verifies and extracts *bootstrap archive*).
  - start the Verus wallet (CLI) with `-zapwallettxes=2 -rescan` options

### Prerequisites
 - Linux OS
 - `curl` and `jq` installed

### Usage
 - Execute `auto-verus.sh`. Command line parameters are ignored.

## start-verus.sh
### Description
1) Start the Verus daemon, and the script waits to return to the command line, until the following conditions are met:
  - The node has connected to at least one other node.
  - The node is fully synchronized (It compares the local blockheight to the Verus explorer blockheight).
  - The latest blockhash on the node is equal to the blockhash for that block on the Verus explorer.
2) Progress is logged in the script folder in the `start-verus.log` file in the script folder
Possible use cases for this script include starting any other application that relies on verus being
fully synchronized and unforked, such as an explorer, pool, exchange or any other application.

### Prerequisites
 - Linux OS
 - `bc`, `curl`, `jq` and `tr` installed
 - The script is placed in the directory containing the `verusd` and `verus` binaries.

### Usage
 - Execute `start-verus.sh`. Command line parameters are passed as `verusd` startup parameters.

## stake-tracker.sh
### Description
1) Checks the wallet transactions for stakes over the past 24 hours and adds the result to a text files

### Prerequisites
 - Linux OS
 - `bc` and `jq` installed.
 - The location of the `verus` binary is set on line 10 of the script.
 - The location and name of the export logfile are set on line 11 of the script.

### Usage
 - Execute `stake-tracker.sh`. For consistend results, best to run on a daily schedule from your `crontab`.

## consolidate.sh
### Description
Loosely based on scripts from https://github.com/alexenglish/VerusExtras
1) This script looks for unspent transactions below the supplied limit (if none supplied smaller than 2500) and spends them back to the same address.
2) If there are multiple UTXOs on an address, this consolidates them into one output. Privacy is preserved because this doesn't comingle any addresses.
   Furthermore, the option is given to allow for a random delay of 5 to 15 minutes between transaction submissions, so the transactions don't show up as a burst, but are metered over time, likely no more than one per block.
3) The standard minimum amount of UTXOs being consolidated is 5, but can be altered using the -np command line option
4) The maximum amount of UTXOs being consolidated on a single address is 400.

### Prerequisites
 - Linux OS
 - `bc` and `jq` installed
 - at least the configured `config` file from https://github.com/alexenglish/VerusExtras

### Usage
`./consolidator.sh [options]`
##### Options:
`-max # || --maximum-size #`  :The maximum UTXO size to include in the consolidation. (default 2500).4
`-np    || --no-privacy`      : Do not delay between consolidating multiple addresses, finishing quickly, but also creating the possibility of correlating the addresses based on time.
`-mu #  || --minimum-utxos #` :The minimum number of UTXOs to include in the consolidation. (default 5).

# Scripts currently only usable on testnet
## launch-pbaas-chains.sh
### Description
Scans the running `vrsctest` chain for PBaaS chains and starts them if they are not running yet

### Prerequisites
 - Linux OS
 - `jq` installed
 - `vrsctest` chain running and synchronized
 - user and locations configured in the script file
 - `root` access

### Usage
`./launch-pbaas-chains.sh` as `root` user.

### notice
Very basic script, no sanity checks.

## verus-ufw.sh
### Description
Checks the `ufw` for previously created rules by this script and removes them, then scans the main chain (`vrsctest`) for defined PBaaS chains, tries to get each chains info and if 
successful, use that info to open the P2P port for that chain.

### Prerequisites
  - Linux OS
  - `ufw` firewall installed (standard linux)
  - `jq` installed
  - chains running
  - user and locations configured in the script file
  - `root` access

### Usage
`./verus-ufw.sh` as `root` user.

### notice
Very basic script, no sanity checks.


# DISCLAIMER
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notices and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
