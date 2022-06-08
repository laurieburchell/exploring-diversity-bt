#!/bin/bash
set -eo pipefail
# author: laurie
# splits out dev sets from amongst syntax group data, then binarises ready for fairseq training
# usage: prepare-syntax-group-data.sh DATA_DIR SRC_DATA TRG_DATA OUT_SUFFIX

if [ $# -ne 4 ]; then
    echo "usage is $0 DATA_DIR SRC_DATA TRG_DATA OUT_SUFFIX"
    exit 1
fi

DATA_DIR=`realpath $1`
SRC_DATA=`realpath $2`
TRG_DATA=`realpath $3`
OUT_SUFFIX=$4
SRC=${SRC_DATA##*.}
TRG=${TRG_DATA##*.}
TRAINPREF=${SRC_DATA%.*}

echo "data dir is ${DATA_DIR}"
echo "source lang: ${SRC}, target lang: ${TRG}"

cd $DATA_DIR
mkdir -p finetuning

echo "generating dev sets"
shuf -n 500 --random-source sp/train.sp.$SRC $SRC_DATA > finetuning/dev.sp.$SRC
shuf -n 500 --random-source sp/train.sp.$SRC $TRG_DATA > finetuning/dev.sp.$TRG

# select relevant test sets
if [[ $SRC == "is" ]]; then
    TEST=$DATA_DIR/sp/newstest2021.en-is.sp,$DATA_DIR/sp/newstest2021.is-en.sp
elif [[ $SRC == "tr" ]]; then 
    TEST=$DATA_DIR/sp/newstest2016.sp,$DATA_DIR/sp/newstest2017.sp,$DATA_DIR/sp/newstest2018.sp
else
    echo "no test set found"
    exit 2
fi
echo "test sets are $TEST"

echo "binarising data for fairseq training"
test -d $DATA_DIR/finetuning/enc-$SRC$TRG-$OUT_SUFFIX || fairseq-preprocess \
    --source-lang $SRC \
    --target-lang $TRG \
    --destdir $DATA_DIR/finetuning/enc-$SRC$TRG-$OUT_SUFFIX \
    --trainpref $TRAINPREF \
    --validpref $DATA_DIR/finetuning/dev.sp \
    --testpref $TEST \
    --srcdict $DATA_DIR/enc-$SRC$TRG/dict.${SRC}.txt \
    --tgtdict $DATA_DIR/enc-$SRC$TRG/dict.${TRG}.txt \
    --workers 80 

rm $DATA_DIR/finetuning/dev.sp.{$SRC,$TRG}
