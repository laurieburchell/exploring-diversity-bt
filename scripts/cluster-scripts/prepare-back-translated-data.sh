#!/bin/bash
set -eo pipefail
# author: laurie
# usage: 'prepare-back-translated-data.sh SHARD_DIR TYPE SRC TRG'
# creates back-translation + parallel corpus for training NMT models

SCRIPT_DIR=`pwd`
SHARD_DIR=$1
TYPE=$2
SRC=$3
TRG=$4
DATA_DIR="/rds/user/cs-burc1/hpc-work/datasets/parallel-plus-bt"
OUT_DIR="$DATA_DIR/$SRC$TRG"
BT_OUT="mono.$TYPE-$TRG-bt.$SRC"
SPM="$SCRIPT_DIR/tools/sentencepiece/build/src"

if [ $# -ne 4 ]; then
    echo "usage: 'bash prepare-back-translated-data.sh SHARD_DIR TYPE SRC TRG'"
    exit 1
fi

# make dirs and symlinks
mkdir -p $OUT_DIR
cd ../datasets
test -e parallel-plus-bt || ln -s $DATA_DIR
cd $SCRIPT_DIR

# pull out orig sents from shards, triple, and recombine
if ! [ -e $OUT_DIR/mono.${TYPE}.${TRG} ]; then
    for shard in $SHARD_DIR/*full.gz; do
        echo "extracting original sent from $shard"
        pigz -dc $shard | grep "^S-" | cut -f2 \
            | awk '{print $0; print $0; print $0}' >> $OUT_DIR/mono.$TYPE.$TRG
        # pull out back-translated sents from shards, filter to three, and recombine
        if [ "$TYPE" = "beam" ]; then
            echo "extracting back-translation from $shard (beam)"
            pigz -dc $shard | grep "^D-" | cut -f3 \
            >> $OUT_DIR/$BT_OUT
        else
            echo "extracting back-translation from $shard ($TYPE)" 
            pigz -dc $shard | grep "^D-" \
                | awk 'BEGIN{FS="\t"} ( NR%5==1 || NR%5==2 || NR%5==3 ) {$1=$2=OFS=""; print $0}' \
                 >> $OUT_DIR/$BT_OUT
        fi
    done
fi

# sentencepiece encode mono and back-translation
if [[ ( "$SRC" = "tr" ) || ( "$TRG" = "tr" ) ]]; then
    SPM_MODEL="/rds/user/cs-burc1/hpc-work/datasets/parallel-data/tr-en/sp/tren-sp.model"
    PARALLEL_DIR="/rds/user/$USER/hpc-work/datasets/parallel-data/tr-en/sp"
    TRAIN=train.sp
    DEV=newsdev2016.sp
    TEST=newstest2016.sp,newstest2017.sp,newstest2018.sp
elif [[ ( "$SRC" = "is" ) || ( "$TRG" = "is" ) ]]; then
    SPM_MODEL="/rds/user/cs-burc1/hpc-work/datasets/parallel-data/is-en/sp/isen-sp.model"
    PARALLEL_DIR="/rds/user/$USER/hpc-work/datasets/parallel-data/is-en/sp"
    TRAIN=train.sp
    DEV=newsdev2021.sp
    TEST=newstest2021.en-is.sp,newstest2021.is-en.sp
else
    echo "invalid language combination, quitting"
    exit 2
fi
for data in $OUT_DIR/mono.$TYPE.$TRG $OUT_DIR/$BT_OUT; do
    echo "sentencepiece encoding $data"
    test -s ${data}.sp || $SPM/spm_encode --model $SPM_MODEL < $data > ${data}.sp
done

cd $OUT_DIR
pigz -d $PARALLEL_DIR/*dev* $PARALLEL_DIR/*test*
# make relevant dirs and symlinks to dev and test
if [[ "$TYPE" = "beam" ]]; then
    DIRS="base3M base9M beam3M"
elif [[ "$TYPE" = "sampling" ]]; then
    DIRS="sampling3M"
elif [[ "$TYPE" = "nucleus" ]]; then
    DIRS="nucleus3M"
elif [[ "$TYPE" = "syntax" ]]; then
    DIRS="syntax3M"
else 
    echo "invalid type. quitting."
    exit 2
fi
for dir in $DIRS; do
    mkdir -p $dir
    for l in $SRC $TRG; do
        test -e $dir/$DEV.$l || ln -s $PARALLEL_DIR/$DEV.$l $dir/$DEV.$l    
        for t in ${TEST//,/ }; do
            test -e $dir/$t.$l || ln -s $PARALLEL_DIR/$t.$l $dir/$t.$l
        done
    done
done

# make training data - beam also makes up baselines so we have extra step
if [[ "$TYPE" = "beam" ]]; then
    echo "preparing data for 9M baseline"
    # take first line of each back-translated triple
    test -s mono.baseline.${SRC}-bt.sp || awk 'NR%3==1' ${OUT_DIR}/${BT_OUT}.sp \
        > mono.baseline.$SRC-bt.sp
    # cut back-translated data to 9M lines
    test -s mono.baseline.9M.${SRC}-bt.sp || head -n 9000000 mono.baseline.$SRC-bt.sp \
        > mono.baseline.9M.${SRC}-bt.sp
    # concat parallel source data with baseline backtrans
    test -s base9M/train.sp.${SRC} || pigz -dc $PARALLEL_DIR/train.sp.${SRC}.gz \
        | cat - mono.baseline.9M.${SRC}-bt.sp > base9M/train.sp.${SRC}
    # pull every third like from beam to make target monolingual
    test -s mono.baseline.${TRG}.sp || awk 'NR%3==1' mono.${TYPE}.${TRG}.sp \
        > mono.baseline.${TRG}.sp
    # trim target mono to 9M
    test -s mono.baseline.9M.${TRG}.sp || head -n 9000000 mono.baseline.${TRG}.sp \
        > mono.baseline.9M.${TRG}.sp
    # concat parallel target data with mono
    test -s base9M/train.sp.${TRG}.gz || pigz -dc $PARALLEL_DIR/train.sp.${TRG}.gz \
        | cat - mono.baseline.9M.${TRG}.sp > base9M/train.sp.${TRG}
    echo "preparing data for 3M baseline"
    # trim off 6M from 9M baseline to make 3M baseline
    for l in $SRC $TRG; do 
        test -s base3M/train.sp.$l.gz || head -n -6000000 base9M/train.sp.$l > base3M/train.sp.$l
    done
fi
# prepare beam, sampling, and nucleus
echo "preparing data for ${TYPE}3M"
if ! [ -s ${TYPE}3M/train.sp.$SRC.gz ]; then
    pigz -dc $PARALLEL_DIR/train.sp.${SRC}.gz > ${TYPE}3M/train.sp.$SRC
    head -n 9000000 ${OUT_DIR}/${BT_OUT}.sp  >> ${TYPE}3M/train.sp.$SRC
fi
if ! [ -s ${TYPE}3M/train.sp.$TRG.gz ]; then
    pigz -dc $PARALLEL_DIR/train.sp.${TRG}.gz > ${TYPE}3M/train.sp.$TRG
    head -n 9000000 mono.${TYPE}.${TRG}.sp >> ${TYPE}3M/train.sp.$TRG 
fi

# binarise data for faster training
for dir in $DIRS; do
    cd ${OUT_DIR}/$dir
    echo "binarising data in $dir"
    test -d enc-${SRC}${TRG} || fairseq-preprocess \
        --source-lang $SRC \
        --target-lang $TRG \
        --destdir enc-${SRC}${TRG} \
        --trainpref $TRAIN \
        --validpref $DEV \
        --testpref $TEST \
        --joined-dictionary \
        --workers 20
    pigz train.sp*
done

echo "script finished"
