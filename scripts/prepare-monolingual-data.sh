#!/bin/bash
set -eo pipefail
# author: laurie
# usage: `bash prepare-monolingual-data.sh`
# downloads, cleans, and creates sample of 9 million sentences for back-translation
# from English, Turkish, and Icelandic monolingual corpora

SCRIPT_DIR=`pwd`
ROOT=`cd ..; pwd`
DATA_DIR="/rds/user/$USER/hpc-work/datasets"
MONO_DIR="$DATA_DIR/monolingual-data"
EN_DIR="$MONO_DIR/en"
TR_DIR="$MONO_DIR/tr"
IS_DIR="$MONO_DIR/is"
SPM_TREN="$DATA_DIR/parallel-data/tr-en/sp/tren-sp.model"
SPM_ISEN="$DATA_DIR/parallel-data/is-en/sp/isen-sp.model"
SPM="${SCRIPT_DIR}/tools/sentencepiece/build/src"

module load parallel
module load miniconda/3

echo "creating directories and symlinks for monolingual data"
for dir in $EN_DIR $TR_DIR $IS_DIR; do mkdir -p $dir; done
mkdir -p $ROOT/datasets; cd $ROOT/datasets
test -e monolingual-data || ln -s $MONO_DIR

# download English monolingual data
cd $EN_DIR
mkdir -p raw; cd raw
echo "downloading raw En data to `pwd`"
test -s news-commentary-v16.en.gz || wget --no-check-certificate \
    http://data.statmt.org/news-commentary/v16/training-monolingual/news-commentary-v16.en.gz
test -s news-discuss.2019.en.filtered.gz || wget --no-check-certificate \
    http://data.statmt.org/news-discussions/en/news-discuss.20{16..19}.en.filtered.gz
test -s news.2020.en.shuffled.deduped.gz || wget --no-check-certificate \
    http://data.statmt.org/news-crawl/en/news.20{16..20}.en.shuffled.deduped.gz

# download Turkish monolingual data
cd $TR_DIR
mkdir -p raw; cd raw
echo "downloading raw Tr data for `pwd`"
for i in {16..20}; do 
    test -s news.20${i}.tr.shuffled.deduped.gz || wget --no-check-certificate \
        http://data.statmt.org/news-crawl/tr/news.20${i}.tr.shuffled.deduped.gz; 
done

# download Icelandic monolingual data
cd $IS_DIR
mkdir -p raw; cd raw
echo "downloading raw Is data to `pwd`"
test -s news.2020.is.shuffled.deduped.gz || wget --no-check-certificate https://data.statmt.org/news-crawl/is/news.2020.is.shuffled.deduped.gz
test -e IGC1.20.05.zip || curl --remote-name-all https://repository.clarin.is/repository/xmlui/bitstream/handle/20.500.12537/41{/IGC1.20.05.zip}
if ! [ -e IGC1.is.gz ]; then
    echo "extracting Icelandic Gigaword data"
    test -s IGC1.is.phase1 || unzip -p IGC1.20.05.zip \
        | grep -E "(<(w|c)|</s>)" \
        | sed 's/<w.*\">//g' \
        | sed -r 's_</(w|c)>__g' \
        | tr -d ' ' > IGC1.is.phase1
    echo "merging lines of processed IGC1"
    test -s IGC1.is.phase2 || python $SCRIPT_DIR/tools/merge-IGC-lines.py
    echo "removing punctuation tags from IGC1"
    test -s IGC1.is || sed 's/\s\?<ctype=\"\w\w\">//g' IGC1.is.phase2 > IGC1.is
    #rm IGC1.is.phase*
    echo "compressing IGC1.is"
    pigz IGC1.is
fi

# clean each file with Patrick's script
cd $SCRIPT_DIR
for lang in en tr is; do
    for file in $MONO_DIR/$lang/raw/*.gz; do
        name=${file##*/}
        name=${name%.gz}
        echo "cleaning $name ($lang)"
        test -s $MONO_DIR/$lang/clean/${name}.clean.gz || tools/clean-monolingual.sh $file $lang
    done
    test ! -d $MONO_DIR/$lang/raw/temp || rm -r $MONO_DIR/$lang/raw/temp
done

# concat files and select 9M
for lang in en tr is; do
    cd $MONO_DIR/$lang/clean
    if [ ! -s mono.all.clean.$lang.gz ]; then
        for file in $MONO_DIR/$lang/clean/*.gz; do
            echo "adding $file to mono.all.clean.$lang"
            pigz -dc $file >> mono.all.clean.$lang
        done
    fi
    echo "shuffling mono.all.clean.en, selecting 9 million sentences for back-translation"
    test -s mono.9M.clean.${lang}.gz || shuf -n 9000000 mono.all.clean.$lang > mono.9M.clean.$lang
    pigz mono*
done

# sentencepiece encode english using turkish and icelandic models
cd $EN_DIR/clean
mkdir -p $EN_DIR/sp
echo "encoding en mono with tr-en SentencePiece model"
test -s $EN_DIR/sp/mono.9M.tren-sp.en.gz || pigz -dc mono.9M.clean.en.gz \
    | $SPM/spm_encode --model $SPM_TREN \
    > $EN_DIR/sp/mono.9M.tren-sp.en
echo "encoding en mono with is-en SentencePiece model"
test -s $EN_DIR/sp/mono.9M.isen-sp.en.gz || pigz -dc mono.9M.clean.en.gz \
    | $SPM/spm_encode --model $SPM_ISEN \
    > $EN_DIR/sp/mono.9M.isen-sp.en
pigz $EN_DIR/sp/*

# sentencepiece encode turkish and icelandic
for lang in tr is; do
    cd $MONO_DIR/$lang/clean
    mkdir -p $MONO_DIR/$lang/sp
    echo "encoding $lang mono with ${lang}-en SentencePiece model"
    test -s $MONO_DIR/$lang/sp/mono.9M.${lang}en-sp.${lang}.gz || pigz -dc mono.9M.clean.${lang}.gz \
        | $SPM/spm_encode --model "$DATA_DIR/parallel-data/${lang}-en/sp/${lang}en-sp.model" \
        > $MONO_DIR/$lang/sp/mono.9M.${lang}en-sp.${lang}
    pigz $MONO_DIR/$lang/sp/*
done

echo "monolingual data cleaned and sentencepiece encoded"
echo "script finished"
