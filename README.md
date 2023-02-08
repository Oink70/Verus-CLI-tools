# Verus-CLI-tools
A collection of scripts to simplify life on CLI.
These tools are tested on Linux Ubuntu 20.04LTS, Debian 10 and Debian 11
Some of these scripts are based on code written by Alex English (https://github.com/alexenglish/VerusExtras)

## Content suitable for mainnet:
 - `auto-verus.sh`: install or upgrade Verus binaries
 - `start-verus.sh`: Start Verus with fork and height checks
 - `stake-tracker.sh`: Counts all stakes in the past 24 hours. Differntiates between orphans and successful stakes.
 - `consolidate.sh`: consolidates UTXOs in your wallet below the treshold value.
 - `PoW-rewards.sh`: Shows how many mining block rewards addresses got over a specified time frame.
 - `PoS-rewards.sh`: Shows how many staking block rewards addresses got over a specified time frame.
 - `PoS-addresses.sh`: Shows how many staking transactions staking address got over a specified time frame.
 - `Address-delta.sh`: Shows the balance change between two dates for a single address.
 - `monitor-addresses.sh`: Meant to be run from `-blocknotify=`. Monitors transactions **from** addresses.
 - `monitor-VerusID.sh`: Meant to be run from `-blocknotify=`. Monitors VerusID updates/creations.
 - `crawl-VerusID.sh`: crawl a predefined range of blocks on the chain for VerusID updates/creations.
 - `block-stats`: retrieves some key statistics from the chain over a specified time frame.
## content only usable on testnet:
 - `launch-pbaas-chains.sh`: launches all PBaaS chains known on the VRSCTEST network.
 - `verus-ufw.sh`: Opens UFW ports for all testnet chains that are running.
 - `check-notarizations.sh`: Checks the notarization heights of PBaaS chains.

## auto-verus.sh
### Description
1) if no `verusd` binary is found in the path or local folder:
  - Download the latest official version from the VerusCoin Github repository, based on OS and processor architecture (yes, it works on ARM-linux as well).
  - Check the download using SHA256.
  - Start the Verus wallet (CLI), instructing it to download and install the network parameters and bootstrap.
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
  - start the Verus wallet (CLI) with `-bootstrap -zapwallettxes=2 -rescan` options

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
4) The maximum amount of UTXOs being consolidated on a single transaction is set to 250. The script will create multiple transactions if needed.

### Prerequisites
 - Linux OS
 - `bc` and `jq` installed
 - at least the configured `config` file from https://github.com/alexenglish/VerusExtras
 - a running `Verusd` daemon

### Usage
`./consolidate.sh [options]`
##### Options:
 - `-max # || --maximum-size #`  : The maximum UTXO size to include in the consolidation. (default 2500).4
 - `-np    || --no-privacy`      : Do not delay between consolidating multiple addresses, finishing quickly, but also creating the possibility of correlating the addresses based on time.
 - `-mu #  || --minimum-utxos #` : The minimum number of UTXOs to include in the consolidation. (default 5).
 - `-h     || --help`            : Displays help text on the console.

## PoW-rewards.sh
### Description
Shows how many mining block rewards addresses got over a specified time frame. It uses the `sed` filter file `KnownPoolAddresses.sed` by default to identify known addresses.

### Prerequisites
 - Linux OS
 - `bc` and `jq` installed
 - `KnownPoolAddresses.sed` file in the script folder
 - The `verus` binary in the PATH environment. If not found it falls back to the location of the `verus` binary is set on line 9 of the script.
 - a running `Verusd` daemon with the `-insightexplorer` option.

### Usage
`./PoW-rewards.sh [options]`
##### Options:
 - `-t # || --time-window #`     : Set an arbitrary time window (default 24hours). This amount will be deducted from the end date to determine the start date.
                                   Requires #minute/#hour/#day/#week/#month/#year.
 - `-s # || --start #`           : Set a start date (00:00 UTC). Overrides the time window. Requires time in YYYY-MM-DD format.
 - `-e # || --end #`             : Set an end date (00:00 UTC). if not set, it uses the current time. Requires time in YYYY-MM-DD format.
 - `-t # || --filter-file #`     : Specify a custum filterfile for the sed function to identify known addresses.
 - `-h   || --help`              : Displays help text on the console.

## PoS-rewards.sh
### Description
Shows how many staking block rewards addresses got over a specified time frame. It uses the `sed` filter file `KnownStakingAddresses.sed` by default to identify known addresses.

### Prerequisites
 - Linux OS
 - `bc` and `jq` installed
 - `KnownStakingAddresses.sed` file in the script folder
 - The `verus` binary in the PATH environment. If not found it falls back to the location of the `verus` binary is set on line 9 of the script.
 - a running `Verusd` daemon with the `-insightexplorer` option.

### Usage
`./PoW-rewards.sh [options]`
##### Options:
 - `-t # || --time-window #`     : Set an arbitrary time window (default 24hours). This amount will be deducted from the end date to determine the start date.
                                   Requires #minute/#hour/#day/#week/#month/#year.
 - `-s # || --start #`           : Set a start date (00:00 UTC). Overrides the time window. Requires time in YYYY-MM-DD format.
 - `-e # || --end #`             : Set an end date (00:00 UTC). if not set, it uses the current time. Requires time in YYYY-MM-DD format.
 - `-t # || --filter-file #`     : Specify a custum filterfile for the sed function to identify known addresses.
 - `-h   || --help`              : Displays help text on the console.

## PoS-addresses.sh
### Description
Shows addresses that are responsible for staked blocks over a specific period of time. It uses the `sed` filter file `KnownStakingAddresses.sed` by default to identify known addresses.

### Prerequisites
 - Linux OS
 - `bc` and `jq` installed
 - `KnownStakingAddresses.sed` file in the script folder
 - The `verus` binary in the PATH environment. If not found it falls back to the location of the `verus` binary is set on line 9 of the script.
 - a running `Verusd` daemon with the `-insightexplorer` option.

### Usage
`./PoW-rewards.sh [options]`
##### Options:
 - `-t # || --time-window #`     : Set an arbitrary time window (default 24hours). This amount will be deducted from the end date to determine the start date.
                                   Requires #minute/#hour/#day/#week/#month/#year.
 - `-s # || --start #`           : Set a start date (00:00 UTC). Overrides the time window. Requires time in YYYY-MM-DD format.
 - `-e # || --end #`             : Set an end date (00:00 UTC). if not set, it uses the current time. Requires time in YYYY-MM-DD format.
 - `-t # || --filter-file #`     : Specify a custum filterfile for the sed function to identify known addresses.
 - `-h   || --help`              : Displays help text on the console.

## Address-delta.sh
Shows the balance difference between two timepoints

### Prerequisites
 - Linux OS
 - `bc` and `jq` installed
 - The `verus` binary in the PATH environment. If not found it falls back to the location of the `verus` binary is set on line 9 of the script.
 - a running `Verusd` daemon with the `-insightexplorer` option.

### Usage
`./Address-delta.sh [options]`
##### Options:
 - `-a # || --address #`         : (MANDATORY) specify an address to use.
 - `-t # || --time-window #`     : Set an arbitrary time window (default 24hours). This amount will be deducted from the end date to determine the start date.
                                   Requires #minute/#hour/#day/#week/#month/#year.
 - `-s # || --start #`           : Set a start date (00:00 UTC). Overrides the time window. Requires time in YYYY-MM-DD or "YYYY-MM-DD hh:mm:ss" format.
 - `-e # || --end #`             : Set an end date (00:00 UTC). if not set, it uses the current time. Requires time in YYYY-MM-DD or "YYYY-MM-DD hh:mm:ss" format.
 - `-h   || --help`              : Displays help text on the console.

## monitor-addresses.sh
This script is meant to be run using the verusd `-blocknotify=/path/monitor-addresses.sh %s` option.
The script takes blockhash or blockheight as input, checks that block for transactions made from addresses
that are specified in the file on line 11 of the script (The address file is **not** included).
If a send is detected from a monitored address it will send a message using the webhook to discord,
including the blocktime, blockheight, TXID and address(es) that matched.

### Prerequisites
 - Linux OS
 - `jq` installed
 - The `verus` binary in the PATH environment. If not found it falls back to the location of the `verus` binary is set on line 15 of the script.
 - A webhook for discord.
 - An address file (text file with one address per line).

### Usage
 - `./address-monitor.sh 2234624`
 - `./address-monitor.sh 000000000008263f8382f888aeb50e60470f0878fa6d77b549e7e2505a5e0a30`
 - `verusd -blocknotify=/path/address-monitor.sh %s`

## monitor-VerusID.sh
This script is meant to be run using the verusd `-blocknotify=/path/monitor-addresses.sh %s` option.
The script takes blockhash or blockheight as input, checks that block for Identity update transactions.
By default it writes the ID-name and i-address to a file specified at line 11 of the script, but the
section that takes action has a remark indicating it is the "action" section, so anyone can adjust
this script to their desires.

### Prerequisites
 - Linux OS
 - `jq` installed
 - The `verus` binary in the PATH environment. If not found it falls back to the location of the `verus` binary is set on line 15 of the script.

### Usage
 - `./monitor-VerusID.sh 2234624`
 - `./monitor-VerusID.sh 000000000008263f8382f888aeb50e60470f0878fa6d77b549e7e2505a5e0a30`
 - `verusd -blocknotify=/path/monitor-VerusID.sh %s`

## crawl-VerusID.sh
The script uses a range of blocks from lines 14-15 and checks that range for Identity update transactions.
By default it writes the ID-name and i-address to a file specified at line 10 of the script, but the
section that takes action has a remark indicating it is the "action" section, so anyone can adjust
this script to their desires.
Since crawling large numbers of blocks is a time-consuming action, a block counter will be displayed in the terminal.

### Prerequisites
 - Linux OS
 - `jq` installed
 - The `verus` binary in the PATH environment. If not found it falls back to the location of the `verus` binary is set on line 15 of the script.

### Usage
 - `./crawl-VerusID.sh` (command line options are ignored)

## block-stats.sh
Shows statistics about difficulty (max/avg/min), hashrate (max/avg/min), amount of blocks (total/PoW/PoS), Rewards (Total/PoW/PoS), Fees (Total/PoW/PoS).

### Prerequisites
- Linux OS
- `bc` and `jq` installed
- `KnownStakingAddresses.sed` file in the script folder
- The `verus` binary in the PATH environment. If not found it falls back to the location of the `verus` binary is set on line 9 of the script.
- a running `Verusd` daemon with the `-insightexplorer` option.

### Usage
`./block-stats.sh [options]`
##### Options:
 - `-a # || --address #`         : (MANDATORY) specify an address to use.
 - `-t # || --time-window #`     : Set an arbitrary time window (default 24hours). This amount will be deducted from the end date to determine the start date.
                                   Requires #minute/#hour/#day/#week/#month/#year.
 - `-s # || --start #`           : Set a start date (00:00 UTC). Overrides the time window. Requires time in YYYY-MM-DD or "YYYY-MM-DD hh:mm:ss" format.
 - `-e # || --end #`             : Set an end date (00:00 UTC). if not set, it uses the current time. Requires time in YYYY-MM-DD or "YYYY-MM-DD hh:mm:ss" format.
 - `-h   || --help`              : Displays help text on the console.


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

## check-notarizations.sh
### Description
Checks wich PBaaS chains are created and checks the notarization status of the running PBaas chains.

###Prerequisites
   - Linux OS
   - `jq` installed
   - at least `vrsctest` chain running
   - locations configured in the script file

### Usage
`./check-notarizations.sh`

### notice
Fairly basic script, no sanity checks.


# DISCLAIMER
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notices and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
