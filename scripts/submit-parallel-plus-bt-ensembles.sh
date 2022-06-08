#!/bin/bash
set -eo pipefail
# author: laurie
# usage: 'submit-parallel-plus-bt-ensembles.sh date lang-pair'
# submits ensembles of En to/from Tr or En to/from Is models to the cluster


if [ $# -ne 2 ]; then
    echo "usage is 'submit-parallel-plus-bt-ensembles.sh ddMMyy {entr|enis|tren|isen}'"
    exit 1
fi

TODAY=$1
langs=$2
DATA_DIR="/rds/user/$USER/hpc-work/datasets/parallel-plus-bt"

for div in base3M base9M beam3M sampling3M nucleus3M; do
#for div in syntax3M; do
    DATA="$DATA_DIR/$langs/$div/enc-$langs"
    echo "submitting $langs models using $div data"
    for rand in 26472 33934 65483 89473; do 
        sbatch cluster-scripts/submit-parallel-plus-bt.slurm $DATA $rand $TODAY; 
    done
done

echo "all models submitted."
