from sacrebleu import corpus_bleu, corpus_chrf
from itertools import permutations
from tqdm import tqdm
from subprocess import check_output
from numpy import array
import random

""" a number of functions designed for calculating inter-sentence metrics over a sample"""

def get_lines_to_sample(input_file, sample_size):
    """Returns a set of triple numbers to sample from input file and total number of triples"""
    total_triples = int(check_output(["wc", "-l", input_file]).split()[0])//3
    if total_triples > int(sample_size):
        lines_to_sample = array(
                random.sample(list(range(total_triples)), sample_size))
        sample_set = set(lines_to_sample)
    else:
        sample_set = "all"

    return sample_set, total_triples


def grouper(iterable, n):
    """Groups iterable into chunks n long"""
    args = [iter(iterable)] * n
    return zip(*args)


def sample_triplets_from_file(input_file, sample_size, output_file=None):
    """Sample specified number of triplets from file and write output"""
    # get line numbers of triplets to sample
    sample_set, num_triples = get_lines_to_sample(input_file, sample_size)
    if not output_file:
        output_file = f"{input_file}.sample"
    
    # read lines from input file and write selected triples to output
    if not sample_set == "all":
        with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
            file_iter = grouper(infile, 3)
            for i, triple in tqdm(enumerate(file_iter), 
                    total=num_triples, desc="sampling triples"):
                if i not in sample_set:
                    continue
                else:
                    for line in triple:
                        outfile.write(f"{line}")
        print(f"wrote sample of triples to {output_file}")
    else:
        print("calculating metrics over whole file")
        output_file = input_file

    return output_file


def self_BLEU(triple):
    """Calculates BLEU score between all pairs"""
    perms = permutations(triple, 2)
    bleus = []
    for pair in perms:
        b = corpus_bleu(
                [pair[0].strip()], [[pair[1].strip()]], lowercase=True).score
        bleus.append(b)

    return bleus


def self_chrf(triple):
    """Calculates chrF score between all pairs"""
    perms = permutations(triple, 2)
    chrfs = []
    for pair in perms:
        c = corpus_chrf([pair[0]], [[pair[1]]]).score
        chrfs.append(c)

    return chrfs

