import argparse
from tqdm import tqdm
from diversity_metrics import intersent_metrics
from numpy import mean, std
import random

random.seed(2626)

parser = argparse.ArgumentParser()
parser.add_argument("input_file")
parser.add_argument("output_folder")
parser.add_argument("output_file")
sample_size=30000
args = parser.parse_args()

bleu_output_file = f"{args.output_folder}/bleu-intersent-results.tsv"
chrf_output_file = f"{args.output_folder}/chrf-intersent-results.tsv"
summary_file = f"{args.output_file}"

# generate sample file
sample_file = intersent_metrics.sample_triplets_from_file(args.input_file, sample_size)
print(f"generated sample file at {sample_file}")

# get inter-triplet metrics for file
with open(sample_file, 'r') as f, open(bleu_output_file, 'w') as bout, open(chrf_output_file, 'w') as chout:
    file_iter = intersent_metrics.grouper(f, 3)
    bleu_results = []
    chrf_results = []
    for triple in tqdm(file_iter, desc="inter-sentence metrics", total=sample_size):
        bleus = intersent_metrics.self_BLEU(triple)
        chrfs = intersent_metrics.self_chrf(triple)

        # find summary stats
        m_bleu = mean(bleus)
        s_bleu = std(bleus)
        m_chrf = mean(chrfs)
        s_chrf = std(chrfs)
        bleu_results.append([m_bleu, s_bleu**2])
        chrf_results.append([m_chrf, s_chrf**2])

        # write out intermediate results
        bout.write(f"{bleus}\t{m_bleu}\t{s_bleu}\n")
        chout.write(f"{chrfs}\t{m_chrf}\t{s_chrf}\n")

print(f"wrote results to {bleu_output_file} and {chrf_output_file}")

print(f"adding summary statistics to {summary_file}")

with open(summary_file, 'a') as f:
    overall_bleu_mean, overall_bleu_var = mean(bleu_results, axis=0)
    overall_chrf_mean, overall_chrf_var = mean(chrf_results, axis=0)
    f.write(f"statistics for sample size {sample_size} from {args.input_file}\n")
    f.write(f"Mean self-BLEU is {100-overall_bleu_mean}, standard deviation is {overall_bleu_var**(0.5)}.\n")
    f.write(f"Mean self-chrF is {100-overall_chrf_mean}, standard deviation is {overall_chrf_var**(0.5)}.\n")
