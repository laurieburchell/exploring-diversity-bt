#!/bin/bash
set -eo pipefail
# downloads stanford parser

wget https://nlp.stanford.edu/software/stanford-parser-4.2.0.zip
unzip stanford-parser-4.2.0.zip 
mkdir -p tools/.
mv stanford-parser-full-2020-11-17 tools/.
rm stanford-parser*
