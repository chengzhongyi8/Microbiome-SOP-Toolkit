#!/usr/bin/env python3
"""Summarize eggNOG-mapper annotations into KO / CAZy / COG abundance tables.

Inputs:
  --abundance     gene TPM/count matrix (tab, first column gene id)
  --annotations   eggNOG-mapper <prefix>.emapper.annotations
  --outdir        output directory
  --ko-description (optional) tab file: KO id -> description

Outputs:
  gene_annotation.tsv     gene -> KO / CAZy / COG / Description
  KO.tsv / CAZy.tsv / COG.tsv   aggregated abundance per annotation

Header columns are located by name when possible (handles emapper v1/v2),
otherwise fixed positions are assumed.
"""
import argparse
import os
import re
import sys

COG_CATEGORIES = {
    "A": "RNA processing and modification", "B": "Chromatin structure and dynamics",
    "C": "Energy production and conversion", "D": "Cell cycle control, cell division",
    "E": "Amino acid transport and metabolism", "F": "Nucleotide transport and metabolism",
    "G": "Carbohydrate transport and metabolism", "H": "Coenzyme transport and metabolism",
    "I": "Lipid transport and metabolism", "J": "Translation, ribosomal structure",
    "K": "Transcription", "L": "Replication, recombination and repair",
    "M": "Cell wall/membrane/envelope biogenesis", "N": "Cell motility",
    "O": "Post-translational modification, chaperones", "P": "Inorganic ion transport",
    "Q": "Secondary metabolites biosynthesis", "R": "General function prediction only",
    "S": "Function unknown", "T": "Signal transduction mechanisms",
    "U": "Intracellular trafficking, secretion", "V": "Defense mechanisms",
    "W": "Extracellular structures", "X": "Mobilome: prophages, transposons",
    "Y": "Nuclear structure", "Z": "Cytoskeleton",
}

FIXED_COLS = {"query": 0, "KEGG_ko": 8, "KEGG_Pathway": 9, "KEGG_Module": 10, "CAZy": 15, "COG_category": 20, "Description": 21}   # v2 标准 0-indexed 列位

COL_ALIASES = {
    "query": ["query", "gene_id", "Query"],
    "KEGG_ko": ["KEGG_ko", "KEGG_KOs", "KEGG_KO", "KO", "KEGG_orthology"],
    "KEGG_Pathway": ["KEGG_Pathway", "KEGG_Pathways", "Pathway", "KEGG_PATHWAY"],
    "KEGG_Module": ["KEGG_Module", "KEGG_Modules", "Module", "KEGG_MODULE"],
    "CAZy": ["CAZy", "CAZymes", "cazy"],
    "COG_category": ["COG_category", "COG", "COG_Category", "COG_cat"],
    "Description": ["Description", "description", "DE"],
}


def resolve_cols(names, fixed):
    """按表头列名（含别名）定位列；找不到的名字回退 fixed 位置。"""
    cols = dict(fixed)
    if not names:
        return cols
    for key, aliases in COL_ALIASES.items():
        for a in aliases:
            if a in names:
                cols[key] = names.index(a)
                break
    return cols



KO_TOKEN = re.compile(r"^K\d{5}$")
PW_TOKEN = re.compile(r"^ko\d{5}$")
MD_TOKEN = re.compile(r"^M\d{5}$")
CAZY_TOKEN = re.compile(r"^(GH|GT|CBM|CE|AA|PL)\d+(?:_\d+)?$")   # 支持 GH5_1 亚家族
COG_TOKEN = re.compile(r"^[A-Z]$")          # COG 类别：单大写字母（可逗号分隔）


def detect_cols(rows, fixed):
    """无表头时按 token 类型探测 KEGG/CAZy/COG/Description 列位置；探测不到回退 fixed。"""
    cols = dict(fixed)
    ncols = max((len(r) for r in rows), default=0)
    if ncols == 0:
        return cols
    ko_c = [0] * ncols
    pw_c = [0] * ncols
    md_c = [0] * ncols
    cazy_c = [0] * ncols
    cog_c = [0] * ncols
    desc_c = [0] * ncols
    for r in rows[:500]:                     # 多看一些行，提高命中率
        for i in range(min(len(r), ncols)):
            for tok in re.split(r"[,;]", r[i]):
                tok = tok.strip()
                if tok == "-" or not tok:
                    continue
                tok2 = re.sub(r"^[^:]+:", "", tok)   # 去掉 ko: 等前缀，与 split_ann 一致
                if KO_TOKEN.match(tok2):
                    ko_c[i] += 1
                elif PW_TOKEN.match(tok):    # 通路列值直接是 koXXXXX（不带前缀）；BRITE 的 br:koXXXXX 不匹配
                    pw_c[i] += 1
                elif MD_TOKEN.match(tok2):
                    md_c[i] += 1
                elif CAZY_TOKEN.match(tok2):
                    cazy_c[i] += 1
                elif COG_TOKEN.match(tok2):
                    cog_c[i] += 1
                elif " " in tok2 and len(tok2) > 6:
                    desc_c[i] += 1

    def best(arr):
        m = max(arr) if arr else 0
        return arr.index(m) if m > 0 else None

    probes = [("KEGG_ko", ko_c), ("KEGG_Pathway", pw_c),
              ("KEGG_Module", md_c), ("CAZy", cazy_c),
              ("COG_category", cog_c), ("Description", desc_c)]
    for key, arr in probes:
        i = best(arr)
        if i is not None:
            cols[key] = i
    # 结构性回退：emapper v1/v2 列序稳定
    #   CAZy = KEGG_ko + 7（v1: 12->19, v2: 8->15）
    #   KEGG_Pathway = KEGG_Module - 1（v1: 14->13, v2: 10->9；BRITE 列会干扰探测故用结构推断）
    if cols.get("CAZy", -1) == fixed.get("CAZy", -1) and cols.get("KEGG_ko", -1) > 0:
        cand = cols["KEGG_ko"] + 7
        if cand < ncols:
            cols["CAZy"] = cand
    if cols.get("KEGG_Pathway", -1) == fixed.get("KEGG_Pathway", -1) and cols.get("KEGG_Module", -1) > 1:
        cand = cols["KEGG_Module"] - 1
        if cand >= 0:
            cols["KEGG_Pathway"] = cand
    print("    [列位探测] query=%d KEGG_ko=%d KEGG_Pathway=%d KEGG_Module=%d CAZy=%d COG_category=%d Description=%d"
          % (cols.get("query", 0), cols.get("KEGG_ko", -1), cols.get("KEGG_Pathway", -1),
             cols.get("KEGG_Module", -1), cols.get("CAZy", -1), cols.get("COG_category", -1),
             cols.get("Description", -1)))
    return cols




def load_ko_description(path):
    d = {}
    if not path:
        return d
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 2:
                d[parts[0]] = parts[1]
    return d


def read_abundance(path):
    genes, samples = {}, []
    with open(path, encoding="utf-8") as fh:
        header = fh.readline().rstrip("\n").split("\t")
        samples = header[1:]
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if not parts or not parts[0]:
                continue
            vals = []
            for p in parts[1:]:
                try:
                    vals.append(float(p))
                except ValueError:
                    vals.append(0.0)
            genes[parts[0]] = vals
    return genes, samples


def split_ann(text):
    """Split a multi-annotation cell (e.g. 'ko:K00001,ko:K00002')."""
    if not text or text in ("-", "NA"):
        return []
    return [x.strip() for x in re.split(r"[,;]", text) if x.strip() and x.strip() != "-"]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--abundance", required=True)
    ap.add_argument("--annotations", required=True)
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--ko-description", default="")
    args = ap.parse_args()

    genes, samples = read_abundance(args.abundance)
    ko_desc = load_ko_description(args.ko_description)

    # Locate columns in annotation header
    with open(args.annotations, encoding="utf-8", errors="replace") as fh:
        lines = fh.readlines()
    header_line = lines[0].lstrip("#").rstrip("\n") if lines else ""
    names = header_line.split("\t")
    has_header = bool(names) and (
        names[0].strip().lower() in ("query", "gene_id") or
        lines[0].lstrip().startswith("#"))
    if has_header:
        cols = resolve_cols(names, FIXED_COLS)
        probe_rows = [l.rstrip("\n").split("\t") for l in lines[1:21] if l.strip()]
        cols = detect_cols(probe_rows, cols)
    else:
        probe_rows = [l.rstrip("\n").split("\t") for l in lines[:21] if l.strip()]
        cols = detect_cols(probe_rows, dict(FIXED_COLS))
        cols["query"] = 0

    ann = {}
    for line in lines:
        if line.startswith("#") and "query" not in line:
            continue
        parts = line.rstrip("\n").split("\t")
        if len(parts) <= cols["query"]:
            continue
        gid = parts[cols["query"]]
        get = lambda key: parts[cols[key]] if len(parts) > cols[key] else ""
        ann[gid] = {
            "KO": split_ann(get("KEGG_ko")),
            "CAZy": split_ann(get("CAZy")),
            "COG": split_ann(get("COG_category")),
            "desc": get("Description"),
        }

    os.makedirs(args.outdir, exist_ok=True)
    ko_sums, cazy_sums, cog_sums = {}, {}, {}
    with open(os.path.join(args.outdir, "gene_annotation.tsv"), "w", encoding="utf-8", newline="") as fg:
        fg.write("gene_id\tKO\tCAZy\tCOG\tDescription\n")
        for gid, vals in genes.items():
            a = ann.get(gid, {"KO": [], "CAZy": [], "COG": [], "desc": ""})
            fg.write(gid + "\t" + ",".join(a["KO"]) + "\t" + ",".join(a["CAZy"]) +
                     "\t" + ",".join(a["COG"]) + "\t" + a["desc"].replace("\t", " ") + "\n")
            for ko in a["KO"]:
                key = ko.replace("ko:", "")
                bucket = ko_sums.setdefault(key, [0.0] * len(samples))
                for j, v in enumerate(vals):
                    bucket[j] += v
            for cazy in a["CAZy"]:
                bucket = cazy_sums.setdefault(cazy, [0.0] * len(samples))
                for j, v in enumerate(vals):
                    bucket[j] += v
            for cog in a["COG"]:
                key = cog.split(".")[0] if cog else cog
                bucket = cog_sums.setdefault(key, [0.0] * len(samples))
                for j, v in enumerate(vals):
                    bucket[j] += v

    def write_table(path, sums, desc_fn):
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write("id\tdescription\t" + "\t".join(samples) + "\n")
            for key in sorted(sums):
                vals = ["%.6g" % v for v in sums[key]]
                fh.write(key + "\t" + (desc_fn(key) or "") + "\t" + "\t".join(vals) + "\n")
        print("Wrote %s (%d entries)" % (path, len(sums)))

    write_table(os.path.join(args.outdir, "KO.tsv"), ko_sums, lambda k: ko_desc.get(k, ""))
    write_table(os.path.join(args.outdir, "CAZy.tsv"), cazy_sums, lambda k: "")
    write_table(os.path.join(args.outdir, "COG.tsv"), cog_sums,
                lambda k: COG_CATEGORIES.get(k.upper(), ""))


if __name__ == "__main__":
    main()
