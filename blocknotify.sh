#!/bin/bash
## © Oink 2023
## This script forwards the blockhash received through the verus
## `-blocknotify=` option to the scripts specified in the text file
## specified on line 11.
## Using this "in-between" script allows calling multiple scripts
## to do whatever they do on blocknotification and process those scripts
## in parallel.


SCRIPTS=/home/verus/bin/scripts
BLOCKHASH="$1"

xargs -P $(nproc) -a "$SCRIPTS" -I{} bash {} "$BLOCKHASH"
