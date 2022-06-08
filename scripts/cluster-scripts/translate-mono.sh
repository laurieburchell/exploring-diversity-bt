#!/bin/bash
set -eo pipefail
# author: laurie
# usage: 'bash translate-mono.sh DATA DICT_DIR MODEL1 MODEL2 MODEL3 MODEL4 TYPE'
# uses ensemble to translate monolingual corpus

DATA=$1
DICT_DIR=$2
MODEL1=$3
MODEL2=$4
MODEL3=$5
MODEL4=$6
TYPE=$7
BATCH=128
LANGS=${DICT_DIR##*enc-}
SRC=${LANGS:0:2}
TRG=${LANGS:2:2}
BT_DIR="/rds/user/$USER/hpc-work/datasets/back-translation"
OUT_DIR=${BT_DIR}/${LANGS}/$TYPE
INPUT_NAME=${DATA##*/}
OUT=${OUT_DIR}/${INPUT_NAME}-$TYPE-bt.${TRG}

if [ $# -ne 7 ]; then
    echo -e "usage: 'bash $0 DATA DICT_DIR MODEL1 MODEL2 MODEL3 MODEL4 TYPE'"
    exit 1
fi

mkdir -p $OUT_DIR
echo "will translate $DATA from $SRC to $TRG, saving result in $OUT_DIR"

if [[ "$TYPE" == "beam" ]]; then
    ARGS="--nbest 3"
elif [[ "$TYPE" == "sampling" ]]; then 
    ARGS="--nbest 5 --sampling"
elif [[ "$TYPE" == "nucleus" ]]; then
    ARGS="--nbest 5 --sampling --sampling-topp 0.95" 
elif [[ "${TYPE:0:6}" == "syntax" ]]; then
    ARGS=""
else
    echo "unrecognised generation method"
    exit 2
fi
echo "diversity type is $TYPE"

fairseq-interactive $DICT_DIR \
    --input $DATA \
    --path $MODEL1:$MODEL2:$MODEL3:$MODEL4 \
    --buffer-size $BATCH \
    --batch-size $BATCH \
    --beam 5 \
    --truncate-source \
    --remove-bpe=sentencepiece \
    --skip-invalid-size-inputs-valid-test \
    $ARGS \
    > $OUT-full

echo "compressing output file"
pigz $OUT-full

echo "back-translation finished"
