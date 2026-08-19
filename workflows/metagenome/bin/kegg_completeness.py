#!/usr/bin/env python3
"""KEGG Pathway / Module completeness analysis from eggNOG-mapper annotations.

Inputs:
  --annotations     eggNOG-mapper <prefix>.emapper.annotations
  --abundance       gene TPM/count matrix (tab, first column gene id)
  --module-def      (optional) KEGG module.ko 定义文件
                    ftp://ftp.genome.jp/pub/kegg/module/module.ko
  --module-name     (optional) KEGG module 名称文件
                    ftp://ftp.genome.jp/pub/kegg/module/module
  --pathway-def     (optional) KEGG ko00001.keg 层级文件
                    ftp://ftp.genome.jp/pub/kegg/brite/ko/ko00001.keg
  --outdir          output directory
  --threshold       completeness >= 该值判定为 Complete (default 1.0)

Outputs (module):
  KEGG_module_completeness.tsv   完整度矩阵（需 --module-def）
  KEGG_module_detected.tsv       仅检测表（无定义文件时，来自 emapper KEGG_Module 列）
Outputs (pathway):
  KEGG_pathway_completeness.tsv  完整度矩阵（需 --pathway-def）
  KEGG_pathway_detected.tsv      仅检测表（无定义文件时，来自 emapper KEGG_Pathway 列）

完整度定义：某样本中该 module/pathway 定义内的 KOs，被该样本中丰度>0 的基因
覆盖的比例（present KOs / 定义内 KOs）。这是常见的“KO 覆盖度”近似，
不区分 pathway 内部的分支/模块步骤结构（如需严格步骤级，可用 anvio 等工具）。
"""
import argparse
import os
import re
import sys

KO_RE = re.compile(r"K\d{5}")

FIXED_COLS = {"query": 0, "KEGG_ko": 8, "KEGG_Pathway": 9, "KEGG_Module": 10}   # v2 标准 0-indexed 列位

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
    if not text or text in ("-", "NA"):
        return []
    out = []
    for x in re.split(r"[,;]", text):
        x = x.strip()
        if not x or x == "-":
            continue
        # 去掉可能的 "ko:" 前缀，保留字母数字
        x = re.sub(r"^[^:]+:", "", x)
        out.append(x)
    return out


def load_annotations(path):
    """Return dict gene -> {"KO": [...], "Pathway": [...], "Module": [...]}."""
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.readlines()
    header_line = lines[0].lstrip("#").rstrip("\n") if lines else ""
    names = header_line.split("\t")
    has_header = bool(names) and (
        names[0].strip().lower() in ("query", "gene_id") or
        lines[0].lstrip().startswith("#"))
    if has_header:
        cols = resolve_cols(names, FIXED_COLS)
        # 表头缺 KEGG 列名时，用数据探测补上
        probe_rows = [l.rstrip("\n").split("\t") for l in lines[1:21] if l.strip()]
        cols = detect_cols(probe_rows, cols)
    else:
        # 无表头（老版 emapper 配 --no_file_comments）：整表探测
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
        kos = [k for k in split_ann(get("KEGG_ko")) if re.match(r"^K\d{5}$", k)]
        ann[gid] = {
            "KO": kos,
            "Pathway": split_ann(get("KEGG_Pathway")),
            "Module": split_ann(get("KEGG_Module")),
        }
    return ann


def load_module_def(path):
    """module.ko: M00001<TAB>K00844 K12407 ..."""
    defs = {}
    if not path:
        return defs
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                continue
            mid = parts[0].strip()
            kos = KO_RE.findall(parts[1])
            if mid.startswith("M") and kos:
                defs[mid] = set(kos)
    return defs


def load_module_names(path):
    """module: M00001<TAB>name"""
    names = {}
    if not path:
        return names
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if not line or line.startswith("#"):
                continue
            if "\t" in line:
                mid, name = line.split("\t", 1)
                names[mid.strip()] = name.strip()
    return names


def load_pathway_def(path):
    """ko00001.keg 层级文件（真实格式，空格对齐，兼容 tab）：

        +D  KO                      <- 残留/注释行（跳过：以 + # ! 开头）
        #<h2>...</h2>               <- HTML 残留（跳过）
        !
        A09100 Metabolism           <- A 行：L1 层级（不是通路，跳过）
        B
        B  09101 Carbohydrate metabolism   <- B 行：L2 层级（跳过）
        C    00010 Glycolysis / Gluconeogenesis [PATH:ko00010]  <- C 行：通路！
        D      K00844  HK; hexokinase [EC:2.7.1.1]              <- D 行：KO

    返回 { koXXXXX : {"name": ..., "kos": set(...)} }
    """
    defs = {}
    if not path:
        return defs
    current = None
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.rstrip("\n")
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or stripped.startswith("+"):
                continue
            parts = line.split()          # 兼容空格/tab 对齐
            if not parts:
                continue
            code = parts[0]
            if code == "C" and len(parts) >= 2:
                # 通路行：优先 [PATH:koXXXXX]，否则取第 2 个字段（5 位数字补 ko 前缀）
                pid = None
                m = re.search(r"\[PATH:\s*(ko\d{5})\]", line)
                if m:
                    pid = m.group(1)
                else:
                    pid = parts[1]
                    if re.match(r"^\d{5}$", pid):
                        pid = "ko" + pid
                    else:
                        pid = None
                if pid == "ko00001":      # 根节点（KO 层级）不算通路
                    current = None
                    continue
                if not pid:
                    continue
                name = re.sub(r"\[PATH:[^\]]*\]", "", line)
                name = name.replace(pid, "", 1).replace("C", "", 1).strip()
                current = pid
                defs.setdefault(pid, {"name": name, "kos": set()})
            elif code == "D" and current is not None:
                for ko in KO_RE.findall(line):
                    defs[current]["kos"].add(ko)
    return defs


def write_tsv(path, header, rows):
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write("\t".join(header) + "\n")
        for r in rows:
            fh.write("\t".join(str(x) for x in r) + "\n")
    print("Wrote %s (%d entries)" % (path, len(rows)))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--annotations", required=True)
    ap.add_argument("--abundance", required=True)
    ap.add_argument("--outdir", required=True)
    ap.add_argument("--module-def", default="")
    ap.add_argument("--module-name", default="")
    ap.add_argument("--pathway-def", default="")
    ap.add_argument("--threshold", type=float, default=1.0)
    ap.add_argument("--min-abundance", type=float, default=0.0)
    args = ap.parse_args()

    genes, samples = read_abundance(args.abundance)
    ann = load_annotations(args.annotations)
    os.makedirs(args.outdir, exist_ok=True)

    # 每个样本：丰度>0 的基因及其 KO / Module / Pathway
    sample_presence = {s: {"KO": set(), "Module": set(), "Pathway": set()}
                       for s in samples}
    for gid, vals in genes.items():
        a = ann.get(gid, {"KO": [], "Module": [], "Pathway": []})
        for j, s in enumerate(samples):
            if vals[j] <= args.min_abundance:
                continue
            sample_presence[s]["KO"].update(a["KO"])
            sample_presence[s]["Module"].update(a["Module"])
            sample_presence[s]["Pathway"].update(a["Pathway"])

    threshold = max(0.0, min(1.0, args.threshold))

    # ---- Module -------------------------------------------------------------
    mod_def = load_module_def(args.module_def)
    mod_names = load_module_names(args.module_name)
    if mod_def:
        rows = []
        for mid in sorted(mod_def):
            kos = sorted(mod_def[mid])
            if not kos:                       # 空模块（无 KO 定义）跳过
                continue
            row = [mid, mod_names.get(mid, ""), len(kos)]
            for s in samples:
                n = len(set(kos) & sample_presence[s]["KO"])
                row.append(n)
                row.append(round(n / len(kos), 6))
                row.append(1 if n / len(kos) >= threshold else 0)
            rows.append(row)
        header = (["module_id", "name", "n_steps"] +
                  [x for s in samples for x in ("n_present_%s" % s, "completeness_%s" % s, "complete_%s" % s)])
        write_tsv(os.path.join(args.outdir, "KEGG_module_completeness.tsv"), header, rows)
        # 完整模块数统计
        for s in samples:
            col = header.index("complete_%s" % s)
            n_complete = sum(1 for r in rows if r[col] == 1)
            print("  [%s] module complete: %d / %d" % (s, n_complete, len(rows)))
    else:
        rows = []
        for mid in sorted(set().union(*[sample_presence[s]["Module"] for s in samples]) if samples else set()):
            row = [mid]
            for s in samples:
                row.append(1 if mid in sample_presence[s]["Module"] else 0)
            rows.append(row)
        header = ["module_id"] + samples
        write_tsv(os.path.join(args.outdir, "KEGG_module_detected.tsv"), header, rows)
        print("  NOTE: 未提供 --module-def（module.ko），只输出模块检测表；"
              "需要完整度请下载 KEGG module.ko 并配置 KEGG_MODULE_DEF")

    # ---- Pathway ------------------------------------------------------------
    pw_def = load_pathway_def(args.pathway_def)
    if pw_def:
        rows = []
        for pid in sorted(pw_def):
            info = pw_def[pid]
            kos = sorted(info["kos"])
            if not kos:                       # 空通路（无 KO 定义）跳过
                continue
            row = [pid, info["name"], len(kos)]
            for s in samples:
                n = len(set(kos) & sample_presence[s]["KO"])
                row.append(n)
                row.append(round(n / len(kos), 6))
                row.append(1 if n / len(kos) >= threshold else 0)
            rows.append(row)
        header = (["pathway_id", "name", "n_steps"] +
                  [x for s in samples for x in ("n_present_%s" % s, "completeness_%s" % s, "complete_%s" % s)])
        write_tsv(os.path.join(args.outdir, "KEGG_pathway_completeness.tsv"), header, rows)
        for s in samples:
            col = header.index("complete_%s" % s)
            n_complete = sum(1 for r in rows if r[col] == 1)
            print("  [%s] pathway complete: %d / %d" % (s, n_complete, len(rows)))
    else:
        rows = []
        all_pw = set().union(*[sample_presence[s]["Pathway"] for s in samples]) if samples else set()
        for pid in sorted(all_pw):
            row = [pid]
            for s in samples:
                row.append(1 if pid in sample_presence[s]["Pathway"] else 0)
            rows.append(row)
        header = ["pathway_id"] + samples
        write_tsv(os.path.join(args.outdir, "KEGG_pathway_detected.tsv"), header, rows)
        print("  NOTE: 未提供 --pathway-def（ko00001.keg），只输出通路检测表；"
              "需要完整度请下载 KEGG ko00001.keg 并配置 KEGG_PATHWAY_DEF")


if __name__ == "__main__":
    main()
