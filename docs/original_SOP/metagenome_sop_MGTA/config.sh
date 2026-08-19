#!/usr/bin/env bash
# ============================================================================
# config.sh — 宏基因组分析 SOP 默认参数
#
# 用法：
#   1) 主控脚本 run_mg_sop.sh 会先 source 本文件，再用命令行参数覆盖同名变量；
#   2) 本文件放“通用默认值”（线程、阈值、conda 环境名、数据库路径）；
#   3) 每个项目的实际路径建议通过命令行参数传入（纯命令行参数模式），
#      或直接修改本文件里的占位符。
#
# 所有变量均可被 run_mg_sop.sh 的命令行参数覆盖。
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# 项目路径（每个项目必须设置，建议用命令行参数传入）
# ---------------------------------------------------------------------------
PROJECT_DIR="${PROJECT_DIR:-/path/to/metagenome_project}"   # 输出根目录（results/ work/ logs/ 都在里面）
FASTQ_DIR="${FASTQ_DIR:-/path/to/fastq}"                  # 原始/clean 测序数据目录（_1.fq.gz / _2.fq.gz）

# ---------------------------------------------------------------------------
# 输入命名约定（双端；支持多种常见后缀，脚本自动识别）
# ---------------------------------------------------------------------------
SEQUENCING_MODE="paired"                    # 本 SOP 仅支持 paired
R1_SUFFIXES=("_1.fq.gz" "_1.fastq.gz" "_R1.fq.gz" "_R1.fastq.gz" ".1.fq.gz" ".1.fastq.gz" ".R1.fq.gz" ".R1.fastq.gz" "_1.fq" "_1.fastq" "_R1.fq" "_R1.fastq" ".1.fq" ".1.fastq" ".R1.fq" ".R1.fastq")
R2_SUFFIXES=("_2.fq.gz" "_2.fastq.gz" "_R2.fq.gz" "_R2.fastq.gz" ".2.fq.gz" ".2.fastq.gz" ".R2.fq.gz" ".R2.fastq.gz" "_2.fq" "_2.fastq" "_R2.fq" "_R2.fastq" ".2.fq" ".2.fastq" ".R2.fq" ".R2.fastq")

# ---------------------------------------------------------------------------
# 质控 / 去宿主
# ---------------------------------------------------------------------------
# QC_NEEDED=yes : 公司未质控，运行 kneaddata(Trimmomatic+Bowtie2) 质控并去宿主
# QC_NEEDED=no  : 公司已给 clean data，只去宿主（无宿主则原样通过）
QC_NEEDED="yes"

# 宿主基因组（二选一）：
#   HOST_GENOME : bowtie2 索引前缀，例如 /home/user/database/host_db/wheat/wheat
#   HOST_FASTA  : 宿主基因组 FASTA；给 FASTA 时脚本自动 bowtie2-build 到
#                 ${HOST_DB_DIR}/${HOST_NAME}/ 下一次直接复用索引
# 两者都为空 = 不去宿主
HOST_GENOME=""
HOST_FASTA=""
HOST_NAME=""                                # 自动建索引的物种目录名（默认取 fasta 文件名）
# 宿主基因组统一放这里（在流水线目录之外，整文件夹拖拽上传/解压覆盖不会把它冲掉）
HOST_DB_DIR="${HOST_DB_DIR:-/home/user/database/host_db}"

# 接头 / trimmomatic 参数（QC_NEEDED=yes 时使用）
# ADAPTERS 为空则不加 ILLUMINACLIP（用 kneaddata 默认接头）；建议显式指定，
# 例如 conda 环境里的 TruSeq3-PE-2.fa（先 grep 确认，参考你之前的做法）
ADAPTERS=""
# kneaddata 的 trimmomatic 安装目录（PDF 里你用的是这个路径）
TRIMMOMATIC_DIR="/home/user/anaconda3/share/trimmomatic-0.39-2/"
TRIMMOMATIC_OPTS="SLIDINGWINDOW:4:20 MINLEN:50"
# bowtie2 去宿主参数（默认 --very-sensitive；不建议加 --dovetail，除非文库确认有重叠）
BOWTIE2_OPTS="--very-sensitive"

# ---------------------------------------------------------------------------
# 组装（MEGAHIT）
# ---------------------------------------------------------------------------
# per-sample: 每个样本单独组装；co-assembly: 全部样本合并组装
# （提供 --group-file 时按分组组装）；both: 两者都做
ASSEMBLY_MODE="per-sample"
MEGAHIT_K_MIN="21"
MEGAHIT_K_MAX="141"
MEGAHIT_K_STEP="10"
MEGAHIT_MIN_CONTIG_LEN="200"                # megahit 输出的最低 contig 长度

# 过滤阈值
GENE_MIN_CONTIG_LEN="1000"                  # 基因预测用 contigs >= N bp
BIN_MIN_CONTIG_LEN="1500"                   # binning 用 contigs >= N bp

# ---------------------------------------------------------------------------
# 基因预测 + 非冗余基因集
# ---------------------------------------------------------------------------
GENE_SPLIT_SEQS="100000"                    # prodigal 拆分：每块多少条记录（seqkit split2 -s）
GENE_CLUSTERER="mmseqs2"                    # mmseqs2 (linclust) 或 cd-hit-est
GENE_MIN_IDENTITY="0.95"                    # 去冗余一致性
GENE_MIN_COVERAGE="0.90"                    # 去冗余覆盖度
TRANSLATE_TRIM="yes"                        # seqkit translate --trim

# ---------------------------------------------------------------------------
# 基因定量
# ---------------------------------------------------------------------------
QUANT_TOOL="salmon"                         # salmon（默认）或 bwa
SALMON_K="31"

# ---------------------------------------------------------------------------
# 物种注释
# ---------------------------------------------------------------------------
TAXONOMY_TOOL="nr-megan"                    # nr-megan（默认）；kraken2 预留可选；none 跳过
# blast2lca 是 MEGAN 的独立 Java 工具（不在 conda 环境里），直接给可执行文件路径
BLAST2LCA="/home/user/megan/tools/blast2lca"   # 已确认存在
NR_DMND="/home/user/nr.dmnd"   # DIAMOND nr 数据库（你确认的服务器路径）
MEGAN_MAP="/home/user/megan_db/prot_acc2tax-Jul2019X1.abin"   # MEGAN accession->taxid 映射（你确认的路径）
DIAMOND_MAX_TARGET_SEQS="10"                # 每个基因保留的比对 hits 数（LCA 建议 >=10）
DIAMOND_EVALUE="0.0001"
MEGAN_MIN_SUPPORT="50"                      # blast2lca -ms
MEGAN_MIN_EVALUE="0.000001"                 # blast2lca -me
TAXA_FILTER="all"                           # all=保留所有domain；bacteria=只留细菌

# Kraken2（预留；服务器未配置时使用会给出明确报错）
KRAKEN2_DB="/path/to/kraken2_db"

# ---------------------------------------------------------------------------
# 功能注释（eggNOG-mapper）
# ---------------------------------------------------------------------------
FUNCTION_TOOL="eggnog"                      # eggnog 或 none
EGGNOG_DATA_DIR="/home/user/database/eggnog_2022_12_4"   # eggNOG 数据库目录（你确认的路径）
EGGNOG_PROT_MIN_LEN="150"                   # 只注释长度 >= N aa 的蛋白（节省时间）
EGGNOG_SPLIT_SEQS="2000000"                 # emapper 拆分：每块多少条记录
# 把 eggNOG 数据库复制到 /dev/shm（内存盘）再注释，速度大幅提升（你 PDF 里的做法）
# 注意：需要 /dev/shm 空间 >= 数据库大小（先 du -sh 数据库、df -h /dev/shm 确认）
EGGNOG_SHM="no"

# ---------------------------------------------------------------------------
# KEGG Pathway / Module 完整度（可选，在 06_function 里运行）
# ---------------------------------------------------------------------------
# 定义文件来自 KEGG FTP（非商业用途免费下载）:
#   module.ko:    ftp://ftp.genome.jp/pub/kegg/module/module.ko
#   module:       ftp://ftp.genome.jp/pub/kegg/module/module       （模块名称，可选）
#   ko00001.keg:  ftp://ftp.genome.jp/pub/kegg/brite/ko/ko00001.keg
# 下载后放到例如 /home/user/database/kegg/ 并在此填写路径。
# 为空时模块 06 退化为“检测表”（只用 emapper 的 KEGG_Module/KEGG_Pathway 列）。
KEGG_MODULE_DEF="/home/user/database/kegg/module.ko"
KEGG_MODULE_NAME="/home/user/database/kegg/module"
KEGG_PATHWAY_DEF="/home/user/db/kegg/ko00001.keg"
KEGG_COMPLETE_THRESHOLD="0.9"   # 完整度 >= 该值判定为 Complete（0.9 常用；严格可用 1.0）

# ---------------------------------------------------------------------------
# contig 覆盖表（可选，在 04_quant 里运行）
# ---------------------------------------------------------------------------
# CONTIG_COVERAGE=yes : 把 clean reads 用 bowtie2 回比到组装 contigs，
#                       samtools depth 计算每个 contig 的平均覆盖深度，
#                       输出 results/quant/contig.depth.tsv（contig x sample）。
# 注意：等于额外多一次全量比对，默认关闭；需要时 --contig-coverage yes。
CONTIG_COVERAGE="no"

# ---------------------------------------------------------------------------
# binning（MetaWRAP + dRep + CheckM2）
# ---------------------------------------------------------------------------
BINNING_TOOL="none"                         # metawrap 或 none（默认 none 关闭）
MAG_BINNERS="metabat2,maxbin2,concoct"      # metawrap binning 用哪些分箱器
RUN_BINNING_REFINE="yes"                    # metawrap bin_refinement
RUN_BINNING_REASSEMBLE="no"                 # metawrap reassemble_bins（较慢）
RUN_DREP="yes"                              # dRep 去冗余
DREP_PRIMARY_ANI="0.90"
DREP_SECONDARY_ANI="0.99"
MAG_MIN_COMPLETENESS="50"
MAG_MAX_CONTAMINATION="10"
MAG_FILTER="no"                              # yes=CheckM2 后按阈值筛 MAG（生成 filtered_genomes/，08 用筛选结果）
CHECKM2_DB="/home/user/database/checkm2_db"   # CheckM2 数据库：目录(自动找 *.dmnd) 或 dmnd 文件路径均可
# metaWRAP reads 输入模式：
#   plain : 把 clean reads 解压成纯文本 *.fastq 再喂给 metaWRAP（兼容老版本，默认）
#   gz    : 直接软链 *.fastq.gz（新版 metaWRAP 支持 gz 时用，零解压省空间）
# 判断：conda activate metawrap && metawrap -v；1.0.4+ 一般支持 gz。
METAWRAP_READS_MODE="plain"
# DAS_Tool（多 binner 整合，替代 metawrap bin_refinement；处理含 | 的 contig 名更稳）
# 留空时用 PATH 里的 DAS_Tool；db 目录留空用工具自带（通常是安装目录下 db/）
# 服务器实测路径（base 环境）
DAS_TOOL="/home/user/anaconda3/envs/dastool117/bin/DAS_Tool"
# dRep 内部需要 checkm（评估完整性/污染过滤），指向 checkm 环境的 bin 目录
CHECKM_BIN_DIR="/home/user/anaconda3/envs/checkm/bin"
# conda base 的 bin 目录（checkm2 需要 prodigal/diamond 等在 PATH）
BASE_BIN_DIR="/home/user/anaconda3/bin"
# dRep 是否跳过 checkm 质量过滤（dRep 的 -comp/-con 依赖 checkm 数据库，未配置时会卡住；
# 本 SOP 后续有 CheckM2 做质量评估，可设 yes 跳过；yes 时 dRep 只做 ANI 去冗余）
DREP_IGNORE_QUALITY="no"
# CheckM2 独立线程数（小内存节点如 node57 建议 8；空=用 THREADS）
CHECKM2_THREADS=""
DAS_TOOL_DB="/home/user/anaconda3/envs/dastool117/share/das_tool-1.1.7-1/db"
S2B_TOOL="/home/user/anaconda3/bin/Fasta_to_Scaffolds2Bin.sh"   # 实测在 base

# ---------------------------------------------------------------------------
# MAG 下游注释（08_mag_annotation，可选；需先 07 binning）
# ---------------------------------------------------------------------------
MAG_ANNOTATE="no"                       # yes=对 dRep 后的 MAG 做 GTDB-Tk + Prodigal + KofamScan
MAG_QUANT="no"                          # yes=coverM 对 dRep 后 MAG 做丰度定量（每样本回比，输出 MAG×样本矩阵）
MAG_QUANT_METHODS=""                    # 追加的 coverM --methods（空格分隔，如 "rpkm tpm"）；空=coverM 默认(coverage+relative_abundance)
ENV_GTDBTK="gtdbtk-2.7.2"               # GTDB-Tk 环境
GTDBTK_DATA_PATH="/home/user/database/gtdbtk_r232"   # GTDB 参考数据库（r232）
GTDBTK_PPLACER_CPUS="1"                 # pplacer 线程数：1=串行(内存最省，分类结果一致)；内存充裕节点可调 2-4，勿>4(fork 内存爆炸)
ENV_MAG_PRODIGAL="base"                 # Prodigal 环境
ENV_KOFAM="kofam"                       # KofamScan 环境
ENV_COVERM="METABOLIC_v4.0"             # coverM 环境（用户安装位置）
KOFAM_PROFILE="/home/user/db/kofamscan/db/profiles"
KOFAM_KO_LIST="/home/user/db/kofamscan/db/ko_list"

# ---------------------------------------------------------------------------
# conda（服务器上的实际路径）
# ---------------------------------------------------------------------------
# 集群若需 module 加载 conda，先确认 module 名再填 CONDA_MODULE（不要猜）
CONDA_SH="/home/user/anaconda3/etc/profile.d/conda.sh"  # 按你服务器 conda info --base 核对
CONDA_MODULE=""

# 各模块使用的 conda 环境名（按你的服务器实际情况修改）
ENV_QC="kneaddata"          # kneaddata + fastqc + multiqc + bowtie2 + trimmomatic
ENV_ASSEMBLY="base"         # megahit（探测：base 里有 megahit）
ENV_GENE="base"             # prodigal + seqkit（base 里有）
ENV_CLUSTER_MMSEQS="base"   # mmseqs（base 里有）
ENV_CLUSTER_CDHIT="base"    # cd-hit-est（base 里有）
ENV_SALMON="base"           # salmon（base PATH 里有，software_documents 下）
ENV_BWA="base"              # bwa + samtools（base PATH 里有）
ENV_DIAMOND="base"          # diamond（base 里有）
ENV_MEGAN="base"            # blast2lca 已改用独立路径 BLAST2LCA，此变量不再使用
ENV_KRAKEN2="base"          # kraken2（预留；若 base 没有需另装）
ENV_EGGNOG="eggnog2.0.1"    # emapper.py
ENV_METAWRAP="metawrap"
ENV_CHECKM2="checkm2"
ENV_DREP="drep"             # dRep 所在环境（你服务器上有 drep / drep.new）

# 不在 conda PATH 里的独立安装工具（绝对路径；找不到时自动回退 PATH）
SALMON="/home/user/software_documents/salmon/bin/salmon"
BWA="/home/user/software_documents/bwa/bwa"
SAMTOOLS="samtools"             # base 里一般有；没有就改成绝对路径
BOWTIE2="bowtie2"               # contig 覆盖回比用（kneaddata 环境里有；独立安装可写绝对路径）
DIAMOND="/home/user/anaconda3/bin/diamond"   # DAS_Tool 单拷贝基因鉴定引擎
COVERM="coverm"                # MAG 丰度定量（METABOLIC_v4.0 环境 PATH 里有；独立安装可写绝对路径）

# ---------------------------------------------------------------------------
# 资源
# ---------------------------------------------------------------------------
THREADS="28"                # 每个任务使用的 CPU
CONCURRENT_JOBS="8"         # 并行任务数（注意 THREADS*CONCURRENT_JOBS <= 节点总核数）
MEMORY_GB="128"

# ---------------------------------------------------------------------------
# 运行行为
# ---------------------------------------------------------------------------
RESUME="yes"                # 输出已存在则跳过（断点续跑）
LOG_DIR="${LOG_DIR:-${PROJECT_DIR}/logs}"
WORK_DIR="${WORK_DIR:-${PROJECT_DIR}/work}"
RESULT_DIR="${RESULT_DIR:-${PROJECT_DIR}/results}"
