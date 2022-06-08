#!/bin/bash
set -eo pipefail
# author: laurie
# usage: 'bash test-ensemble.sh ...'
# tests performance of ensemble of four models

SCRIPT_DIR=`pwd`
SPM="${SCRIPT_DIR}/tools/sentencepiece/build/src"
DICT_DIR=$1
MODEL1=$2
MODEL2=$3
MODEL3=$4
MODEL4=$5
OUTPUT_DIR=${MODEL1%/*/*.pt}
TODAY=`date +"%d%m%y-%H%M"`

if [ $# -ne 5 ]; then
    echo "usage is 'bash $0 DICT_DIR MODEL{1..4}'"
    exit 1
fi

# download test sets for en-tr
mkdir -p tools/test-sets
for i in 16 17 18; do
    for langs in en-tr tr-en; do
        src=${langs:0:2}
        ts="tools/test-sets/wmt${i}-test.$langs.$src"
        if [ ! -s $ts ]; then
            echo "downloading test set for wmt${i} $langs"
            sacrebleu -t wmt${i} -l $langs --echo src > $ts 
        fi
    done
done

# get test-sets for en-is
if [ ! -s tools/test-sets/newstest2021.is-en.is ]; then
    echo "copying Is-En test sets for wmt21"
    cp /rds/user/$USER/hpc-work/datasets/parallel-data/is-en/raw/*test*.gz \
        tools/test-sets
    pigz -d tools/test-sets/*.gz
fi

# preprocess test sets: source side only!
for lang in en tr is; do
    for file in tools/test-sets/*.$lang; do
        if [ ! -s ${file}.norm ]; then
            echo "normalising $file"
            cat $file | \
                perl tools/remove-non-printing-char.perl | \
                perl tools/normalize-punctuation.perl -l $lang \
                > ${file}.norm
        fi
    done
done

# sentencepiece encoding
mkdir -p tools/test-sets/sp
for langs in isen tren; do
    SRC=${langs:0:2}
    TRG=${langs:2:4}
    MODEL="/home/$USER/projects/diversity-bt/experiments/datasets/parallel-data/$SRC-$TRG/sp/${SRC}${TRG}-sp.model"
    for path in tools/test-sets/*$SRC*; do
        file=${path##*/}
        spfile="tools/test-sets/sp/${file}.sp"
        if [ ! -s $spfile ]; then
            echo "sentencepiece encoding $file"
            $SPM/spm_encode --model $MODEL < $path > $spfile 
        fi
    done
done

# translate test set with ensemble
DICT=${DICT_DIR%/}; DICT=${DICT##*/}
SRC=${DICT:4:2}
TRG=${DICT:6:2}
TEST_DIR="tools/test-sets/sp"
echo "translating test sets from $SRC to $TRG"

if [[ ( "$SRC" = "tr" ) || ( "$TRG" = "tr" ) ]]; then
    INPUT="$TEST_DIR/wmt16-test.${SRC}-${TRG}.${SRC}.norm.sp $TEST_DIR/wmt17-test.${SRC}-${TRG}.${SRC}.norm.sp $TEST_DIR/wmt18-test.${SRC}-${TRG}.${SRC}.norm.sp"
elif [[ ( "$SRC" = "is" ) || ( "$TRG" = "is" ) ]]; then
    INPUT="$TEST_DIR/newstest2021.${SRC}-${TRG}.${SRC}.norm.sp $TEST_DIR/newstest2021.${TRG}-${SRC}.${SRC}.norm.sp"
else
    echo "invalid language combination, quitting"
    exit 2
fi

# prepare location for output
mkdir -p $OUTPUT_DIR/results

# translate test sets
for i in $INPUT; do
    INPUT_NAME=${i##*/}
    OUT_FILE="$OUTPUT_DIR/results/${INPUT_NAME}.${TRG}.hyp"
    if [ ! -s $OUT_FILE ]; then
        test -s $OUT_FILE || fairseq-interactive $DICT_DIR \
            --input $i \
            --path $MODEL1:$MODEL2:$MODEL3:$MODEL4 \
            --buffer-size 64 \
            --batch-size 64 \
            --beam 5 \
            --remove-bpe=sentencepiece \
            | grep -E "^D" | cut -f3 > $OUT_FILE
    fi
done

OUT="${OUTPUT_DIR}/results/results-${TODAY}.txt"
echo "scores saved to $OUT"
echo "results for $TODAY are for the following models" > $OUT
echo "${MODEL1}" >> $OUT
echo "${MODEL2}" >> $OUT
echo "${MODEL3}" >> $OUT
echo "${MODEL4}" >> $OUT
echo "" >> $OUT

# get metrics
if [[ ( "$SRC" = "is" ) || ( "$TRG" = "is" ) ]]; then
    echo "--- WMT21 ---" >> $OUT

    # combining Icelandic test sets 
    for dir in $SRC $TRG; do
        test -s tools/test-sets/newstest2021.combo.${dir} || \
            cat tools/test-sets/newstest2021.${SRC}-${TRG}.${dir} \
            tools/test-sets/newstest2021.${TRG}-${SRC}.${dir} \
            > tools/test-sets/newstest2021.combo.${dir}
    done
    cat $OUTPUT_DIR/results/newstest2021.${SRC}-${TRG}.${SRC}.norm.sp.${TRG}.hyp \
        $OUTPUT_DIR/results/newstest2021.${TRG}-${SRC}.${SRC}.norm.sp.${TRG}.hyp \
        > $OUTPUT_DIR/results/newstest2021.combo.${TRG}.hyp

    echo "calculating BLEU score for combined wmt21 test sets"
    echo "BLEU score for combined wmt21 test sets" >> $OUT
    sacrebleu "tools/test-sets/newstest2021.combo.${TRG}" -m bleu \
            -l ${SRC}-${TRG} \
            -w 3 \
            -i $OUTPUT_DIR/results/newstest2021.combo.${TRG}.hyp \
            -f text \
            >> $OUT

    REFS="newstest2021.${SRC}-${TRG} newstest2021.${TRG}-${SRC}"
    echo "calculating BLEU score for wmt21 ${SRC}-${TRG}"
    for ref in $REFS; do
        echo "BLEU score for $ref" >> $OUT
        sacrebleu "tools/test-sets/${ref}.${TRG}" -m bleu  \
            -l ${SRC}-${TRG} \
            -w 3 \
            -i $OUTPUT_DIR/results/$ref.${SRC}.norm.sp.${TRG}.hyp \
            -f text \
            >> $OUT 
    done
    echo "" >> $OUT

    echo "calculating COMET score for combined wmt21 test sets"
    echo "COMET score for combined wmt21 test sets" >> $OUT
    S="tools/test-sets/newstest2021.combo.${SRC}"
    R="tools/test-sets/newstest2021.combo.${TRG}"
    COMET_OUT="${OUTPUT_DIR}/results/comet-results-wmt21-combo.json" 
    test -s $COMET_OUT || comet-score -s $S \
        -t $OUTPUT_DIR/results/newstest2021.combo.${TRG}.hyp \
        -r $R \
        --num_workers 32 \
        --to_json true > $COMET_OUT
    SCORE=`cut -f2 $COMET_OUT | grep score`
    echo "COMET $SCORE" >> $OUT

    for pair in ${SRC}-${TRG} ${TRG}-${SRC}; do
        echo "calculating COMET score for wmt21 $pair"
        echo "COMET score for newstest2021.$pair" >> $OUT
        S="tools/test-sets/newstest2021.${pair}.${SRC}"
        R="tools/test-sets/newstest2021.${pair}.${TRG}"
        COMET_OUT="${OUTPUT_DIR}/results/comet-results-wmt21-$pair.json"
        test -s $COMET_OUT || comet-score -s $S \
            -t $OUTPUT_DIR/results/newstest2021.${pair}.${SRC}.norm.sp.${TRG}.hyp \
            -r $R \
            --num_workers 32 \
            --to_json true > $COMET_OUT
        SCORE=`cut -f2 $COMET_OUT | grep score`
        echo "COMET $SCORE" >> $OUT
    done
        

elif [[ ( "$SRC" = "tr" ) || ( "$TRG" = "tr" ) ]]; then
    for i in 16 17 18; do
        echo "calculating BLEU score for wmt${i} ${SRC}-${TRG}"
        echo "--- WMT$i ---" >> $OUT
        sacrebleu -m bleu  \
            -t wmt${i} \
            -l ${SRC}-${TRG} \
            -w 3 \
            -i $OUTPUT_DIR/results/wmt${i}*${TRG}.hyp \
            -f text \
            >> $OUT

        echo "calculating BLEU score separated by translation direction"
        for dir in en tr; do
            SCORE=`sacrebleu -m bleu  \
                -t wmt${i} \
                -l ${SRC}-${TRG} \
                -w 3 \
                -i $OUTPUT_DIR/results/wmt${i}*${TRG}.hyp \
                --origlang=$dir | jq -r .score`
            echo "for test set wmt${i} with native language $dir, BLEU score: $SCORE" >> $OUT
        done

        echo "calculating COMET score for wmt${i} ${SRC}-${TRG}"
        COMET_OUT="${OUTPUT_DIR}/results/comet-results-wmt${i}-${SRC}-${TRG}.json"
        test -s $COMET_OUT || comet-score \
            -d wmt${i}:${SRC}-${TRG} \
            -t $OUTPUT_DIR/results/wmt${i}*${TRG}.hyp \
            --num_workers 32 \
            --to_json true > $COMET_OUT 
        SCORE=`cut -f2 $COMET_OUT | grep score`
        echo "Overall COMET $SCORE" >> $OUT

        echo "calculating COMET score separated by translation direction"
        for dir in en tr; do
            SCORE=`python tools/get_comet_score_by_direction.py $COMET_OUT wmt${i} $dir`
            echo $SCORE >> $OUT
        done
        echo "" >> $OUT
    done
fi

cat $OUT
