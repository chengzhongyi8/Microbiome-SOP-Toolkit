#!/usr/bin/env python3
"""合并 coverM genome 每样本输出为 MAG×样本 丰度矩阵。

coverM genome 单样本输出列（0.6+）:
    Genome  Contig  <sample>.<method> ...   (method ∈ coverage/relative_abundance/rpkm/tpm/...)

用法:
    merge_coverm.py <by_sample_dir> <sample1> [sample2 ...] > MAG_abundance.tsv

输出（stdout）:
    第一列 MAG（Genome），其后按方法分组、每组按样本排序输出列
    （如 MAG | <s1>.coverage <s2>.coverage ... | <s1>.relative_abundance ... | <s1>.rpkm ...）
    方法顺序取第一个样本文件表头的出现顺序；样本顺序按命令行给定；
    某样本无某方法/无输出时该单元格为空。
"""
import csv
import os
import sys


def read_sample(path):
    """返回 ({genome: {method: value}}, [methods])"""
    rows = {}
    methods = []
    with open(path, newline="") as fh:
        reader = csv.reader(fh, delimiter="\t")
        try:
            header = next(reader)
        except StopIteration:
            return rows, methods
        if not header:
            return rows, methods
        # 动态识别：Genome 列 = 无 "." 后缀的首列；指标列 = 最后一个 "." 后为方法名
        genome_idx = None
        col_method = {}          # col_idx -> method
        for i, col in enumerate(header):
            low = col.lower()
            if low == "genome":
                genome_idx = i
                continue
            if "." in low:
                m = low.rsplit(".", 1)[1]
                if m and m not in ("bam", "fq", "gz"):   # 排除文件名类伪列
                    col_method[i] = m
                    if m not in methods:
                        methods.append(m)
        if genome_idx is None:
            genome_idx = 0
        for row in reader:
            if len(row) <= genome_idx:
                continue
            g = row[genome_idx].strip()
            if not g:
                continue
            rec = rows.setdefault(g, {})
            for i, m in col_method.items():
                if i < len(row):
                    rec[m] = row[i]
    return rows, methods


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: merge_coverm.py <by_sample_dir> <sample1> [sample2 ...]")
    by_dir = sys.argv[1]
    samples = sys.argv[2:]

    per_sample = []          # [(sample, {genome: {method: value}})]
    genomes_ordered = []
    seen = set()
    all_methods = []         # 方法全局顺序：按首个有输出的样本文件的表头顺序
    for s in samples:
        path = os.path.join(by_dir, f"{s}.tsv")
        if not os.path.isfile(path):
            per_sample.append((s, {}))
            continue
        rec, methods = read_sample(path)
        if not all_methods and methods:
            all_methods = methods
        per_sample.append((s, rec))
        for g in rec:
            if g not in seen:
                seen.add(g)
                genomes_ordered.append(g)

    # 输出：按方法分组，组内按样本顺序
    header = ["MAG"]
    for m in all_methods:
        header += [f"{s}.{m}" for s in samples]
    print("\t".join(header))
    for g in genomes_ordered:
        cells = [g]
        for m in all_methods:
            for _, rec in per_sample:
                cells.append(rec.get(g, {}).get(m, ""))
        print("\t".join(cells))


if __name__ == "__main__":
    main()
