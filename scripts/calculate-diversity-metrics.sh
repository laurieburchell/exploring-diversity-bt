#!/bin/bash
set -eo pipefail
# author: laurie
# usage: calculate-diversity-metrics.sh $INPUT_DATA 
# calculates diversity metrics over a back-translated corpus of triples

if [ $# -ne 4 ]; then
    echo "usage is bash calculate-diversity-metrics.sh INPUT_DATA LANG-FROM-LANG CORPUS_SIZE TYPE"
    exit 1
fi

DATA=`readlink -f $1`
LANG=$2
CORPUS_SIZE=$3
TYPE=$4

TODAY=`date +"%d%m%y-%H%M"`
SUBMIT_DIR=`pwd`
FILENAME=`basename $DATA`; FILENAME=${FILENAME%.gz}
RDS_DIR="/rds/user/$USER/hpc-work/datasets/diversity-metrics"
OUTPUT_DIR="$RDS_DIR/$LANG/$TYPE"
TMPDIR=$OUTPUT_DIR
OUTPUT_FILE="$OUTPUT_DIR/$FILENAME.$TODAY.stats"

# make dirs and symlinks
mkdir -p $OUTPUT_DIR
cd ..; test -L diversity-metrics || ln -s $RDS_DIR
cd $SUBMIT_DIR
echo "will output results to $OUTPUT_DIR"

echo "input data is $DATA" | tee -a $OUTPUT_FILE
echo "expected language is $LANG" | tee -a $OUTPUT_FILE
echo "corpus size is $CORPUS_SIZE" | tee -a $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# trim data file to corpus size
if [ ! -s $OUTPUT_DIR/$FILENAME.gz ]; then
    echo "trimming $FILENAME to corpus size for calculating metrics"
    pigz -dc $DATA > $OUTPUT_DIR/data
    head -n $CORPUS_SIZE $OUTPUT_DIR/data > $OUTPUT_DIR/$FILENAME
    rm $OUTPUT_DIR/data
    pigz $OUTPUT_DIR/$FILENAME
fi

# calculate vocab size (case insensitive)
VOCAB_FILE="$OUTPUT_DIR/$FILENAME.vocab"
if [ ! -s $VOCAB_FILE.gz ]; then
    echo "calculating vocab size" 
    pigz -dc $OUTPUT_DIR/$FILENAME.gz \
        | tr ' [:upper:]' '\n[:lower:]' \
        | tr -d '[:punct:]' \
        | sort -u --parallel=70 \
        > $VOCAB_FILE
    VOCAB_SIZE=$(cat $VOCAB_FILE | wc -l)
    pigz $VOCAB_FILE
else
    VOCAB_SIZE=$(pigz -dc $VOCAB_FILE.gz | wc -l)
fi
echo "vocab size is ${VOCAB_SIZE}" | tee -a $OUTPUT_FILE

# calculate average word and sentence length (wc definition)
echo "calculating average word and sentence length"
WC_OUT=$(pigz -dc $OUTPUT_DIR/$FILENAME.gz | wc)
L=$(echo $WC_OUT | cut -f1 -d ' ')
W=$(echo $WC_OUT | cut -f2 -d ' ')
C=$(echo $WC_OUT | cut -f3 -d ' ')
AV_WORD_LEN=`echo "${C} / ${W}" | bc -l`
AV_SENT_LEN=`echo "${W} / ${L}" | bc -l`
echo "mean word len: $AV_WORD_LEN; mean sent len: $AV_SENT_LEN" \
    | tee -a $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

if [[ "${TYPE:0:4}" == "base" ]]; then
    echo "all metrics calculated for base"
    exit 0
fi

# calculate intersent metrics
pigz -d $OUTPUT_DIR/$FILENAME.gz
python tools/calculate-intersent-metrics.py $OUTPUT_DIR/$FILENAME $OUTPUT_DIR $OUTPUT_FILE
pigz $OUTPUT_DIR/$FILENAME

# calcualte tree metrics
if [ ${LANG:0:2} == "en" ]; then
    bash tools/calculate-tree-kernel.sh $OUTPUT_DIR/$FILENAME.sample $OUTPUT_DIR $OUTPUT_FILE
    pigz $OUTPUT_DIR/*.tsv; pigz $OUTPUT_DIR/*sample*
fi

echo "script finished."
