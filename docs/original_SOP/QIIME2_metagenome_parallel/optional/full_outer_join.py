#!/usr/bin/env python3
"""Full outer join two-column or multi-column TSV matrices by first column.

Unlike shell `join`, inputs need not be sorted and IDs present in only one file are
retained. Duplicate IDs within a file are rejected. Missing values are filled with 0.
"""
import argparse
import csv

parser = argparse.ArgumentParser()
parser.add_argument("inputs", nargs="+")
parser.add_argument("--output", required=True)
args = parser.parse_args()

headers, tables, ids = [], [], set()
for path in args.inputs:
    with open(path, newline="", encoding="utf-8") as handle:
        reader = csv.reader(handle, delimiter="\t")
        header = next(reader)
        table = {}
        for row in reader:
            if not row or not row[0]: continue
            if row[0] in table: raise SystemExit(f"duplicate ID in {path}: {row[0]}")
            table[row[0]] = row[1:]
            ids.add(row[0])
        headers.append(header[1:]); tables.append(table)

with open(args.output, "w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
    writer.writerow(["feature_id"] + [x for h in headers for x in h])
    for feature_id in sorted(ids):
        values = []
        for header, table in zip(headers, tables):
            values.extend(table.get(feature_id, ["0"] * len(header)))
        writer.writerow([feature_id] + values)
