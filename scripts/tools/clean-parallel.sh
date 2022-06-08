#!/bin/bash

# Usage: bash clean-parallel.sh FILE1 LANGID1 FILE2 LANGID2

set -eo pipefail

# check num of args
if [ "$#" -ne 4 ]; then
	echo "Usage: bash clean-parallel.sh FILE1.gz LANGID1 FILE2.gz LANGID2"
	echo "ex.: bash clean-parallel.sh news.tr.gz tr news.en.gz en"
	exit 1
fi

# assign args
FILE_SRC=$1
SRC=$2
FILE_TRG=$3
TRG=$4
LID="tools/langid-fasttext.py"
RB_FILTER="tools/clean-parallel.py"
echo "will clean parallel files $FILE_SRC (expected lang: $SRC) and $FILE_TRG (expected lang: $TRG)"

# check files and folders exist
test -s $FILE_SRC || exit 2 
test -s $FILE_TRG || exit 3 
test -s $LID || exit 5
test -s $RB_FILTER || exit 6
echo "all expected files found"

# load parallel
module load parallel

# clean with moses
echo "removing non-printing characters and normalising punctuation with moses"
test -s $FILE_SRC.phase1.gz || pigz -dc $FILE_SRC \
	| parallel --no-notice --pipe -k -j32 --block 50M "perl tools/remove-non-printing-char.perl | perl tools/normalize-punctuation.perl -l $SRC" \
	| pigz > $FILE_SRC.phase1.gz
test -s $FILE_TRG.phase1.gz || pigz -dc $FILE_TRG \
	| parallel --no-notice --pipe -k -j32 --block 50M "perl tools/remove-non-printing-char.perl | perl tools/normalize-punctuation.perl -l $TRG" \
	| pigz > $FILE_TRG.phase1.gz
echo "moses step complete"


# deduplication
echo "deduping"
test -s $FILE_SRC-$TRG.phase2.gz ||  paste <(pigz -dc $FILE_SRC.phase1.gz) <(pigz -dc $FILE_TRG.phase1.gz) \
        | LC_ALL=C sort -S 10G | uniq \
        | pigz > $FILE_SRC-$TRG.phase2.gz
echo "deduping done"

# language id
echo "filtering using language ID"
test -s $FILE_SRC-$TRG.phase3.gz || pigz -dc $FILE_SRC-$TRG.phase2.gz \
        | parallel --no-notice --pipe -k -j16 --block 50M "python3 $LID -f 1 | python3 $LID -f 1" \
        | grep -P "^$SRC\t$TRG\t" \
        | cut -f3,4 \
        | pigz > $FILE_SRC-$TRG.phase3.gz
echo "lang ID filter done"

echo "applying rule-based filters"
# rule-based filtering - uses clean-parallel.py
test -s $FILE_SRC-$TRG.clean.gz || pigz -dc $FILE_SRC-$TRG.phase3.gz \
        | parallel --no-notice --pipe -k -j16 --block 50M "python3 $RB_FILTER -l1 $SRC -l2 $TRG --debug" \
        2> $FILE_SRC-$TRG.clean.debug.txt \
        | pigz > $FILE_SRC-$TRG.clean.gz
echo "rule-based filters complete. splitting parallel file into source and target."
test -s $FILE_SRC.clean.gz || pigz -dc $FILE_SRC-$TRG.clean.gz | cut -f1 | pigz > $FILE_SRC.clean.gz
test -s $FILE_TRG.clean.gz || pigz -dc $FILE_SRC-$TRG.clean.gz | cut -f2 | pigz > $FILE_TRG.clean.gz
echo "cleaning complete. intermediate phase files can be deleted."

