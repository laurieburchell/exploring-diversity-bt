#!/bin/bash
# author: laurie
# combines parsed shards into one dataset
# usage: 'bash combine-parsed-shards.sh SHARD_DIR'

if [ $# -ne 1 ]; then
    echo "usage is 'bash $0 SHARD_DIR'"
    exit 1
fi

SHARD_DIR=$1

cd $SHARD_DIR
echo "changed dir to $SHARD_DIR"
echo "combining shards in train.en.combo.cfg"
cat *.cfg > train.en.combo.cfg

echo "removing shards"
for file in *chunk*; do 
    if [[ ${file##*.} != "cfg" ]]; then
        rm $file
    fi
done

echo "compressing parsed shards"
pigz *chunk*
echo "script finished"
