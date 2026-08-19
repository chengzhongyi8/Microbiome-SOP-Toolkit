#!/usr/bin/env python3
"""Minimal stubs for end-to-end dry-run of the metagenome SOP.
Each symlinked name dispatches to a fake implementation that creates just
enough output files for the next module step to continue.
"""
import os
import shutil
import sys

TOOL = os.path.basename(sys.argv[0])
ARGS = sys.argv[1:]

if ARGS and ARGS[0] in ("--version", "-v", "--help"):
    print("%s stub 0.0" % TOOL)
    sys.exit(0)


def get(args, *names, default=None):
    for i, a in enumerate(args):
        if a in names and i + 1 < len(args):
            return args[i + 1]
    return default


def fa_headers(path):
    hs = []
    try:
        with open(path) as fh:
            for line in fh:
                if line.startswith(">"):
                    hs.append(line[1:].strip())
    except OSError:
        pass
    return hs


def write_fasta(path, seqs):
    with open(path, "w") as fh:
        for name, seq in seqs:
            fh.write(">%s\n%s\n" % (name, seq))


# ---------------------------------------------------------------------------
if TOOL == "parallel":
    toks = ARGS
    sep = None
    for i, a in enumerate(toks):
        if a in ("::::", ":::"):
            sep = i
            break
    if sep is None:
        sys.exit("stub parallel: no ::: separator")
    cmd = toks[sep - 1] if sep >= 1 else ""
    items = toks[sep + 1:]
    mode = toks[sep]
    for item in items:
        if mode == "::::":
            with open(item) as fh:
                for line in fh:
                    line = line.rstrip("\n")
                    if not line:
                        continue
                    parts = line.split("\t")
                    body = cmd
                    body = body.replace("{}", line)
                    for idx, name in enumerate(("1", "2", "3", "4", "5"), start=1):
                        body = body.replace("{%s}" % name,
                                            parts[idx - 1] if len(parts) >= idx else "")
                    code = 'set -- %s; %s' % (
                        " ".join('"%s"' % __import__("shlex").quote(x) for x in parts), body)
                    os.system("bash -c " + __import__("shlex").quote(code))
        else:
            body = cmd.replace("{}", item)
            os.system("bash -c " + __import__("shlex").quote('set -- "%s"; %s' % (item, body)))

elif TOOL == "seqkit":
    if ARGS and ARGS[0] == "split2":
        outdir = get(ARGS, "--out-dir", "-O", default=".")
        inp = ARGS[-1]
        os.makedirs(outdir, exist_ok=True)
        name = os.path.basename(inp) + ".part_001" + os.path.splitext(inp)[1]
        shutil.copy(inp, os.path.join(outdir, name))
    elif ARGS and ARGS[0] == "stat":
        inp = ARGS[-1]
        print("%s\t1\t100\t100\t100\t100" % inp)
    elif ARGS and ARGS[0] in ("rmdup", "translate", "seq"):
        # find input = last non-flag arg
        inp = ARGS[-1]
        with open(inp) as fh:
            sys.stdout.write(fh.read())
    else:
        sys.exit("stub seqkit: unknown mode")

elif TOOL == "megahit":
    outdir = get(ARGS, "-o", default="megahit_out")
    os.makedirs(outdir, exist_ok=True)
    write_fasta(os.path.join(outdir, "final.contigs.fa"),
                [("k141_0", "ACGT" * 250), ("k141_1", "TGCA" * 250)])

elif TOOL == "prodigal":
    inp = get(ARGS, "-i", default="")
    dout = get(ARGS, "-d", default="out.fna")
    aout = get(ARGS, "-a", default="out.faa")
    gout = get(ARGS, "-o", default="out.gff")
    headers = fa_headers(inp)
    write_fasta(dout, [("%s_1" % h.split()[0], "ATGCGT" * 50) for h in headers])
    write_fasta(aout, [("%s_1" % h.split()[0], "MRT" * 50) for h in headers])
    with open(gout, "w") as fh:
        for h in headers:
            fh.write("%s\tprodigal\tCDS\t1\t300\t.\t+\t0\tID=%s_1;partial=00\n" % (h.split()[0], h.split()[0]))

elif TOOL == "mmseqs":
    # mmseqs easy-linclust IN OUT TMP ...
    if ARGS and ARGS[0] == "easy-linclust":
        inp, out, tmp = ARGS[1], ARGS[2], ARGS[3]
        os.makedirs(tmp, exist_ok=True)
        shutil.copy(inp, out + "_rep_seq.fasta")
    else:
        sys.exit("stub mmseqs: unknown mode")

elif TOOL == "cd-hit-est":
    inp = get(ARGS, "-i", default="")
    out = get(ARGS, "-o", default="out.fa")
    shutil.copy(inp, out)

elif TOOL == "salmon":
    if ARGS and ARGS[0] == "index":
        idx = get(ARGS, "-i", default="index")
        os.makedirs(idx, exist_ok=True)
        open(os.path.join(idx, "versionInfo.json"), "w").write("{}")
    elif ARGS and ARGS[0] == "quant":
        out = get(ARGS, "-o", default="quant_out")
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, "quant.sf"), "w") as fh:
            fh.write("Name\tLength\tEffectiveLength\tTPM\tNumReads\n")
            fh.write("Unigene1\t300\t300\t100.0\t10\n")
    elif ARGS and ARGS[0] == "quantmerge":
        out = ARGS[-1]
        with open(out, "w") as fh:
            fh.write("Name\tS1\tS2\nUnigene1\t10\t20\n")
    else:
        sys.exit("stub salmon: unknown mode")

elif TOOL == "bwa":
    if ARGS and ARGS[0] == "index":
        prefix = get(ARGS, "-p", default="idx")
        for ext in (".bwt", ".pac", ".ann", ".amb", ".sa"):
            open(prefix + ext, "w").close()
    elif ARGS and ARGS[0] == "mem":
        r1 = ARGS[-2]
        r2 = ARGS[-1]
        sys.stdout.write("@HD\tVN:1.0\n")
        sys.stdout.write("@SQ\tSN:Unigene1\tLN:300\n")
        for f in (r1, r2):
            with open(f) as fh:
                for line in fh:
                    if line.startswith("@"):
                        sys.stdout.write("%s\t0\tUnigene1\t1\t60\t10M\t*\t0\t0\tACGTACGTAC\tIIIIIIIII\tAS:i:0\n"
                                         % line[1:].strip())
                        break
    else:
        sys.exit("stub bwa: unknown mode")

elif TOOL == "samtools":
    if ARGS and ARGS[0] == "view":
        # 支持落盘: view -b -F <flag> -o out.bam in.sam / view -c in.bam
        out = get(ARGS, "-o", default=None)
        count = "-c" in ARGS
        infile = None
        for a in reversed(ARGS[1:]):
            if not a.startswith("-") and not a.startswith("@") and a != "0x904":
                infile = a
                break
        payload = b""
        if infile and os.path.exists(infile):
            with open(infile, "rb") as fh:
                payload = fh.read()
        elif not count and out is None:
            # 无输入文件 => 读 stdin（管道: view -S -b -F 0x904 -）
            payload = sys.stdin.buffer.read()
        if count:
            # 有内容 => 输出正计数；空输入 => 0
            n = 1 if (payload or infile) else 0
            if not payload and not infile:
                n = 1  # stdin 管道模式给默认正计数
            sys.stdout.write(str(n) + "\n")
        elif out:
            # 落盘内容与输入一致（非空时保证非空）
            if not payload:
                payload = b"@HD\tVN:1.0\n@SQ\tSN:k141_0\tLN:100\nread1\t0\tk141_0\t1\t60\t50M\t*\t0\t0\tACGT\tIIII\tAS:i:0\n"
            with open(out, "wb") as fh:
                fh.write(payload)
        else:
            if not payload:
                payload = b"@HD\tVN:1.0\n@SQ\tSN:k141_0\tLN:100\nread1\t0\tk141_0\t1\t60\t50M\t*\t0\t0\tACGT\tIIII\tAS:i:0\n"
            sys.stdout.buffer.write(payload)
    elif ARGS and ARGS[0] == "sort":
        out = get(ARGS, "-o", default="out.bam")
        infile = None
        for a in reversed(ARGS[1:]):
            if not a.startswith("-") and a != out:
                infile = a
                break
        payload = b""
        if infile and os.path.exists(infile):
            with open(infile, "rb") as fh:
                payload = fh.read()
        elif hasattr(sys.stdin, "buffer"):
            payload = sys.stdin.buffer.read()
        if not payload:
            payload = b"@HD\tVN:1.0\n@SQ\tSN:k141_0\tLN:100\nread1\t0\tk141_0\t1\t60\t50M\t*\t0\t0\tACGT\tIIII\tAS:i:0\n"
        with open(out, "wb") as fh:
            fh.write(payload)
    elif ARGS and ARGS[0] == "index":
        bam = ARGS[-1]
        open(bam + ".bai", "w").close()
    elif ARGS and ARGS[0] == "idxstats":
        print("Unigene1\t300\t5\t0")
        print("*\t0\t0\t0")
    elif ARGS and ARGS[0] == "depth":
        # stub: 输出 contig 深度（contig 名与 idxstats stub 保持一致；格式同真实 depth: contig pos depth）
        print("Unigene1\t1\t20")
    elif ARGS and ARGS[0] == "flagstat":
        print("5 + 0 in total (QC-passed reads + QC-failed reads)")
    else:
        sys.exit("stub samtools: unknown mode")

elif TOOL == "bowtie2":
    r1 = get(ARGS, "-1", default="")
    r2 = get(ARGS, "-2", default="")
    sam = get(ARGS, "-S", default="out.sam")
    sam_content = ("@HD\tVN:1.0\n"
                   "@SQ\tSN:k141_0\tLN:100\n"
                   "read1\t0\tk141_0\t1\t60\t50M\t*\t0\t0\tACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTACGTAC\tIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\tAS:i:0\n")
    if sam == "-":
        # 输出到 stdout：给一条假比对记录，保证下游 BAM 非空
        sys.stdout.write(sam_content)
    else:
        os.makedirs(os.path.dirname(sam) or ".", exist_ok=True)
        with open(sam, "w") as fh:
            fh.write(sam_content)
    un_conc = get(ARGS, "--un-conc-gz", default="")
    if un_conc:
        os.makedirs(os.path.dirname(un_conc) or ".", exist_ok=True)
        shutil.copy(r1, un_conc.replace("%", "1"))
        shutil.copy(r2, un_conc.replace("%", "2"))

elif TOOL == "bowtie2-build":
    prefix = ARGS[-1]
    for i in (1, 2, 3, 4):
        for ext in (".bt2", ".bt2l"):
            open("%s.%d%s" % (prefix, i, ext), "w").close()

elif TOOL in ("kneaddata", "kneaddata_read_count_table"):
    if TOOL == "kneaddata":
        out = get(ARGS, "-o", default="knd")
        r1 = get(ARGS, "-i", default="")
        # -i appears twice; second is R2
        r2 = None
        for i, a in enumerate(ARGS):
            if a == "-i":
                r2 = ARGS[i + 1] if i + 1 < len(ARGS) else None
        os.makedirs(out, exist_ok=True)
        sample = os.path.basename(r1).split("_1")[0]
        shutil.copy(r1, os.path.join(out, sample + "_1_kneaddata_paired_1.fastq"))
        shutil.copy(r2 or r1, os.path.join(out, sample + "_1_kneaddata_paired_2.fastq"))
    else:
        out = get(ARGS, "--output", default="table.txt")
        with open(out, "w") as fh:
            fh.write("sample\tinitial\ttrimmed\thost\tfinal\nS1\t100\t90\t10\t80\n")

elif TOOL == "fastqc":
    out = get(ARGS, "-o", default=".")
    os.makedirs(out, exist_ok=True)
    for a in ARGS:
        if a.endswith((".fq.gz", ".fastq.gz", ".fastq")):
            open(os.path.join(out, os.path.basename(a) + "_fastqc.html"), "w").close()

elif TOOL == "multiqc":
    out = get(ARGS, "-o", default=".")
    name = get(ARGS, "-n", default="multiqc_report.html")
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, name), "w").close()

elif TOOL == "diamond":
    out = get(ARGS, "-o", default="out.tsv")
    inp = get(ARGS, "-q", default="")
    with open(out, "w") as fh:
        for h in fa_headers(inp):
            fh.write("%s\tnr1\t100.0\t300\t0\t0\t1\t300\t1\t300\t0.0\t1000\n" % h.split()[0])

elif TOOL == "blast2lca":
    inp = get(ARGS, "-i", default="")
    out = get(ARGS, "-o", default="lca.tsv")
    with open(out, "w") as fh:
        for line in open(inp):
            q = line.split("\t")[0]
            fh.write("%s; ;d__Bacteria; 100;p__Proteobacteria; 100;c__Gammaproteobacteria; 100;o__Enterobacterales; 100;f__Enterobacteriaceae; 100;g__Escherichia; 100;s__Escherichia coli; 100;\n" % q)

elif TOOL == "emapper.py":
    if "--no_annot" in ARGS:
        inp = get(ARGS, "-i", default="")
        pref = get(ARGS, "-o", default="out")
        with open(pref + ".emapper.seed_orthologs", "w") as fh:
            for h in fa_headers(inp):
                fh.write("%s\t12345\t0.0\t100\t2\tprotein\t-\t-\tko:K00001\t-\t-\t-\t-\t-\t-\tGH5\t-\t2\tCOG0001\tCOG0001\tG\tTest function\n" % h.split()[0])
    else:
        inp = None
        for i, a in enumerate(ARGS):
            if a == "--annotate_hits_table":
                inp = ARGS[i + 1]
        pref = get(ARGS, "-o", default="output")
        with open(pref + ".emapper.annotations", "w") as fh:
            fh.write("#query\tseed_ortholog\tevalue\tscore\ttaxonomic\tprotein\tGOs\tEC\tKEGG_ko\tKEGG_Pathway\tKEGG_Module\tKEGG_Reaction\tKEGG_rclass\tBRITE\tKEGG_TC\tCAZy\tBiGG_Reaction\ttax_scope\teggNOG_OGs\tbest_OG\tCOG_category\tDescription\n")
            if inp:
                for line in open(inp):
                    q = line.split("\t")[0]
                    fh.write("%s\t12345\t0.0\t100\t2\tprotein\t-\t-\tko:K00001\t-\t-\t-\t-\t-\t-\tGH5\t-\t2\tCOG0001\tCOG0001\tG\tTest function\n" % q)

elif TOOL == "gtdbtk":
    out = None
    prefix = "tax"
    for i, a in enumerate(ARGS):
        if a == "--out_dir": out = ARGS[i+1]
        if a == "--prefix": prefix = ARGS[i+1]
    if not out: sys.exit("stub gtdbtk: no --out_dir")
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, prefix + ".bac120.summary.tsv"), "w") as fh:
        fh.write("user_genome\tclassification\nrep1\td__Bacteria;p__Firmicutes;c__Bacilli\n")

elif TOOL == "exec_annotation":
    out = None
    for i, a in enumerate(ARGS):
        if a == "-o": out = ARGS[i+1]
    if not out: sys.exit("stub exec_annotation: no -o")
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    # 真实 KofamScan detail-tsv 6 列: * / gene / KO / score / threshold / evalue / desc
    with open(out, "w") as fh:
        fh.write("*\tgene1\tK00001\t100.0\t120.0\t1e-30\t\"test KO 1\"\n")
        fh.write("*\tgene1\tK00002\t80.0\t90.0\t1e-20\t\"test KO 2\"\n")
        fh.write("\tgene2\tK00003\t5.0\t100.0\t0.5\t\"below threshold\"\n")

elif TOOL == "jgi_summarize_bam_contig_depths":
    out = get(ARGS, "--outputDepth", default="depth.txt")
    bams = [a for a in ARGS if a.endswith(".bam")]
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    with open(out, "w") as fh:
        fh.write("contig\tcontigLen\ttotalAvgDepth")
        for b in bams:
            fh.write("\t%s\t%s-var" % (os.path.basename(b), os.path.basename(b)))
        fh.write("\n")
        fh.write("k141_0\t100\t5")
        for _ in bams:
            fh.write("\t5\t0")
        fh.write("\n")

elif TOOL == "metabat2":
    asm = get(ARGS, "-i", default="")
    out = get(ARGS, "-o", default="bin")
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    shutil.copy(asm, out + ".1.fa")

elif TOOL == "run_MaxBin.pl":
    contig = get(ARGS, "-contig", default="")
    out = get(ARGS, "-out", default="bin")
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    # 真实 MaxBin2 输出是 *.fasta（07 合并/收集曾只认 .fa 而漏掉，回归测试用）
    shutil.copy(contig, out + ".001.fasta")

elif TOOL == "cut_up_fasta.py":
    inp = ARGS[0]
    bed = None
    for i, a in enumerate(ARGS):
        if a == "-b":
            bed = ARGS[i + 1]
    if bed:
        with open(bed, "w") as fh:
            for h in fa_headers(inp):
                fh.write("%s\t1\t100\t0\t+\n" % h.split()[0])
    with open(inp) as fh:
        sys.stdout.write(fh.read())

elif TOOL == "concoct_coverage_table.py":
    # 参数: bed bam1 bam2 ...，stdout 输出
    print("contig\tsample1")
    print("k141_0\t5")

elif TOOL == "concoct":
    bdir = None
    for i, a in enumerate(ARGS):
        if a == "-b":
            bdir = ARGS[i + 1]
    if not bdir:
        sys.exit("stub concoct: no -b")
    # 真实 CONCOCT: -b OUT 在 OUT/ 下写 clustering_gt1000.csv（07 模块 glob concoct_out/*.csv 匹配）
    os.makedirs(bdir, exist_ok=True)
    with open(os.path.join(bdir, "clustering_gt1000.csv"), "w") as fh:
        fh.write("contig,cluster\nk141_0,1\n")

elif TOOL == "merge_cutup_clustering.py":
    # 参数: input.csv -> stdout
    sys.stdout.write("contig,cluster\nk141_0,1\n")

elif TOOL == "extract_fasta_bins.py":
    asm = ARGS[0]
    out = None
    for i, a in enumerate(ARGS):
        if a == "--output_path":
            out = ARGS[i + 1]
    if not out:
        sys.exit("stub extract_fasta_bins.py: no --output_path")
    os.makedirs(out, exist_ok=True)
    # 真实 CONCOCT 输出无 bin 前缀：0.fa / 1.fa ...（07 合并/收集曾只认 bin.*.fa 而漏掉，回归测试用）
    shutil.copy(asm, os.path.join(out, "0.fa"))

elif TOOL == "metawrap":
    if ARGS[0] == "binning":
        out = get(ARGS, "-o", default="bins")
        asm = get(ARGS, "-a", default="")
        os.makedirs(out, exist_ok=True)
        for d in ("metabat2_bins", "maxbin2_bins", "concoct_bins"):
            if "--" + d.split("_")[0] in ARGS:
                os.makedirs(os.path.join(out, d), exist_ok=True)
                shutil.copy(asm, os.path.join(out, d, "bin.1.fa"))
    elif ARGS[0] == "bin_refinement":
        out = get(ARGS, "-o", default="refine")
        os.makedirs(os.path.join(out, "metawrap_50_10_bins"), exist_ok=True)
        src = None
        for i, a in enumerate(ARGS):
            if a in ("-A", "-B", "-C"):
                src = ARGS[i + 1]
        if src:
            for f in os.listdir(src):
                if f.endswith(".fa"):
                    shutil.copy(os.path.join(src, f), os.path.join(out, "metawrap_50_10_bins", f))
    elif ARGS[0] == "reassemble_bins":
        out = get(ARGS, "-o", default="reassemble")
        bdir = get(ARGS, "-b", default="")
        os.makedirs(os.path.join(out, "reassembled_bins"), exist_ok=True)
        if bdir:
            for f in os.listdir(bdir):
                if f.endswith(".fa"):
                    shutil.copy(os.path.join(bdir, f), os.path.join(out, "reassembled_bins", f))
    else:
        sys.exit("stub metawrap: unknown mode " + ARGS[0])

elif TOOL == "coverm":
    # coverm genome --genome-fasta-files F1 F2 ... --coupled R1 R2
    #   [--methods ...] -o OUT -t N
    out = get(ARGS, "-o", default="out.tsv")
    sample = "S"
    if "--coupled" in ARGS:
        i = ARGS.index("--coupled")
        if i + 1 < len(ARGS):
            r1 = ARGS[i + 1]
            base = os.path.basename(r1)
            for suf in ("_1.fq.gz", "_1.fastq.gz", ".R1.fq.gz", ".R1.fastq.gz", "_1.fq", "_1.fastq", ".R1.fq", ".R1.fastq"):
                if base.endswith(suf):
                    sample = base[: -len(suf)]
                    break
            else:
                sample = base
    # 解析 --genome-fasta-files（收集其后直到下一个 - 开头的参数）
    genome_files = []
    if "--genome-fasta-files" in ARGS:
        i = ARGS.index("--genome-fasta-files") + 1
        while i < len(ARGS) and not ARGS[i].startswith("-"):
            genome_files.append(ARGS[i])
            i += 1
    # 解析 --methods（MAG_QUANT_METHODS 追加时）: 默认 coverage relative_abundance
    methods = ["coverage", "relative_abundance"]
    if "--methods" in ARGS:
        i = ARGS.index("--methods")
        j = i + 1
        while j < len(ARGS) and not ARGS[j].startswith("-"):
            methods.append(ARGS[j])
            j += 1
    header_parts = ["Genome", "Contig"]
    for m in methods:
        header_parts.append("%s.%s" % (sample, m))
    with open(out, "w") as fh:
        fh.write("\t".join(header_parts) + "\n")
        if genome_files:
            for path in genome_files:
                gname = os.path.splitext(os.path.basename(path))[0]
                vals = ["%s" % gname, "%s_contig" % gname]
                for m in methods:
                    vals.append("5.0" if m != "relative_abundance" else "0.5")
                fh.write("\t".join(vals) + "\n")
    sys.exit(0)

elif TOOL == "dRep":
    out = ARGS[1]
    os.makedirs(os.path.join(out, "dereplicated_genomes"), exist_ok=True)
    write_fasta(os.path.join(out, "dereplicated_genomes", "rep1.fa"), [("rep1", "ACGT" * 250)])

elif TOOL == "checkm2":
    out = get(ARGS, "--output-directory", default="checkm2")
    os.makedirs(out, exist_ok=True)
    # 真实 CheckM2 的 Name 列 = 输入文件名去扩展名（如 dereplicated_genomes/rep1.fa -> rep1）
    with open(os.path.join(out, "quality_report.tsv"), "w") as fh:
        fh.write("Name\tCompleteness\tContamination\tGenome size\nrep1\t95.0\t2.0\t1000000\n")

elif TOOL == "conda":
    # never invoked as executable; fake conda.sh handles it
    sys.exit(0)

else:
    sys.exit("stub: unknown tool %s" % TOOL)
