# Verus-CLI-tools


##Content
 - `auto-verus.sh`

### auto-verus.sh
##### Description
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
##### Prerequisites
 - Linux OS
 - `curl` and `jq` installed
##### Usage
 - Execute `auto-verus.sh`. Command line parameters are ignored.


## DISCLAIMER
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notices and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
