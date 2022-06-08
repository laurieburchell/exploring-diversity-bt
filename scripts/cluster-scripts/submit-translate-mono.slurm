#!/bin/bash

#SBATCH -J back-trans
#SBATCH -A NLP-CDT-SL2-GPU
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
#SBATCH --time=36:00:00
#SBATCH --output="/home/%u/logs/bt_%A.out"
#SBATCH --error="/home/%u/logs/bt_%A.err"
#SBATCH -p ampere
#SBATCH --mail-type=FAIL

. /etc/profile.d/modules.sh 
module purge               
module load rhel7/default-gpu   
module load cuda/11.0
module load cuda/11.1
module load cudnn/8.0_cuda-11.1
module load nccl/2.4.2-cuda10.0
module load miniconda/3

# get conda working
source ~/.bashrc
conda activate diversity

application="bash cluster-scripts/translate-mono.sh"
options="$1 $2 $3 $4 $5 $6 $7"
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
