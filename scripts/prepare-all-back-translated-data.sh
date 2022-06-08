#!/bin/bash
set -eo pipefail
# author: laurie
# usage: 'prepare-all-back-translated-data.sh SRC TRG'
# get all flavours of back-translation prepared into training corpora

SCRIPT_DIR=`pwd`
SRC=$1
TRG=$2

if [ $# -ne 2 ]; then
    echo "usage: 'prepare-all-back-translated-data.sh FINAL_SRC FINAL_TRG'"
    exit 1
fi

#for div in beam sampling nucleus; do
for div in sampling nucleus; do
    bash cluster-scripts/prepare-back-translated-data.sh \
        ../datasets/back-translation/$TRG$SRC/$div $div $SRC $TRG
done 
