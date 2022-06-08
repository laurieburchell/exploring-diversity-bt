#!/bin/bash

#SBATCH -J parse-shard
#SBATCH -A NLP-CDT-SL2-CPU
#SBATCH -p icelake
#SBATCH --nodes=1
#SBATCH --ntasks=76
#SBATCH --time=04:00:00
#SBATCH --output="/home/%u/logs/parse-shard_%A.out"
#SBATCH --error="/home/%u/logs/parse-shard_%A.err"

#! Number of nodes and tasks per node allocated by SLURM (do not change):
numnodes=$SLURM_JOB_NUM_NODES
numtasks=$SLURM_NTASKS
mpi_tasks_per_node=$(echo "$SLURM_TASKS_PER_NODE" | sed -e  's/^\([0-9][0-9]*\).*$/\1/')

. /etc/profile.d/modules.sh
module purge
module load rhel8/default-icl

if [ $# -ne 1 ]; then
    echo -e "usage is $0 SHARD"
    exit 1
fi


INPUT=$1
PARSER="/home/$USER/projects/diversity-bt/experiments/scripts/tools/stanford-parser-full-2020-11-17/*"

application="java -mx300g -cp \"$PARSER\" edu.stanford.nlp.parser.lexparser.LexicalizedParser -maxLength 65 -nthreads 70 -sentences newline -retainTMPSubcategories -outputFormat 'oneline' edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz $INPUT > $INPUT.cfg"

workdir="$SLURM_SUBMIT_DIR"
export OMP_NUM_THREADS=1
np=$[${numnodes}*${mpi_tasks_per_node}]
export I_MPI_PIN_DOMAIN=omp:compact
export I_MPI_PIN_ORDER=scatter
CMD="$application"

###############################################################

cd $workdir
echo -e "Changed directory to `pwd`.\n"

JOBID=$SLURM_JOB_ID

echo -e "JobID: $JOBID\n======"
echo "Time: `date`"
echo "Running on master node: `hostname`"
echo "Current directory: `pwd`"

echo -e "\nnumtasks=$numtasks, numnodes=$numnodes, mpi_tasks_per_node=$mpi_tasks_per_node (OMP_NUM_THREADS=$OMP_NUM_THREADS)"

echo -e "\nExecuting command:\n==================\n$CMD\n"

eval $CMD 
