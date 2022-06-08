#!/bin/bash
set -eo pipefail
# author: laurie
# usage: 'bash prepare-parallel-data.sh'
# downloads and prepares parallel data for training NMT models. 
# designed to run on CSD3.

SCRIPT_DIR=`pwd`
ROOT=`cd ..; pwd`
TREN_DIR="/rds/user/$USER/hpc-work/datasets/parallel-data/tr-en"
ISEN_DIR="/rds/user/$USER/hpc-work/datasets/parallel-data/is-en"
SPM="${SCRIPT_DIR}/tools/sentencepiece/build/src"

module load parallel
module load miniconda/3

echo "creating directories and symlinks for parallel data"
mkdir -p $TREN_DIR
mkdir -p $ISEN_DIR
mkdir -p $ROOT/datasets/parallel-data
cd $ROOT/datasets/parallel-data
test -e tr-en || ln -s $TREN_DIR
test -e is-en || ln -s $ISEN_DIR

# download Turkish-English parallel data
cd $TREN_DIR
mkdir -p raw
cd raw
echo "downloading raw Tr-En data to `pwd`"
test -s en-tr.zip || wget --no-check-certificate https://opus.nlpl.eu/download.php?f=SETIMES/v2/moses/en-tr.txt.zip -O en-tr.zip
test -s dev18.tgz || wget --no-check-certificate -O dev18.tgz http://data.statmt.org/wmt18/translation-task/dev.tgz 
test -s test18.tgz || wget --no-check-certificate -O test18.tgz http://data.statmt.org/wmt18/translation-task/test.tgz

if [ ! -e train.raw.en.gz ]; then
    echo "decompressing files"
    unzip -n en-tr.zip
    for lang in en tr; do
        mv SETIMES.en-tr.$lang train.raw.$lang
        pigz train.raw.$lang
    done
    rm LICENSE README SETIMES.en-tr.ids
fi

shopt -s extglob
if [ ! -e newsdev2016.raw.en.gz ]; then
    tar -xzf dev18.tgz
    tar -xvf test18.tgz
    cp test18/*entr* dev18/.  # can reformat all at once
    cd dev18
    rm !(*entr*)
    for file in *.sgm; do new=${file%.sgm}; mv $file $new; done
    for file in news*; do pref=${file%-entr*}; lang=${file##*.}; mv $file $pref.$lang; done
    for lang in en tr; do
        for file in *.$lang; do
            pref=${file%.*}
            grep '<seg id' $file | \
                sed -e 's/<seg id="[0-9]*">\s*//g' | \
                sed -e 's/\s*<\/seg>\s*//g' | \
                sed -e "s/\’/\'/g" > $TREN_DIR/raw/${pref}.raw.$lang
                test -f $TREN_DIR/raw/${pref}.raw.$lang.gz || pigz $TREN_DIR/raw/${pref}.raw.$lang
        done
    done
    cd ..
    rm -r dev18 test18
fi

# download Icelandic-English parallel data
cd $ISEN_DIR
mkdir -p raw
cd raw
echo "downloading raw Is-En data to `pwd`"
test -s parice_filtered.zip || wget  --no-check-certificate http://parice.arnastofnun.is/data/parice_filtered.zip 
test -s paracrawl-en-is.txt.gz || wget --no-check-certificate -O paracrawl-en-is.txt.gz https://s3.amazonaws.com/web-language-models/paracrawl/release7.1/en-is.txt.gz 
test -s WikiMatrix.v1.en-is.langid.tsv.gz || wget --no-check-certificate https://data.statmt.org/wmt21/translation-task/WikiMatrix/WikiMatrix.v1.en-is.langid.tsv.gz 
test -s wikititles-v3.is-en.tsv.gz  || wget --no-check-certificate https://data.statmt.org/wikititles/v3/wikititles-v3.is-en.tsv
test -s dev21.tgz || wget --no-check-certificate -O dev21.tgz http://data.statmt.org/wmt21/translation-task/dev.tgz 
test -s test21.tgz || wget --no-check-certificate -O test21.tgz http://data.statmt.org/wmt21/translation-task/test.tgz

if [ ! -e train.raw.en.gz ]; then
    unzip parice_filtered.zip
    pigz -d paracrawl-en-is.txt.gz WikiMatrix.v1.en-is.langid.tsv.gz
    cut -f1 paracrawl-en-is.txt > paracrawl-en-is.en
    cut -f2 paracrawl-en-is.txt > paracrawl-en-is.is
    grep -P "\ten\tis" WikiMatrix.v1.en-is.langid.tsv | cut -f2 > wikimatrix-en-is.en
    grep -P "\ten\tis" WikiMatrix.v1.en-is.langid.tsv | cut -f3 > wikimatrix-en-is.is
    cut -f1 wikititles-v3.is-en.tsv > wikititles-en-is.is
    cut -f2 wikititles-v3.is-en.tsv > wikititles-en-is.en
    for lang in is en; do
        cat paracrawl-en-is.$lang train.$lang wikimatrix-en-is.$lang wikititles-en-is.$lang > train.raw.$lang
        pigz train.raw.${lang}
        rm paracrawl-en-is.$lang train.$lang wikimatrix-en-is.$lang wikititles-en-is.$lang
    done
    pigz paracrawl-en-is.txt wikititles-v3.is-en.tsv WikiMatrix.v1.en-is.langid.tsv
fi 

if [ ! -e newsdev2021.en-is.en.gz ]; then
    tar -xvf dev21.tgz
    tar -xvf test21.tgz
    cp test/newstest2021.en-is.xml test/newstest2021.is-en.xml dev/xml/newsdev2021.en-is.xml .
    for file in *.xml; do python $SCRIPT_DIR/tools/extract-xml.py $file; done
    rm *.xml
    pigz *.is *.en
    rm -r dev test
fi
pigz *.is *.en

# clean turkish training data
cd $SCRIPT_DIR
echo "cleaning tr-en training data"
mkdir -p $TREN_DIR/clean 
for lang in tr en; do
    test -s $TREN_DIR/clean/train.clean.$lang.gz || ln -s $TREN_DIR/raw/train.raw.$lang.gz $TREN_DIR/clean/train.$lang.gz
done

if [ ! -e $TREN_DIR/clean/train.clean.en.gz ]; then
    bash tools/clean-parallel.sh $TREN_DIR/clean/train.tr.gz tr \
        $TREN_DIR/clean/train.en.gz en
    cd $TREN_DIR/clean; rm *phase* train.en.gz train.tr.gz train.tr.gz-en.clean.gz
    for l in en tr; do mv train.${l}.gz.clean.gz train.clean.${l}.gz; done
    pigz *debug*
fi

echo "cleaning dev sets"
cd $SCRIPT_DIR
if [ ! -f $TREN_DIR/clean/newsdev2016.clean.en.gz ]; then
    for lang in en tr; do
        for path in $TREN_DIR/raw/*dev*${lang}.gz; do
            file=${path##*/}
            name=${file%%.*}
            echo "processing $name.$lang"
            pigz -dc $path | perl tools/remove-non-printing-char.perl | perl tools/normalize-punctuation.perl -l $lang > $TREN_DIR/clean/${name}.clean.${lang}
            pigz $TREN_DIR/clean/${name}.clean.${lang}
        done
    done
fi

echo "copying test sets"
cd $SCRIPT_DIR
if [ ! -f $TREN_DIR/clean/newstest2018.raw.en.gz ]; then
    for lang in en tr; do
        for path in $TREN_DIR/raw/*test*${lang}.gz; do
            file=${path##*/}
            echo "copying $file"
            cp $path $TREN_DIR/clean/$file
        done
    done
fi

echo "finished cleaning Turkish-English parallel data"

# clean Icelandic traning data
cd $SCRIPT_DIR
echo "cleaning is-en training data"
mkdir -p $ISEN_DIR/clean 
for lang in is en; do
    test -s $ISEN_DIR/clean/train.clean.$lang.gz || ln -s $ISEN_DIR/raw/train.raw.$lang.gz $ISEN_DIR/clean/train.$lang.gz
done

if [ ! -e $ISEN_DIR/clean/train.clean.en.gz ]; then
    bash tools/clean-parallel.sh $ISEN_DIR/clean/train.is.gz is \
        $ISEN_DIR/clean/train.en.gz en
    cd $ISEN_DIR/clean; rm *phase* train.en.gz train.is.gz train.is.gz-en.clean.gz
    for l in en is; do mv train.${l}.gz.clean.gz train.clean.${l}.gz; done
    pigz *debug* train*
fi

echo "cleaning dev sets"
cd $SCRIPT_DIR
if [ ! -f $ISEN_DIR/clean/newsdev2021.clean.en.gz ]; then
    for lang in en is; do
        for path in $ISEN_DIR/raw/*dev*${lang}.gz; do
            file=${path##*/}
            name=${file%%.*}
            echo "processing $name.$lang"
            pigz -dc $path | perl tools/remove-non-printing-char.perl | perl tools/normalize-punctuation.perl -l $lang > $ISEN_DIR/clean/${name}.clean.${lang}
            pigz $ISEN_DIR/clean/${name}.clean.${lang}
        done
    done
fi

echo "copying test sets"
cd $SCRIPT_DIR
if [ ! -f $ISEN_DIR/clean/newstest2021.is-en.is.gz ]; then
    for lang in en is; do
        for path in $ISEN_DIR/raw/*test*${lang}.gz; do
            file=${path##*/}
            echo "copying $file"
            cp $path $ISEN_DIR/clean/$file
        done
    done
fi

echo "finished cleaning Icelandic-English data"

# sentence piece encoding
mkdir -p $TREN_DIR/sp
cd $TREN_DIR/sp
if [ ! -f $TREN_DIR/sp/tren-sp.model ]; then
    echo "training tr-en sentencepiece model"
    for l in tr en; do pigz -d $TREN_DIR/clean/train.clean.$l.gz; done
    $SPM/spm_train \
        --input=$TREN_DIR/clean/train.clean.tr,$TREN_DIR/clean/train.clean.en \
        --model_prefix=tren-sp \
        --vocab_size=16000 \
        --character_coverage=1.0 \
        --model_type=bpe
    for l in tr en; do pigz $TREN_DIR/clean/train.clean.$l; done
fi

echo "sentencepiece encoding turkish-english data"
for lang in tr en; do
    for path in $TREN_DIR/clean/*.${lang}.gz; do
        file=${path##*/}
        name=${file%%.*}
        echo "encoding ${name}.${lang}"
        test -s $TREN_DIR/sp/${name}.sp.${lang}.gz || pigz -dc $path | $SPM/spm_encode \
            --model $TREN_DIR/sp/tren-sp.model > $TREN_DIR/sp/${name}.sp.${lang}
    done
done

mkdir -p $ISEN_DIR/sp
cd $ISEN_DIR/sp
if [ ! -f $ISEN_DIR/sp/isen-sp.model ]; then
    echo "training is-en sentencepiece model"
    for l in is en; do pigz -d $ISEN_DIR/clean/train.clean.$l.gz; done
    $SPM/spm_train \
        --input=$ISEN_DIR/clean/train.clean.is,$ISEN_DIR/clean/train.clean.en \
        --model_prefix=isen-sp \
        --vocab_size=16000 \
        --character_coverage=1.0 \
        --model_type=bpe
    for l in is en; do pigz $ISEN_DIR/clean/train.clean.$l; done
fi

echo "sentencepiece encoding icelandic-english data"
for lang in is en; do
    for path in $ISEN_DIR/clean/*clean.${lang}.gz; do
        file=${path##*/}
        name=${file%%.*}
        echo "encoding ${name}.${lang}"
        test -s $ISEN_DIR/sp/${name}.sp.${lang}.gz || pigz -dc $path | $SPM/spm_encode \
            --model $ISEN_DIR/sp/isen-sp.model > $ISEN_DIR/sp/${name}.sp.${lang}
    done
    for path in $ISEN_DIR/clean/*test*.${lang}.gz; do
        file=${path##*/}
        name=${file%.*.gz}
        echo "encoding ${name}.${lang}"
        test -s $ISEN_DIR/sp/${name}.sp.${lang}.gz || pigz -dc $path | $SPM/spm_encode \
            --model $ISEN_DIR/sp/isen-sp.model > $ISEN_DIR/sp/${name}.sp.${lang}
    done
done

# binarise for faster fairseq training
cd $TREN_DIR/sp
echo "binarising parallel tr-en data for fairseq training"
TRAIN=train.sp
DEV=newsdev2016.sp 
TEST=newstest2016.sp,newstest2017.sp,newstest2018.sp 

for langs in entr tren; do
    SRC=${langs:0:2}; TRG=${langs:2:4}
    test -d $TREN_DIR/enc-${SRC}${TRG} || fairseq-preprocess \
        --source-lang $SRC \
        --target-lang $TRG \
        --destdir $TREN_DIR/enc-${SRC}${TRG} \
        --trainpref $TRAIN \
        --validpref $DEV \
        --testpref $TEST \
        --joined-dictionary \
        --workers 20
done

cd $ISEN_DIR/sp
echo "binarising parallel is-en data for fairseq training"
TRAIN=train.sp
DEV=newsdev2021.sp 
TEST=newstest2021.en-is.sp,newstest2021.is-en.sp

for langs in enis isen; do
    SRC=${langs:0:2}; TRG=${langs:2:4}
    test -d $ISEN_DIR/enc-${SRC}${TRG} || fairseq-preprocess \
        --source-lang $SRC \
        --target-lang $TRG \
        --destdir $ISEN_DIR/enc-${SRC}${TRG} \
        --trainpref $TRAIN \
        --validpref $DEV \
        --testpref $TEST \
        --joined-dictionary \
        --workers 20
done

echo "compressing SentencePiece encoded data"
test -s $TREN_DIR/sp/newstest2018.sp.tr.gz || pigz $TREN_DIR/sp/*.sp.*     
test -s $ISEN_DIR/sp/newsdev2021.sp.is.gz || pigz $ISEN_DIR/sp/*.sp.*     

# prepare directories for later
cd $SCRIPT_DIR
mkdir -p ../logs  # for fairseq
mkdir -p ../models
mkdir -p ~/logs  # for slurm
echo "parallel data preparation finished. Time to train parallel models?"
