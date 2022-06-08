from diversity_metrics.tree_kernel_from_string import SSTKernelFromString as Kernel
from diversity_metrics.intersent_metrics import grouper
from itertools import combinations
from numpy import mean, std
from tqdm import tqdm
from subprocess import check_output
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("input_file")
parser.add_argument("output_folder")
parser.add_argument("output_file")
args = parser.parse_args()

inputfile = args.input_file
outputfile = f"{args.output_folder}/kernel-results.tsv"
summaryfile = f"{args.output_file}"
kern = Kernel()

print(f"will calculate triplets over {inputfile}")
with open(inputfile, 'r') as infile, open(outputfile, 'w') as outfile:
    # get length of file for tqdm
    in_len = int(check_output(["wc", "-l", inputfile]).split()[0])//3
    # iterate over file in triples
    file_iter = grouper(infile, 3)
    results = []
    
    for i, triple in tqdm(iterable=enumerate(file_iter), total=in_len):
        # calculate tree kernel for each triplet
        combos = combinations(triple, 2)
        try:
            ks = [kern.calculate_kernel(*c) for c in combos]
            # find summary stats
            m = mean(ks)
            s = std(ks)
            results.append([m, s**2])
            outfile.write(f"{ks}\t{m}\t{s}\n")
        except:
            print(f"error occurred for triple {i+1}")
            outfile.write(f"ERROR{triple}\n")
            continue

print(f"wrote results to {outputfile}")

print(f"adding summary statistics to {summaryfile}")

with open(summaryfile, "a") as f:
    overall_mean, overall_var = mean(results, axis=0)
    overall_std = overall_var**(0.5)
    f.write(f"Mean normalised kernel score is {100-(overall_mean*100)}, standard deviation of mean kernel score is {overall_std*100}\n")
