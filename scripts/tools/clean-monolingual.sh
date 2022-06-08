#!/bin/bash
set -eo pipefail
# author: patrick chen
# Usage: bash clean-monolingual.sh INPUT LANGID

# check num of args
if [ "$#" -ne 2 ]; then
	echo "Usage: bash clean-monolingual.sh INPUT.gz LANGID"
	echo "ex.: bash clean-monolingual.sh news.gz tr"
	exit 1
fi

INPUT=$1
LANG=$2
JOBS=76
PWD=`pwd`
FILENAME=${INPUT##*/}
FILENAME=${FILENAME%.gz}
OUT_DIR="/rds/user/$USER/hpc-work/datasets/monolingual-data/$LANG/clean"
TEMP=${INPUT%/*.gz}/temp

mkdir -p $TEMP

if [ $# -ne 2 ]; then
    echo "usage is 'bash clean-monolingual.sh INPUT LANG'"
    exit 1
fi

echo "will clean $INPUT; expected language is $LANG"
mkdir -p $OUT_DIR
echo "will output results to $OUT_DIR/$FILENAME.clean.gz"

# load parallel
module load parallel

# clean with moses
echo "removing non-printing characters and normalising punctuation"
test -s $TEMP/$FILENAME.phase1.gz || pigz -dc $INPUT \
    | parallel --no-notice --pipe -k -j$JOBS --block 50M \
    "perl tools/remove-non-printing-char.perl | perl tools/normalize-punctuation.perl -l $LANG" \
    | pigz > $TEMP/$FILENAME.phase1.gz

# deduplication
echo "deduping"
test -s $TEMP/$FILENAME.phase2.gz || pigz -p $JOBS -dc $TEMP/$FILENAME.phase1.gz \
    | LC_ALL=C sort -S 100G -T $TEMP -u --parallel=$JOBS \
    | pigz > $TEMP/$FILENAME.phase2.gz

# language id
echo "filtering using language ID"
test -s $TEMP/$FILENAME.phase3.gz || pigz -dc $TEMP/$FILENAME.phase2.gz \
	| parallel --no-notice --pipe -k -j$JOBS --block 50M \
    "python tools/langid-fasttext.py" \
    | grep -P "^$LANG\t" | cut -f2 \
    | pigz > $TEMP/$FILENAME.phase3.gz

echo "applying rule-based filters"
test -s $OUT_DIR/$FILENAME.clean.gz || pigz -dc $TEMP/$FILENAME.phase3.gz \
   | parallel --no-notice --pipe -k -j$JOBS --block 50M \
   "python tools/clean-monolingual.py -l $LANG --debug" 2> $INPUT.clean.debug.txt \
   | pigz > "$OUT_DIR/$FILENAME.clean.gz"

echo "cleaning complete for $FILENAME"
