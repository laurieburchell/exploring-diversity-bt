#!/bin/bash

# usage: sbatch submit-parallel-only.slurm $SRC $TRG $RND
# author: laurie
# submits parallel-only training script to the cluster

#SBATCH -J parallel-nmt
#SBATCH -A NLP-CDT-SL2-GPU
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:4
#SBATCH --time=36:00:00
#SBATCH --output="/home/%u/logs/parallel-only_%A.out"
#SBATCH --error="/home/%u/logs/parallel-only_%A.err"
#SBATCH -p ampere
#SBATCH --array=1-2%1

. /etc/profile.d/modules.sh 
module purge               
module load rhel7/default-gpu   
module load nccl/2.4.2-cuda10.0
module load miniconda/3

# get conda working
source ~/.bashrc
conda activate diversity

if [ $# -ne 4 ]; then
    echo "usage: sbatch $0 SRC TRG RND ddMMyy"
    exit 1
fi

# set up vars
PWD=`pwd`
SRC=$1
TRG=$2
RND=$3
TODAY=$4

# change script depending on lang
echo "source is $SRC"
echo "target is $TRG"
if [[ ( "$SRC" = "tr" ) || ( "$TRG" = "tr" ) ]]; then
    DATA="../datasets/parallel-data/tr-en/enc-$SRC$TRG"
    echo "will train on dataset $DATA"
    SCRIPT="cluster-scripts/train-turkish-model.sh"
    echo "script to run is $SCRIPT"
elif [[ ( "$SRC" = "is" ) || ( "$TRG" = "is" ) ]]; then
    DATA="../datasets/parallel-data/is-en/enc-$SRC$TRG"
    echo "will train on dataset $DATA"
    SCRIPT="cluster-scripts/train-icelandic-model.sh"
    echo "script to run is $SCRIPT"
else
    echo "invalid language selection; quitting."
    exit 1
fi
PROJECT="${SRC}${TRG}-parallel-only"
echo "project is $PROJECT"
MODEL_NAME="${SRC}${TRG}-parallel-only-$RND"
echo "base model name is $MODEL_NAME"

application="bash $SCRIPT"
options="$SRC $TRG $DATA $PROJECT $MODEL_NAME $RND $TODAY"
workdir="$SLURM_SUBMIT_DIR" 
CMD="$application $options"

###############################################################
### You should not have to change anything below this line ####
###############################################################

cd $workdir
echo -e "Changed directory to `pwd`.\n"

JOBID=$SLURM_JOB_ID

echo -e "JobID: $JOBID\n======"
echo "Time: `date`"
echo "Running on master node: `hostname`"
echo "Current directory: `pwd`"
echo -e "\nExecuting command:\n==================\n$CMD\n"

eval $CMD 

scancel $SLURM_JOB_ID
