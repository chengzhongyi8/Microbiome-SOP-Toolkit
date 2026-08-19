#!/usr/bin/env python3
"""Merge gene abundance matrix with MEGAN blast2lca output -> per-level taxa tables.

Abundance matrix: tab-separated, first column gene id, remaining columns samples.
LCA file: first field per line is the query/gene id; the rest of the line may
contain MEGAN taxpath tokens like `d__Bacteria; p__Proteobacteria; ...`
(with or without numeric taxids interspersed). Rank-prefixed tokens are parsed
preferentially; otherwise a positional fallback is used.

Outputs (in --outdir):
  gene_taxonomy.tsv                       gene -> 7 rank assignment
  Table_taxa_Domain.tsv ... Table_taxa_Species.tsv   abundance summed per taxon

Only the Python standard library is used.
"""
import argparse
import os
import re
import sys

RANKS = ["domain", "phylum", "class", "order", "family", "genus", "species"]
PREFIXES = {"d__": "domain", "p__": "phylum", "c__": "class", "o__": "order",
            "f__": "family", "g__": "genus", "s__": "species"}

TOKEN_RE = re.compile(r"(?P<rank>d__|p__|c__|o__|f__|g__|s__)(?P<name>[^;\t]+)")


def parse_taxpath(raw):
    """Return dict rank -> name (missing ranks become 'Unclassified').

    MEGAN blast2lca 常见两种输出：
      tab 格式:   qseqid<TAB>d__Bacteria; 2; p__...; ...
      分号格式:   qseqid; ;d__Bacteria; 100;p__...; ...   (MEGAN 6.12)
    本函数对 raw（基因名之后的部分）统一用 rank 前缀正则提取；
    同一层级出现多个候选（如两个 s__）时保留第一个（PDF 原代码也是取第一个）。
    """
    tax = {r: "Unclassified" for r in RANKS}
    if not raw or raw.strip() in ("", "unclassified", "Unclassified"):
        return tax

    tokens = []
    for m in TOKEN_RE.finditer(raw):
        tokens.append((PREFIXES[m.group("rank")], m.group("name").strip()))
    if tokens:
        for rank, name in tokens:
            # 字典已预填 Unclassified，只有仍为 Unclassified 时才赋值（保留第一个候选）
            if name and tax[rank] == "Unclassified":
                tax[rank] = name
        return tax

    # Fallback: split on ';' or tab, drop numeric ids / empty / 'unclassified'
    parts = [p.strip() for p in re.split(r"[;\t]+", raw)]
    named = [p for p in parts if p and not p.isdigit() and p.lower() != "unclassified"]
    for rank, name in zip(RANKS, named):
        tax[rank] = name
    return tax


def read_abundance(path):
    genes = {}
    samples = []
    with open(path, encoding="utf-8") as fh:
        header = fh.readline().rstrip("\n").split("\t")
        samples = header[1:]
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if not parts or not parts[0]:
                continue
            gid = parts[0]
            vals = []
            for p in parts[1:]:
                try:
                    vals.append(float(p))
                except ValueError:
                    vals.append(0.0)
            genes[gid] = vals
    return genes, samples


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--abundance", required=True, help="gene TPM/count matrix (tab)")
    ap.add_argument("--lca", required=True, help="blast2lca output")
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--filter", choices=["all", "bacteria"], default="all")
    args = ap.parse_args()

    genes, samples = read_abundance(args.abundance)
    if not genes:
        sys.exit("ERROR: abundance matrix is empty")

    lca = {}
    with open(args.lca, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line:
                continue
            line = line.rstrip(";").rstrip()
            if "\t" in line:
                gid, raw = line.split("\t", 1)
            else:
                # 分号格式：第一个字段是基因名，其余是 taxpath（含空字段和分数）
                parts = line.split(";")
                gid = parts[0].strip()
                raw = ";".join(parts[1:])
            if not gid or gid in lca:
                continue
            lca[gid] = parse_taxpath(raw)

    # Per-gene taxonomy table + per-rank sums
    os.makedirs(args.outdir, exist_ok=True)
    level_sums = {r: {} for r in RANKS}
    with open(os.path.join(args.outdir, "gene_taxonomy.tsv"), "w", encoding="utf-8", newline="") as fg:
        fg.write("gene_id\t" + "\t".join(RANKS) + "\n")
        for gid, vals in genes.items():
            tax = lca.get(gid, {r: "Unclassified" for r in RANKS})
            fg.write(gid + "\t" + "\t".join(tax[r] for r in RANKS) + "\n")
            if args.filter == "bacteria" and tax["domain"].lower() not in ("d__bacteria", "bacteria"):
                continue
            for i, rank in enumerate(RANKS):
                name = tax[rank]
                if name == "Unclassified":
                    # 更高层级已确定时也保留（如只到属），全部未知的行在 all 模式下保留
                    pass
                bucket = level_sums[rank].setdefault(name, [0.0] * len(samples))
                for j, v in enumerate(vals):
                    bucket[j] += v

    # Write per-rank tables
    for rank in RANKS:
        out = os.path.join(args.outdir, "Table_taxa_%s.tsv" % rank.capitalize())
        names = sorted(level_sums[rank].keys())
        with open(out, "w", encoding="utf-8", newline="") as fh:
            fh.write(rank.capitalize() + "\t" + "\t".join(samples) + "\n")
            for name in names:
                vals = ["%.6g" % v for v in level_sums[rank][name]]
                fh.write(name + "\t" + "\t".join(vals) + "\n")
        print("Wrote %s (%d taxa)" % (out, len(names)))


if __name__ == "__main__":
    main()
