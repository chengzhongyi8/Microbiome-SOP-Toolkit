#!/usr/bin/env python3
"""Full outer join gene abundance, taxonomy and function tables by gene ID.

Inputs are TSV paths supplied as --abundance, --taxonomy and --function. The first
column is treated as gene ID. Missing annotation fields stay empty; missing numeric
abundance values are filled with 0.
"""
import argparse
import csv

parser = argparse.ArgumentParser()
parser.add_argument("--abundance", required=True)
parser.add_argument("--taxonomy", required=True)
parser.add_argument("--function", required=True)
parser.add_argument("--output", required=True)
args = parser.parse_args()

tables = []
all_ids = set()
for path in (args.abundance, args.taxonomy, args.function):
    with open(path, newline="", encoding="utf-8") as handle:
        reader = csv.reader(handle, delimiter="\t")
        header = next(reader)
        rows = {}
        for row in reader:
            if row and row[0] and not row[0].startswith("#"):
                rows[row[0]] = row[1:]
                all_ids.add(row[0])
        tables.append((header[1:], rows))

with open(args.output, "w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
    writer.writerow(["gene_id"] + tables[0][0] + tables[1][0] + tables[2][0])
    for gene_id in sorted(all_ids):
        abundance = tables[0][1].get(gene_id, ["0"] * len(tables[0][0]))
        taxonomy = tables[1][1].get(gene_id, [""] * len(tables[1][0]))
        function = tables[2][1].get(gene_id, [""] * len(tables[2][0]))
        writer.writerow([gene_id] + abundance + taxonomy + function)
