#!/usr/bin/env python3
"""Merge normalized virus-host evidence and assign transparent consensus tiers.

Each input TSV must have: virus_id, host_id, method, score, detail. Rows remain
independent in evidence_long.tsv. Consensus is high for >=2 methods including
CRISPR or iPHoP, medium for >=2 methods, and single_method otherwise. Conflicting
hosts are retained and flagged rather than silently resolved.
"""
import argparse
import csv
from collections import defaultdict

parser = argparse.ArgumentParser()
parser.add_argument("--inputs", nargs="+", required=True)
parser.add_argument("--evidence-out", required=True)
parser.add_argument("--consensus-out", required=True)
args = parser.parse_args()

rows = []
for path in args.inputs:
    with open(path, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            rows.append(row)

with open(args.evidence_out, "w", newline="", encoding="utf-8") as handle:
    fields = ["virus_id", "host_id", "method", "score", "detail"]
    writer = csv.DictWriter(handle, fieldnames=fields, delimiter="\t", lineterminator="\n", extrasaction="ignore")
    writer.writeheader(); writer.writerows(rows)

support = defaultdict(set)
hosts_by_virus = defaultdict(set)
for row in rows:
    support[(row["virus_id"], row["host_id"])].add(row["method"].lower())
    hosts_by_virus[row["virus_id"]].add(row["host_id"])

with open(args.consensus_out, "w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
    writer.writerow(["virus_id", "host_id", "methods", "support_count", "tier", "conflict"])
    for (virus, host), methods in sorted(support.items()):
        if len(methods) >= 2 and ({"crispr", "iphop"} & methods): tier = "high"
        elif len(methods) >= 2: tier = "medium"
        else: tier = "single_method"
        writer.writerow([virus, host, ",".join(sorted(methods)), len(methods), tier,
                         "yes" if len(hosts_by_virus[virus]) > 1 else "no"])
