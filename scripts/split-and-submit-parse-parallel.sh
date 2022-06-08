#!/bin/bash
# author: laurie
# usage: split-and-submit-parse-parallel.sh {tr|is}
# splits English side of parallel data and submits each shard for parsing 

if [ $# -ne 1 ]; then
    echo "usage is 'bash $0 {tr|is}'"
    exit 1
fi

INPUT_DIR="/rds/user/${USER}/hpc-work/datasets/parallel-data/${1}-en"
INPUT="$INPUT_DIR/clean/train.clean.en.gz"

# split input file into chunks for parsing
mkdir -p $INPUT_DIR/parsed
echo "splitting $INPUT into shards"
pigz -dc $INPUT | split -l 100000 -d - $INPUT_DIR/parsed/train.en.chunk 

# submit parse jobs
for file in $INPUT_DIR/parsed/train.en.chunk*; do
    ext="${file##*.}"
    if [[ "$ext" != "cfg" && "$ext" != "gz" ]]; then
        test -s "${file}.cfg" || sbatch cluster-scripts/submit-parse-shard.slurm $file
        echo "submitted $file for parsing"
    fi
done

echo "all shards submitted for parsing"
