#!/bin/bash
set -eo pipefail
# author: laurie
# usage: 'bash submit-backtranslation-jobs.sh DATA DICT_DIR MODEL1 MODEL2 MODEL3 MODEL4'
# shards and back-translates monolingual data

SCRIPT_DIR=`pwd`
DATA=$1
DICT_DIR=$2
MODEL1=$3
MODEL2=$4
MODEL3=$5
MODEL4=$6
LANGS=${DICT_DIR##*enc-}
SRC=${LANGS:0:2}
TRG=${LANGS:2:2}
BT_DIR="/rds/user/$USER/hpc-work/datasets/back-translation"
OUT_DIR=${BT_DIR}/${SRC}${TRG}

if [ $# -ne 6 ]; then
    echo "usage is 'bash $0 DATA DICT_DIR MODEL1 MODEL2 MODEL3 MODEL4'"
    exit 1
fi

# make dirs and symlinks
mkdir -p $OUT_DIR
cd ../datasets
test -L back-translation || ln -s $BT_DIR
echo "will translate $DATA from $SRC to $TRG, saving result in $OUT_DIR"

# shard data
test -s $OUT_DIR/mono.9M.$SRC || pigz -dc $DATA > $OUT_DIR/mono.9M.$SRC
cd $OUT_DIR
test -s mono.shard.${SRC}09 || split -d -n l/10 mono.9M.$SRC mono.shard.$SRC
pigz mono.9M.$SRC

# back-translate each shard
cd $SCRIPT_DIR
for shard in $OUT_DIR/mono.shard.$SRC*; do
    for type in beam sampling nucleus; do
        INPUT_NAME=${shard##*/}
        OUT="$OUT_DIR/$type/$INPUT_NAME-$type-bt.${TRG}.gz"
        if ! [ -s $OUT ]; then
            echo "submitting back-translation of $shard with $type diversity"
            sbatch cluster-scripts/submit-translate-mono.slurm \
                $shard \
                $DICT_DIR \
                $MODEL1 \
                $MODEL2 \
                $MODEL3 \
                $MODEL4 \
                $type
        else
            echo "$OUT already exists"
        fi
    done
done

echo "submitted all back-translation jobs for shards"
