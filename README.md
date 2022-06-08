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
2. Alter project name in all `cluster-scripts/submit-*` scripts to your own project (by `#SBATCH -A`)
3. Run `bash submit-parallel-only-ensembles.sh` to train four ensembles of four models, one for each language pair and direction.
4. Test ensemble performance with `bash test-ensemble.sh DICT_DIR MODEL{1..4}`
    - e.g. `bash test-ensemble.sh ../datasets/parallel-data/tr-en/enc-tren/ ../models/tren/tren-parallel-only/tren-parallel-only-*/checkpoint_best.pt`
    - Results are in each ensemble's directory e.g. `../models/tren/tren-parallel-only/results`

### Fine-tune syntax-group back-translation models
1. Run `bash split-and-submit-parse-parallel.sh {tr|is}` to shard the English side of the parallel datasets and submit them to the cluster for parsing.
2. The notebook `CreateSyntaxGroups.ipynb` contains instructions to create the three syntax groups.
3. Prepare the syntax groups for fairseq training by running `bash prepare-syntax-group-data.sh DATA_DIR SRC_DATA TRG_DATA group{0,1,2}`

### Back-translation
1. Run `bash prepare-monolingual-data.sh` to download and prepare the monolingual data.
2. For each language pair, back-translate the monolingual data by runnning `bash submit-backtranslation-jobs.sh DATA DICT_DIR MODEL{1..4}`
    - e.g. `bash submit-backtranslation-jobs.sh ../datasets/monolingual-data/en/sp/mono.9M.isen-sp.en.gz ../datasets/parallel-data/is-en/enc-enis/ ../models/enis/enis-parallel-only/enis-parallel-only-*/checkpoint_best.pt`
3. For syntax models, run `for i in 0..3; do for j in 0..2; do for l in isen tren; do sbatch cluster-scripts/submit-translate-mono.slurm ../datasets/back-translation/$l/mono.shard.is$i ../datasets/parallel-data/${l:0:2}-en/enc-$l/ ../models/$l/$l-syntax-finetune/$l-syntax-finetune-*group$j/checkpoint_best.pt syntax$j; done; done; done`
4. Once back-translation is complete, create parallel plus back-translation datasets for each language pair by running `bash prepare-all-back-translated-data FINAL_SRC FINAL_TRG` 

### Parallel plus back-translation models
1. Run `bash submit-parallel-plus-bt-ensembles.sh` to train ensembles of four models for each of the language pairs and different diversity datasets.
2. Test ensemble performance as before with `bash test-ensemble.sh DICT_DIR MODEL{1..4}`
    - e.g. `bash test-ensemble.sh ../datasets/parallel-plus-bt/tren/nucleus3M/enc-tren/ ../models/tren/tren-parallel-plus-bt-nucleus3M/tren-parallel-plus-bt-nucleus3M-*/checkpoint_best.pt`

### Diversity metrics
1. Run `bash calculate-diversity-metrics.sh INPUT_DATA LANG_FROM_LANG CORPUS_SIZE TYPE` to calculate the diversity metrics over the back-translated corpora.
    - e.g. `bash calculate-diversity-metrics.sh ../datasets/parallel-plus-bt/entr/mono.beam-tr-bt.en.gz en-from-tr 9000000 beam3M`
    - Note that results will be saved in `diversity-metrics/${LANG_FROM_LANG}/`
