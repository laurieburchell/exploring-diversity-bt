#!/bin/bash
set -eo pipefail
# author: laurie
# usage: 'submit-parallel-only-ensembles.sh'
# submits ensembles of En to/from Tr and En to/from Is models to the cluster

if [ $# -ne 1 ]; then 
    echo "usage is 'bash submit-parallel-only-ensembles.sh ddMMyy'"
    exit 1
fi

TODAY=$1

for langs in entr tren enis isen; do
    SRC=${langs:0:2}; TRG=${langs:2:4}
    echo "submitting $SRC to $TRG parallel-only models"
    for rand in 26472 33934 65483 89473; do 
        sbatch cluster-scripts/submit-parallel-only.slurm $SRC $TRG $rand $TODAY; 
    done
done

echo "all models submitted."
