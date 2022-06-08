# "Exploring Diversity in Back-Translation for Low-Resource Machine Translation" (Burchell et al., NAACL 2022)

The scripts in this repo were written to run on [CSD3](https://docs.hpc.cam.ac.uk/hpc/index.html) using the ampere GPU nodes. Note that all data and models are saved to `/rds/user/$USER/hpc-work`. 

All scripts are in `scripts/` directory.

## Requirements
 - [Miniconda](https://docs.conda.io/en/latest/miniconda.html) (Python>=3.8)
 - [Weights and Biases](https://wandb.ai/site)

### Prepare software
1. Run `conda env create -f diversity-env.yml`
2. Activate environment by running `conda activate diversity-env`
3. Config [Weights and Biases API key](https://wandb.ai/settings), then run `export WANDB_API_KEY=<your_key>` 
4. Get Stanford Parser by running `bash installation/get-stanford-parser.sh`
5. Start an interactive session with one GPU and activate environment again
6. Install fairseq and sentencepiece by running `bash installation/install-fairseq-spm.sh`
7. Close GPU session

### Parallel-only models
1. Run `bash prepare-parallel-data.sh` to download and prepare the parallel training data, development sets, and test sets.
2. Alter project name in all `tools/submit-*` scripts to your own project (by `#SBATCH -A`)
3. Run `bash submit-parallel-only-ensembles.sh` to train four ensembles of four models, one for each language pair and direction.
4. Test ensemble performance with `bash test-ensemble.sh DICT_DIR MODEL{1..4}`
    - e.g. `bash test-ensemble.sh ../datasets/parallel-data/tr-en/enc-tren/ ../models/tren/tren-parallel-only/tren-parallel-only-*/checkpoint_best.pt`
    - Results are in each ensemble's directory e.g. `../models/tren/tren-parallel-only/results`
