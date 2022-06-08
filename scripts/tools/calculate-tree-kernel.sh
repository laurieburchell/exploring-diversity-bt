#!/bin/bash
# author: laurie
# calculates tree kernel over triples of sentences

INPUT_FILE=$1
OUTPUT_DIR=$2
OUTPUT_FILE=$3
PARSER="tools/stanford-parser-full-2020-11-17/*"

source ~/.bashrc
conda activate diversity

# CFG parse data
if [ ! -s $INPUT_FILE.cfg ]; then
    echo "running CFG parse of data"
    java -mx300g -cp "$PARSER" \
        edu.stanford.nlp.parser.lexparser.LexicalizedParser \
        -maxLength 80 \
        -nthreads 50 \
        -sentences newline \
        -retainTMPSubcategories \
        -outputFormat 'oneline' edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz \
        $INPUT_FILE > $INPUT_FILE.cfg 
fi

# over parsed data, calculate triplets
python tools/calculate-kernel-triplets.py $INPUT_FILE.cfg $OUTPUT_DIR $OUTPUT_FILE
