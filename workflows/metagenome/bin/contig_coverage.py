#!/usr/bin/env python3
"""Merge per-sample contig depth into a contig x sample coverage matrix.

Worker 04_contig_cov.sh 对每个样本输出:
  <sample>.depth.sum.tsv   contig<TAB>sum(depth)   (samtools depth 各位置深度求和)
  <sample>.length.tsv      contig<TAB>length       (samtools idxstats)

本脚本合并为:
  contig.depth.tsv         contig_id<TAB>length<TAB>sample1<TAB>sample2...
其中每个样本的值 = sum(depth) / contig_length（未覆盖到 = 0），
即该 contig 在该样本中的平均覆盖深度（reads/base，与 MetaBAT2 totalAvgDepth 口径一致）。
"""
import argparse
import os
import sys


def read_pairs(path):
    d = {}
    if not os.path.exists(path):
        return d
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 2:
                d[parts[0]] = parts[1]
    return d


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--depth-dir", required=True, help="含 <sample>.depth.sum.tsv 的目录")
    ap.add_argument("--samples", required=True, help="每行一个样本名")
    ap.add_argument("--output", required=True, help="输出 contig.depth.tsv")
    args = ap.parse_args()

    samples = [s for s in args.samples.splitlines() if s.strip()]
    if not samples:
        sys.exit("ERROR: 没有样本")

    # 长度表：contig -> length（所有样本一致，取第一个存在且非空的）
    lengths = {}
    for s in samples:
        if lengths:
            break
        lengths = read_pairs(os.path.join(args.depth_dir, "%s.length.tsv" % s))
    if not lengths:
        sys.exit("ERROR: 没有找到任何 <sample>.length.tsv（先运行 04_contig_cov.sh）")

    # 深度求和表：sample -> contig -> sum
    sums = {}
    for s in samples:
        sums[s] = read_pairs(os.path.join(args.depth_dir, "%s.depth.sum.tsv" % s))

    header = ["contig_id", "length"] + samples
    rows = []
    for cid in sorted(lengths):
        try:
            length = float(lengths[cid])
        except ValueError:
            length = 0.0
        row = [cid, lengths[cid]]
        for s in samples:
            total = sums[s].get(cid, "0")
            try:
                total = float(total)
            except ValueError:
                total = 0.0
            mean = total / length if length > 0 else 0.0
            row.append("%.4f" % mean)
        rows.append(row)

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, "w", encoding="utf-8", newline="") as fh:
        fh.write("\t".join(header) + "\n")
        for r in rows:
            fh.write("\t".join(r) + "\n")
    print("Wrote %s (%d contigs, %d samples)" % (args.output, len(rows), len(samples)))


if __name__ == "__main__":
    main()
