#!/bin/bash

# usage: sbatch submit-parallel-finetune.slurm $DATA $RND ddMMyy
# author: laurie
# submits script to finetune parallel models to the cluster

#SBATCH -J par-finetune
#SBATCH -A NLP-CDT-SL2-GPU
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:4
#SBATCH --time=36:00:00
#SBATCH --output="/home/%u/logs/parallel-finetune_%A.out"
#SBATCH --error="/home/%u/logs/parallel-finetune_%A.err"
#SBATCH -p ampere
##SBATCH --array=1-2%1

. /etc/profile.d/modules.sh 
module purge               
module load rhel7/default-gpu   
module load nccl/2.4.2-cuda10.0
module load miniconda/3

# get conda working
source ~/.bashrc
conda activate diversity

if [ $# -ne 3 ]; then
    echo "usage: sbatch submit-parallel-finetune.slurm DATA RND ddMMyy"
    exit 1
fi

# set up vars
PWD=`pwd`
DATA=$1
RND=$2
TODAY=$3

LANGS=${DATA##*enc-}
SRC=${LANGS:0:2}
TRG=${LANGS:2:2}

# change script depending on lang
echo "source is $SRC"
echo "target is $TRG"
echo "will train on dataset $DATA"
echo "type is $TYPE"

if [[ ( "$SRC" = "tr" ) || ( "$TRG" = "tr" ) ]]; then
    SCRIPT="cluster-scripts/finetune-turkish-model.sh"
    echo "script to run is $SCRIPT"
elif [[ ( "$SRC" = "is" ) || ( "$TRG" = "is" ) ]]; then
    SCRIPT="cluster-scripts/finetune-icelandic-model.sh"
    echo "script to run is $SCRIPT"
else
    echo "invalid language selection; quitting."
    exit 1
fi
PROJECT="${SRC}${TRG}-syntax-finetune"
echo "project is $PROJECT"
MODEL_NAME="${PROJECT}-$RND"
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
