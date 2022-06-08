#!/bin/bash
set -eo pipefail
# author: laurie
# usage: `bash instal-fairseq-spm.sh`
# installs fairseq so it works on the command line. Assumes conda env activated.
# builds sentencepiece locally (assumes no sudo).

cd tools
test -d fairseq || git clone https://github.com/pytorch/fairseq
test -d sentencepiece || git clone https://github.com/google/sentencepiece.git 
# install fairseq
cd fairseq
pip install --editable ./
python setup.py build_ext --inplace
echo "fairseq installed"
# install sentencepiece locally 
cd ../sentencepiece
mkdir -p build; cd build
cmake ..
make -j 20
echo "sentencepiece built"
