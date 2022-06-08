#!/bin/bash
set -eo pipefail
# usage: bash train-turkish-model.sh $SRC $TRG $DATA $PROJECT $MODEL_NAME $RND $TODAY
# author: laurie
# trains a model with the hyperparameter settings for Tr<->En

#TODAY=`date +"%d%m%y"`
SRC=$1
TRG=$2
DATA=$3
PROJECT=$4
TODAY=$7
MODEL_NAME="$5-$TODAY"
RND=$6
SCRIPT_DIR=`pwd`
MODELS_DIR="/rds/user/$USER/hpc-work/mt-models"
SAVE_DIR="$MODELS_DIR/${SRC}${TRG}/${PROJECT}"

if [ $# -ne 7 ]; then
    echo "usage is 'bash $0 SRC TRG DATA PROJECT MODEL_NAME RND ddMMyy'"
    exit 1
fi

# set up directories and symlinks
echo "model will be saved to $SAVE_DIR/$MODEL_NAME"
mkdir -p $SAVE_DIR
test -s ../models/${SRC}${TRG} || ln -s $MODELS_DIR/${SRC}${TRG} ../models/$SRC$TRG

# train models
echo "Source lang: $SRC, target lang: $TRG"
echo "Training model on data in $DATA"
echo "Model name is $MODEL_NAME"
echo "Random seed is $RND"

fairseq-train $DATA \
    --arch transformer \
    --batch-size 64 \
    --optimizer adam \
    --adam-betas '[0.9,0.98]' \
    --lr 0.001 \
    --lr-scheduler inverse_sqrt \
    --warmup-updates 3000 \
    --criterion label_smoothed_cross_entropy \
    --label-smoothing 0.1 \
    --no-epoch-checkpoints \
    --save-dir $SAVE_DIR/$MODEL_NAME \
    --log-file ../logs/${MODEL_NAME}.log \
    --task translation \
    --share-all-embeddings \
    --dropout 0.6 \
    --activation-dropout 0.1 \
    --attention-dropout 0.1 \
    --activation-fn relu \
    --wandb-project $PROJECT \
    --update-freq 16 \
    --seed $RND \
    --patience 15

echo "training done"
exit 0
