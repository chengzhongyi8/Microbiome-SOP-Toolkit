#!/usr/bin/env python3
"""Merge per-sample `samtools idxstats` files into count and FPKM matrices.

idxstats file format (tab-separated, one per sample):
    GeneID<TAB>length<TAB>mapped_reads<TAB>unmapped_reads
The trailing '*' (unmapped) row is dropped.

FPKM = mapped_reads * 1e9 / (length * total_mapped_reads)

Only the Python standard library is used so it runs in any python3.
"""
import argparse
import glob
import os
import sys


def parse_idxstats(path):
    counts = {}
    lengths = {}
    total = 0
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            gid, length, mapped = parts[0], parts[1], parts[2]
            if gid == "*":
                continue
            try:
                length = int(length)
                mapped = int(mapped)
            except ValueError:
                continue
            counts[gid] = mapped
            lengths[gid] = length
            total += mapped
    return counts, lengths, total


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--idxstats-dir", required=True, help="directory with <sample>.txt idxstats files")
    ap.add_argument("--output-prefix", required=True, help="output prefix, e.g. results/quant/gene")
    args = ap.parse_args()

    files = sorted(glob.glob(os.path.join(args.idxstats_dir, "*.txt")))
    if not files:
        sys.exit("ERROR: no idxstats files found in " + args.idxstats_dir)

    samples = []
    data = []
    for path in files:
        sample = os.path.basename(path)[:-4]
        counts, lengths, total = parse_idxstats(path)
        if not counts:
            print("WARNING: empty idxstats for %s" % sample, file=sys.stderr)
        samples.append(sample)
        data.append((counts, lengths, total))

    gene_ids = sorted(set().union(*(d[0].keys() for d in data)))
    if not gene_ids:
        sys.exit("ERROR: no gene rows found in idxstats files")

    count_out = args.output_prefix + ".count.tsv"
    fpkm_out = args.output_prefix + ".FPKM.tsv"
    with open(count_out, "w", encoding="utf-8", newline="") as fc, \
         open(fpkm_out, "w", encoding="utf-8", newline="") as ff:
        wc = __import__("csv").writer(fc, delimiter="\t", lineterminator="\n")
        wf = __import__("csv").writer(ff, delimiter="\t", lineterminator="\n")
        wc.writerow(["GeneID"] + samples)
        wf.writerow(["GeneID"] + samples)
        for gid in gene_ids:
            row_c = [gid]
            row_f = [gid]
            for counts, lengths, total in data:
                mapped = counts.get(gid, 0)
                length = lengths.get(gid, 0)
                row_c.append(mapped)
                row_f.append(round(mapped * 1e9 / (length * total), 6) if length and total else 0)
            wc.writerow(row_c)
            wf.writerow(row_f)

    print("Wrote %s (%d genes x %d samples)" % (count_out, len(gene_ids), len(samples)))
    print("Wrote %s" % fpkm_out)


if __name__ == "__main__":
    main()
