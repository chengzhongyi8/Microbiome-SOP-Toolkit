#!/usr/bin/env python3
"""合并 KofamScan final 注释（每 bin 一个 tsv）为：长表 + KO×Bin 计数矩阵 + best-hit 矩阵。

KofamScan detail-tsv final 文件列（6 列，tab 分隔）:
    * / <基因ID> / <KO> / <score> / <threshold> / <evalue> / "<KO 描述>"
    （行首 * = 通过阈值，final 文件只含 * 行）

用法:
    merge_kofam.py <final_dir> -o <out_prefix>
    例: merge_kofam.py results/mags/annotations/kofam/final -o results/mags/annotations/kofam/kofam_merged

输出（<out_prefix>.*）:
    kofam_merged.tsv            长表: Bin Gene KO Score Threshold Evalue KO_Desc
    KO_bin_matrix.tsv           计数矩阵: 行=KO 列=Bin 单元格=该 bin 注释到该 KO 的基因数
                                 （一个基因命中多 KO 时在每列各计一次）
    KO_bin_matrix_besthit.tsv   best-hit 矩阵: 每基因只取 score 最高的 KO 再计数
                                 （行合计 = 该 bin 有注释的基因数，严格 1:1）
    duplicate_genes.tsv         跨 bin 重复基因 ID 清单（存在重复时输出，否则不生成）
"""
import argparse
import csv
import os
import sys


def parse_final(path):
    """读取一个 final tsv，返回 {gene: [(ko, score), ...]} 与总行数。
    描述列可能含引号/空格，用 csv 解析。"""
    genes = {}
    with open(path, newline="") as fh:
        reader = csv.reader(fh, delimiter="\t")
        for row in reader:
            if len(row) < 3:
                continue
            gene = row[1].strip()
            ko = row[2].strip()
            try:
                score = float(row[3].strip())
            except ValueError:
                score = 0.0
            genes.setdefault(gene, []).append((ko, score))
    return genes


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("final_dir", help="KofamScan final 输出目录（*.kofam.final.tsv）")
    ap.add_argument("-o", "--out-prefix", required=True, help="输出文件前缀")
    args = ap.parse_args()

    final_dir = args.final_dir
    files = sorted(f for f in os.listdir(final_dir) if f.endswith(".kofam.final.tsv"))
    if not files:
        sys.exit(f"ERROR: {final_dir} 下没有 *.kofam.final.tsv")

    # bin 顺序按文件名排序；bin 名 = 去 .kofam.final.tsv 后缀
    bins = [f[: -len(".kofam.final.tsv")] for f in files]

    all_rows = []        # 长表行: (bin, gene, ko, score, threshold, evalue, desc)
    per_bin = {}         # bin -> {gene: [(ko, score), ...]}
    ko_desc = {}         # ko -> desc（取首个出现的描述）
    gene_bin = {}        # gene -> set(bin)  用于跨 bin 重复检查

    for b, f in zip(bins, files):
        path = os.path.join(final_dir, f)
        genes = parse_final(path)
        per_bin[b] = genes
        with open(path, newline="") as fh:
            reader = csv.reader(fh, delimiter="\t")
            for row in reader:
                if len(row) < 7:
                    continue
                gene, ko = row[1].strip(), row[2].strip()
                score = row[3].strip()
                thr = row[4].strip()
                ev = row[5].strip()
                desc = row[6].strip()
                all_rows.append((b, gene, ko, score, thr, ev, desc))
                ko_desc.setdefault(ko, desc)
        for g in genes:
            gene_bin.setdefault(g, set()).add(b)

    # 跨 bin 重复基因检查（fallback 合并路径会出现）
    dup = {g: sorted(bs) for g, bs in gene_bin.items() if len(bs) > 1}
    if dup:
        with open(args.out_prefix + ".duplicate_genes.tsv", "w") as fh:
            fh.write("Gene\tBins\n")
            for g in sorted(dup):
                fh.write(f"{g}\t{','.join(dup[g])}\n")
        print(f"WARN: {len(dup)} 个基因出现在多个 bin（可能走了 fallback 合并路径），"
              f"清单见 {args.out_prefix}.duplicate_genes.tsv", file=sys.stderr)

    # ---- 输出 1: 长表 ----
    long_path = args.out_prefix + ".kofam_merged.tsv"
    with open(long_path, "w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t", lineterminator="\n")
        w.writerow(["Bin", "Gene", "KO", "Score", "Threshold", "Evalue", "KO_Desc"])
        for row in all_rows:
            w.writerow(row)
    print(f"长表: {long_path} ({len(all_rows)} 行)")

    # ---- 输出 2/3: 计数矩阵 与 best-hit 矩阵 ----
    kos = sorted(ko_desc.keys())
    # 计数矩阵（多 KO 各计一次）
    with open(args.out_prefix + ".KO_bin_matrix.tsv", "w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t", lineterminator="\n")
        w.writerow(["KO"] + bins)
        for ko in kos:
            row = [ko]
            for b in bins:
                n = sum(1 for g, hits in per_bin[b].items() if any(h[0] == ko for h in hits))
                row.append(n)
            w.writerow(row)
    print(f"计数矩阵: {args.out_prefix}.KO_bin_matrix.tsv ({len(kos)} KO × {len(bins)} bin)")

    # best-hit 矩阵（每基因取 score 最高 KO，严格 1:1）
    with open(args.out_prefix + ".KO_bin_matrix_besthit.tsv", "w", newline="") as fh:
        w = csv.writer(fh, delimiter="\t", lineterminator="\n")
        w.writerow(["KO"] + bins)
        for ko in kos:
            row = [ko]
            for b in bins:
                n = 0
                for g, hits in per_bin[b].items():
                    best = max(hits, key=lambda h: h[1])[0]
                    if best == ko:
                        n += 1
                row.append(n)
            w.writerow(row)
    print(f"best-hit 矩阵: {args.out_prefix}.KO_bin_matrix_besthit.tsv")

    # 汇总统计
    total_genes = sum(len(g) for g in per_bin.values())
    print(f"汇总: {len(bins)} bin, {total_genes} 基因, {len(kos)} 唯一 KO")


if __name__ == "__main__":
    main()
