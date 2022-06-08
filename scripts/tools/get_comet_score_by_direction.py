#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Jan 31 16:20:41 2022

@author: laurie
"""

import os
import re
import argparse
from sacrebleu.dataset import DATASETS
from sacrebleu.utils import smart_open


USERHOME = os.path.expanduser("~")
SACREBLEU_DIR = os.environ.get(
    'SACREBLEU', os.path.join(USERHOME, '.sacrebleu'))

def get_comet_score_by_direction(file, test_set, lang):
    """
    Splits COMET score for En-Tr test sets by direction.

    Parameters
    ----------
    file : json file path
        json output file from COMET score script.
    test_set : str
        wmt{16..18}, the test set to compare.
    lang : str
        'en' or 'tr', the language direction to output.

    Returns
    -------
    float
        Mean COMET score by direction.

    """
    
    langpair = 'tr-en'
    origlang = 'en'
    re_origlang = re.compile(r'.* origlang="([^"]+)".*\n')
    
    # get indices to keep from test sets
    rawfile = os.path.join(SACREBLEU_DIR, test_set, 'raw', 
                           DATASETS[test_set][langpair][0])
    indices_to_keep = []
    number_sentences_included = 0
    with smart_open(rawfile) as fin:
        include_doc = False
        for line in fin:
            if line.startswith('<doc '):
                doc_origlang = re_origlang.sub(r'\1', line)
                if origlang.startswith('non-'):
                    include_doc = doc_origlang != origlang[4:]
                else:
                    include_doc = doc_origlang == origlang
    
            if line.startswith('<seg '):
                indices_to_keep.append(include_doc)
                number_sentences_included += 1 if include_doc else 0
                    
    # for each line, sum comet score
    re_score = re.compile(r'.*Segment.*score:')
    with open(file, 'r') as f:
        en_score, tr_score = 0., 0.
        en_count, tr_count = 0, 0
        for i, line in enumerate(f):
            score = re_score.sub(r'', line).strip()
            try:
                if indices_to_keep[i]:
                    en_score += float(score)
                    en_count += 1
                else:
                    tr_score += float(score)
                    tr_count +=1
            except IndexError:
                break
            
            
    # output appropriate test set
    if lang=='en':
        score = en_score/en_count
    elif lang=='tr':
        score = tr_score/tr_count
    else:
        return 'INVALID LANG'
    
    print(f"for test set {test_set} with native language {lang}, COMET score: {score:.4f}")
    
if __name__ == '__main__':
    
    parser = argparse.ArgumentParser()
    parser.add_argument('cometjson', type=str,
                    help='path to comet json output file')
    parser.add_argument('wmt', type=str,
                    help='which wmt test set to compare (wmt{16..18})')
    parser.add_argument('lang', type=str,
                    help='which language direction to ouput (en or tr)')
    args = parser.parse_args()
    
    get_comet_score_by_direction(args.cometjson, args.wmt, args.lang)

