#!/usr/bin/env bash
# ============================================================================
# run_mg_sop.sh — 宏基因组分析 SOP 主控脚本（纯命令行参数）
#
# 用法示例:
#   bash run_mg_sop.sh \
#     --project-dir /home/user/proj/mg1 \
#     --fastq-dir  /home/user/proj/mg1/seq \
#     --qc-needed yes \
#     --host-genome /home/user/database/host_db/wheat/wheat \
#     --assembly co-assembly \
#     --binning metawrap \
#     --threads 28 --jobs 8
#
# 参数全部通过命令行传入；config.sh 提供默认值，命令行覆盖之。
# 推荐在 PBS 里调用本脚本（见 run_metagenome.pbs 模板）。
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

usage() {
  sed -n '2,90p' "${SCRIPT_DIR}/run_mg_sop.sh" | sed 's/^# \{0,1\}//'
  cat <<'EOF2'

必填参数:
  --project-dir DIR        输出根目录（results/ work/ logs/）
  --fastq-dir DIR          测序数据目录（*_1.fq.gz / *_2.fq.gz）

常用参数:
  --qc-needed yes|no       公司没质控=yes(kneaddata)；已质控=no(只去宿主)   [默认 yes]
  --host-genome PREFIX     bowtie2 索引前缀（与 --host-fasta 二选一）
  --host-fasta FILE        宿主基因组 FASTA（自动建索引到 <HOST_DB_DIR>/<物种>/）
  --host-name NAME         自动建索引的物种目录名（默认取 FASTA 文件名）
  --adapters FILE          trimmomatic 接头文件（ILLUMINACLIP）
  --group-file FILE        可选分组文件 (sample_id<TAB>group)，共组装按组
  --assembly MODE          per-sample | co-assembly | both                 [默认 per-sample]
  --min-contig-len N       基因预测用 contigs >= N bp                        [默认 1000]
  --bin-min-contig-len N   binning 用 contigs >= N bp                        [默认 1500]
  --cluster TOOL           mmseqs2 | cd-hit-est                              [默认 mmseqs2]
  --quant TOOL             salmon | bwa                                      [默认 salmon]
  --taxonomy TOOL          nr-megan | kraken2 | none                         [默认 nr-megan]
  --function TOOL          eggnog | none                                     [默认 eggnog]
  --binning TOOL           metawrap | none                                   [默认 none]
  --metawrap-reads-mode MODE  plain(解压,默认) | gz(软链,需新版 metawrap 支持)
  --mag-annotate yes|no      MAG 下游注释(GTDB-Tk+Prodigal+KofamScan)          [默认 no]
  --mag-quant yes|no         MAG 丰度定量(coverM genome, 需 METABOLIC_v4.0)     [默认 no]
  --mag-quant-methods LIST   coverM 追加方法，如 "rpkm tpm"（空格分隔）        [默认空=coverage+relative_abundance]
  --gtdbtk-db DIR            GTDB 参考数据库目录（GTDBTK_DATA_PATH）
  --gtdbtk-pplacer-cpus N    pplacer 线程数（1=最省内存；2-4 更快但吃内存）        [默认 1]
  --kofam-profile DIR / --kofam-ko-list FILE   KofamScan 数据库路径
  --binners LIST           metabat2,maxbin2,concoct                          [默认三款]
  --binning-refine yes|no                                                     [默认 yes]
  --binning-reassemble yes|no                                                [默认 no]
  --run-drep yes|no                                                          [默认 yes]
  --drep-ignore-quality yes|no   dRep 跳过质量过滤（仍由 CheckM2 评估）          [默认 no]
  --mag-filter yes|no         CheckM2 后按阈值筛 MAG（生成 filtered_genomes/）  [默认 no]
  --mag-min-completeness N    筛选阈值：最小完整度                                [默认 50]
  --mag-max-contamination N   筛选阈值：最大污染度                                [默认 10]
  --checkm2-db DIR         CheckM2 数据库                                     [默认服务器路径]
  --nr-db PATH             NR diamond 数据库
  --megan-map PATH         MEGAN accession->taxid 映射
  --taxa-filter all|bacteria                                                  [默认 all]
  --eggnog-db DIR          eggNOG 数据库目录
  --contig-coverage yes|no  额外输出 contig 覆盖深度表（reads 回比组装）       [默认 no]
  --kegg-module-def FILE    可选 KEGG module.ko（完整度；空=只出检测表）
  --kegg-pathway-def FILE   可选 KEGG ko00001.keg（完整度；空=只出检测表）
  --kegg-module-name FILE   可选 KEGG module 名称文件
  --kegg-complete-threshold N  KEGG 完整度判定阈值（0-1）                          [默认 0.9]

conda / 资源:
  --conda-sh PATH          conda.sh 路径（服务器上 conda info --base）
  --qc-env NAME            各模块环境名（--assembly-env/--gene-env/--mmseqs-env/
  ...                        --cdhit-env/--salmon-env/--bwa-env/--diamond-env/
                             --megan-env/--kraken2-env/--eggnog-env/--metawrap-env/
                             --checkm2-env/--drep-env）
  --threads N              每个任务 CPU                                      [默认 28]
  --jobs N                 并行任务数                                       [默认 8]
  --memory-gb N            内存 GB（binning 用）                             [默认 128]

运行行为:
  --resume yes|no          输出已存在则跳过（断点续跑）                      [默认 yes]
  --force                  强制重跑全部
  --check-only             只校验参数/输入/环境并生成 generated.env，不跑流程
  -h|--help                帮助
EOF2
  exit 0
}

# ---- 解析命令行 --------------------------------------------------------------
FORCE="no"; CHECK_ONLY="no"; GROUP_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-dir)    PROJECT_DIR="${2:?missing --project-dir}"; shift 2 ;;
    --fastq-dir)      FASTQ_DIR="${2:?missing --fastq-dir}"; shift 2 ;;
    --group-file)     GROUP_FILE="${2:?missing --group-file}"; shift 2 ;;
    --qc-needed)      QC_NEEDED="${2:?missing --qc-needed}"; shift 2 ;;
    --host-genome)    HOST_GENOME="${2:?missing --host-genome}"; shift 2 ;;
    --host-fasta)     HOST_FASTA="${2:?missing --host-fasta}"; shift 2 ;;
    --host-name)      HOST_NAME="${2:?missing --host-name}"; shift 2 ;;
    --host-db-dir)    HOST_DB_DIR="${2:?missing --host-db-dir}"; shift 2 ;;
    --adapters)       ADAPTERS="${2:?missing --adapters}"; shift 2 ;;
    --trimmomatic-dir) TRIMMOMATIC_DIR="${2:?missing --trimmomatic-dir}"; shift 2 ;;
    --trimmomatic-opts) TRIMMOMATIC_OPTS="${2:?missing --trimmomatic-opts}"; shift 2 ;;
    --bowtie2-opts)   BOWTIE2_OPTS="${2:?missing --bowtie2-opts}"; shift 2 ;;
    --assembly)       ASSEMBLY_MODE="${2:?missing --assembly}"; shift 2 ;;
    --min-contig-len) GENE_MIN_CONTIG_LEN="${2:?missing --min-contig-len}"; shift 2 ;;
    --bin-min-contig-len) BIN_MIN_CONTIG_LEN="${2:?missing --bin-min-contig-len}"; shift 2 ;;
    --cluster)        GENE_CLUSTERER="${2:?missing --cluster}"; shift 2 ;;
    --quant)          QUANT_TOOL="${2:?missing --quant}"; shift 2 ;;
    --taxonomy)       TAXONOMY_TOOL="${2:?missing --taxonomy}"; shift 2 ;;
    --function)       FUNCTION_TOOL="${2:?missing --function}"; shift 2 ;;
    --binning)        BINNING_TOOL="${2:?missing --binning}"; shift 2 ;;
    --metawrap-reads-mode) METAWRAP_READS_MODE="${2:?missing --metawrap-reads-mode}"; shift 2 ;;
    --binners)        MAG_BINNERS="${2:?missing --binners}"; shift 2 ;;
    --binning-refine) RUN_BINNING_REFINE="${2:?missing --binning-refine}"; shift 2 ;;
    --binning-reassemble) RUN_BINNING_REASSEMBLE="${2:?missing --binning-reassemble}"; shift 2 ;;
    --run-drep)       RUN_DREP="${2:?missing --run-drep}"; shift 2 ;;
    --drep-ignore-quality) DREP_IGNORE_QUALITY="${2:?missing --drep-ignore-quality}"; shift 2 ;;
    --mag-filter)     MAG_FILTER="${2:?missing --mag-filter}"; shift 2 ;;
    --mag-min-completeness) MAG_MIN_COMPLETENESS="${2:?missing --mag-min-completeness}"; shift 2 ;;
    --mag-max-contamination) MAG_MAX_CONTAMINATION="${2:?missing --mag-max-contamination}"; shift 2 ;;
    --checkm2-threads)    CHECKM2_THREADS="${2:?missing --checkm2-threads}"; shift 2 ;;
    --mag-annotate)       MAG_ANNOTATE="${2:?missing --mag-annotate}"; shift 2 ;;
    --mag-quant)          MAG_QUANT="${2:?missing --mag-quant}"; shift 2 ;;
    --mag-quant-methods)  MAG_QUANT_METHODS="${2:?missing --mag-quant-methods}"; shift 2 ;;
    --gtdbtk-db)          GTDBTK_DATA_PATH="${2:?missing --gtdbtk-db}"; shift 2 ;;
    --gtdbtk-pplacer-cpus) GTDBTK_PPLACER_CPUS="${2:?missing --gtdbtk-pplacer-cpus}"; shift 2 ;;
    --kofam-profile)      KOFAM_PROFILE="${2:?missing --kofam-profile}"; shift 2 ;;
    --kofam-ko-list)      KOFAM_KO_LIST="${2:?missing --kofam-ko-list}"; shift 2 ;;
    --checkm2-db)     CHECKM2_DB="${2:?missing --checkm2-db}"; shift 2 ;;
    --nr-db)          NR_DMND="${2:?missing --nr-db}"; shift 2 ;;
    --megan-map)      MEGAN_MAP="${2:?missing --megan-map}"; shift 2 ;;
    --max-target-seqs) DIAMOND_MAX_TARGET_SEQS="${2:?missing --max-target-seqs}"; shift 2 ;;
    --taxa-filter)    TAXA_FILTER="${2:?missing --taxa-filter}"; shift 2 ;;
    --kraken2-db)     KRAKEN2_DB="${2:?missing --kraken2-db}"; shift 2 ;;
    --eggnog-db)      EGGNOG_DATA_DIR="${2:?missing --eggnog-db}"; shift 2 ;;
    --eggnog-shm)     EGGNOG_SHM="${2:?missing --eggnog-shm}"; shift 2 ;;
    --contig-coverage) CONTIG_COVERAGE="${2:?missing --contig-coverage}"; shift 2 ;;
    --kegg-module-def)  KEGG_MODULE_DEF="${2:?missing --kegg-module-def}"; shift 2 ;;
    --kegg-pathway-def) KEGG_PATHWAY_DEF="${2:?missing --kegg-pathway-def}"; shift 2 ;;
    --kegg-module-name) KEGG_MODULE_NAME="${2:?missing --kegg-module-name}"; shift 2 ;;
    --kegg-complete-threshold) KEGG_COMPLETE_THRESHOLD="${2:?missing --kegg-complete-threshold}"; shift 2 ;;
    --conda-sh)       CONDA_SH="${2:?missing --conda-sh}"; shift 2 ;;
    --conda-module)   CONDA_MODULE="${2:?missing --conda-module}"; shift 2 ;;
    --qc-env)         ENV_QC="${2:?missing --qc-env}"; shift 2 ;;
    --assembly-env)   ENV_ASSEMBLY="${2:?missing --assembly-env}"; shift 2 ;;
    --gene-env)       ENV_GENE="${2:?missing --gene-env}"; shift 2 ;;
    --mmseqs-env)     ENV_CLUSTER_MMSEQS="${2:?missing --mmseqs-env}"; shift 2 ;;
    --cdhit-env)      ENV_CLUSTER_CDHIT="${2:?missing --cdhit-env}"; shift 2 ;;
    --salmon-env)     ENV_SALMON="${2:?missing --salmon-env}"; shift 2 ;;
    --bwa-env)        ENV_BWA="${2:?missing --bwa-env}"; shift 2 ;;
    --diamond-env)    ENV_DIAMOND="${2:?missing --diamond-env}"; shift 2 ;;
    --megan-env)      ENV_MEGAN="${2:?missing --megan-env}"; shift 2 ;;
    --kraken2-env)    ENV_KRAKEN2="${2:?missing --kraken2-env}"; shift 2 ;;
    --eggnog-env)     ENV_EGGNOG="${2:?missing --eggnog-env}"; shift 2 ;;
    --metawrap-env)   ENV_METAWRAP="${2:?missing --metawrap-env}"; shift 2 ;;
    --checkm2-env)    ENV_CHECKM2="${2:?missing --checkm2-env}"; shift 2 ;;
    --drep-env)       ENV_DREP="${2:?missing --drep-env}"; shift 2 ;;
    --threads)        THREADS="${2:?missing --threads}"; shift 2 ;;
    --jobs)           CONCURRENT_JOBS="${2:?missing --jobs}"; shift 2 ;;
    --memory-gb)      MEMORY_GB="${2:?missing --memory-gb}"; shift 2 ;;
    --resume)         RESUME="${2:?missing --resume}"; shift 2 ;;
    --force)          FORCE="yes"; shift ;;
    --check-only)     CHECK_ONLY="yes"; shift ;;
    -h|--help)        usage ;;
    *) echo "ERROR: 未知参数: $1" >&2; usage ;;
  esac
done

# ---- 基础校验 ----------------------------------------------------------------
[[ "${PROJECT_DIR}" == /* ]] || { echo "ERROR: --project-dir 必须是绝对路径: ${PROJECT_DIR}" >&2; exit 1; }
[[ "${PROJECT_DIR}" == "/path/to/metagenome_project" ]] && { echo "ERROR: 未设置 --project-dir" >&2; exit 1; }
[[ -d "${FASTQ_DIR}" ]] || { echo "ERROR: --fastq-dir 不存在: ${FASTQ_DIR}" >&2; exit 1; }
[[ "${FASTQ_DIR}" == "/path/to/fastq" ]] && { echo "ERROR: 未设置 --fastq-dir" >&2; exit 1; }

for v in QC_NEEDED RUN_BINNING_REFINE RUN_BINNING_REASSEMBLE RUN_DREP RESUME CONTIG_COVERAGE; do
  val="${!v:-}"
  [[ -z "${val}" || "${val}" == "yes" || "${val}" == "no" ]] || {
    echo "ERROR: ${v} 必须是 yes 或 no (got: ${val})" >&2; exit 1; }
done
case "${ASSEMBLY_MODE}" in per-sample|co-assembly|both) : ;; *) echo "ERROR: --assembly 必须是 per-sample|co-assembly|both" >&2; exit 1 ;; esac
case "${GENE_CLUSTERER}" in mmseqs2|cd-hit-est) : ;; *) echo "ERROR: --cluster 必须是 mmseqs2|cd-hit-est" >&2; exit 1 ;; esac
case "${QUANT_TOOL}" in salmon|bwa) : ;; *) echo "ERROR: --quant 必须是 salmon|bwa" >&2; exit 1 ;; esac
case "${TAXONOMY_TOOL}" in nr-megan|kraken2|none) : ;; *) echo "ERROR: --taxonomy 必须是 nr-megan|kraken2|none" >&2; exit 1 ;; esac
case "${FUNCTION_TOOL}" in eggnog|none) : ;; *) echo "ERROR: --function 必须是 eggnog|none" >&2; exit 1 ;; esac
case "${BINNING_TOOL}" in metawrap|none) : ;; *) echo "ERROR: --binning 必须是 metawrap|none" >&2; exit 1 ;; esac
case "${TAXA_FILTER}" in all|bacteria) : ;; *) echo "ERROR: --taxa-filter 必须是 all|bacteria" >&2; exit 1 ;; esac
[[ -f "${CONDA_SH}" ]] || { echo "ERROR: --conda-sh 文件不存在: ${CONDA_SH}（服务器上 conda info --base 得到）" >&2; exit 1; }
[[ "${THREADS}" =~ ^[0-9]+$ && "${CONCURRENT_JOBS}" =~ ^[0-9]+$ ]] || { echo "ERROR: --threads/--jobs 必须是数字" >&2; exit 1; }

# ---- 目录（基于最终 PROJECT_DIR 重算，覆盖 config.sh 的占位值）------------------
WORK_DIR="${PROJECT_DIR}/work"
RESULT_DIR="${PROJECT_DIR}/results"
LOG_DIR="${PROJECT_DIR}/logs"
export PROJECT_DIR FASTQ_DIR WORK_DIR RESULT_DIR LOG_DIR
mkdir -p "${PROJECT_DIR}" "${WORK_DIR}" "${RESULT_DIR}" "${LOG_DIR}" \
         "${WORK_DIR}/markers" "${RESULT_DIR}/summary"
LOG_FILE="${LOG_DIR}/pipeline.log"
say() { printf '%s\n' "$*" | tee -a "${LOG_FILE}"; }
say "==== $(date '+%F %T') run_mg_sop.sh 启动 ===="
say "    项目目录: ${PROJECT_DIR}"

# ---- 样品发现 ------------------------------------------------------------------
echo "==> 发现样品 (${FASTQ_DIR})"
printf 'sample_id\tR1\tR2\n' > "${WORK_DIR}/samples.tsv"
found=0
for i in "${!R1_SUFFIXES[@]}"; do
  s1="${R1_SUFFIXES[$i]}"; s2="${R2_SUFFIXES[$i]}"
  for f in "${FASTQ_DIR}"/*"${s1}"; do
    [[ -e "${f}" ]] || continue
    sample="$(basename "${f}" "${s1}")"
    r2="${FASTQ_DIR}/${sample}${s2}"
    [[ -e "${r2}" ]] || { echo "WARNING: ${sample} 缺少 R2 (${s2})，跳过" >&2; continue; }
    printf '%s\t%s\t%s\n' "${sample}" "$(cd "$(dirname "${f}")" && pwd)/$(basename "${f}")" \
        "$(cd "$(dirname "${r2}")" && pwd)/$(basename "${r2}")" >> "${WORK_DIR}/samples.tsv"
    found=$((found+1))
  done
done
[[ "${found}" -gt 0 ]] || { echo "ERROR: ${FASTQ_DIR} 中没有找到 *_1.fq.gz / *_2.fq.gz 配对文件" >&2; exit 1; }
sort -u -o "${WORK_DIR}/samples.tsv" "${WORK_DIR}/samples.tsv"
echo "    共发现 ${found} 个样品: $(cut -f1 "${WORK_DIR}/samples.tsv" | tr '\n' ' ')"

if [[ -n "${GROUP_FILE:-}" ]]; then
  [[ -s "${GROUP_FILE}" ]] || { echo "ERROR: --group-file 不存在或为空: ${GROUP_FILE}" >&2; exit 1; }
  while read -r sid _; do
    [[ -z "${sid}" || "${sid}" == \#* || "${sid}" == "sample_id" ]] && continue
    grep -qxF "${sid}" <(cut -f1 "${WORK_DIR}/samples.tsv") || {
      echo "ERROR: group-file 中的样品 ${sid} 不在 fastq 目录里" >&2; exit 1; }
  done < "${GROUP_FILE}"
fi

# ---- 宿主基因组准备 -------------------------------------------------------------
if [[ -n "${HOST_FASTA:-}" ]]; then
  [[ -s "${HOST_FASTA}" ]] || { echo "ERROR: --host-fasta 不存在: ${HOST_FASTA}" >&2; exit 1; }
  [[ -z "${HOST_NAME:-}" ]] && HOST_NAME="$(basename "${HOST_FASTA}" | sed -E 's/\.(fa|fna|fasta)(\.gz)?$//')"
  HOST_DB_DIR="${HOST_DB_DIR:-/home/user/database/host_db}"
  HOST_GENOME="${HOST_DB_DIR}/${HOST_NAME}/${HOST_NAME}"
  mkdir -p "$(dirname "${HOST_GENOME}")"
  if [[ ! -e "${HOST_GENOME}.1.bt2" && ! -e "${HOST_GENOME}.1.bt2l" ]]; then
    echo "==> 构建宿主索引: ${HOST_GENOME}"
    source "${SCRIPT_DIR}/bin/activate_conda_env.sh" "${ENV_QC}" bowtie2 bowtie2-build
    build_args=(--threads "${THREADS}")
    # 小麦等超大参考基因组(>4Gb)必须加 --large-index，否则 bowtie2-build 会失败
    if [[ "$(stat -c %s "${HOST_FASTA}" 2>/dev/null || stat -f %z "${HOST_FASTA}" 2>/dev/null || echo 0)" -gt 4000000000 ]]; then
      echo "    检测到大基因组(>4Gb)，自动加 --large-index"
      build_args+=(--large-index)
    fi
    bowtie2-build "${build_args[@]}" "${HOST_FASTA}" "${HOST_GENOME}"
  fi
fi
if [[ -n "${HOST_GENOME:-}" ]]; then
  ok="no"
  for f in "${HOST_GENOME}"*.bt2 "${HOST_GENOME}"*.bt2l; do [[ -e "${f}" ]] && ok="yes"; done
  [[ "${ok}" == "yes" ]] || { echo "ERROR: 宿主索引不存在: ${HOST_GENOME}" >&2; exit 1; }
  echo "    去宿主: 使用索引 ${HOST_GENOME}"
else
  echo "    去宿主: 未配置宿主基因组（跳过）"
fi

# ---- 写出 generated.env（模块脚本会加载）----------------------------------------
echo "==> 写入 ${WORK_DIR}/generated.env"
{
  for v in PROJECT_DIR WORK_DIR RESULT_DIR LOG_DIR FASTQ_DIR GROUP_FILE QC_NEEDED HOST_GENOME HOST_FASTA HOST_NAME \
           HOST_DB_DIR ADAPTERS TRIMMOMATIC_DIR TRIMMOMATIC_OPTS BOWTIE2_OPTS \
           ASSEMBLY_MODE GENE_MIN_CONTIG_LEN BIN_MIN_CONTIG_LEN \
           GENE_SPLIT_SEQS GENE_CLUSTERER GENE_MIN_IDENTITY GENE_MIN_COVERAGE TRANSLATE_TRIM \
           QUANT_TOOL SALMON_K TAXONOMY_TOOL NR_DMND MEGAN_MAP DIAMOND_MAX_TARGET_SEQS \
           DIAMOND_EVALUE MEGAN_MIN_SUPPORT MEGAN_MIN_EVALUE TAXA_FILTER KRAKEN2_DB \
           FUNCTION_TOOL EGGNOG_DATA_DIR EGGNOG_PROT_MIN_LEN EGGNOG_SPLIT_SEQS EGGNOG_SHM \
           KEGG_MODULE_DEF KEGG_MODULE_NAME KEGG_PATHWAY_DEF KEGG_COMPLETE_THRESHOLD \
           CONTIG_COVERAGE BOWTIE2 \
           BINNING_TOOL MAG_BINNERS RUN_BINNING_REFINE RUN_BINNING_REASSEMBLE RUN_DREP \
           DREP_PRIMARY_ANI DREP_SECONDARY_ANI MAG_MIN_COMPLETENESS MAG_MAX_CONTAMINATION \
           CHECKM2_DB METAWRAP_READS_MODE DREP_IGNORE_QUALITY CHECKM2_THREADS \
           MAG_FILTER \
           MAG_ANNOTATE MAG_QUANT MAG_QUANT_METHODS ENV_GTDBTK GTDBTK_DATA_PATH GTDBTK_PPLACER_CPUS ENV_MAG_PRODIGAL ENV_KOFAM \
           ENV_COVERM KOFAM_PROFILE KOFAM_KO_LIST CONDA_SH CONDA_MODULE \
           ENV_QC ENV_ASSEMBLY ENV_GENE ENV_CLUSTER_MMSEQS ENV_CLUSTER_CDHIT ENV_SALMON \
           ENV_BWA ENV_DIAMOND ENV_MEGAN ENV_KRAKEN2 ENV_EGGNOG ENV_METAWRAP ENV_CHECKM2 \
           ENV_DREP THREADS CONCURRENT_JOBS MEMORY_GB RESUME; do
    printf '%s=%q\n' "${v}" "${!v:-}"
  done
} > "${WORK_DIR}/generated.env"

[[ "${CHECK_ONLY}" == "yes" ]] && { echo "==> check-only 完成，未运行任何模块"; exit 0; }

# ---- 模块执行 ------------------------------------------------------------------
run_module() {
  local name="$1"
  local script="$2"
  local marker="${WORK_DIR}/markers/${name}.ok"
  if [[ "${RESUME}" == "yes" && -f "${marker}" && "${FORCE}" != "yes" ]]; then
    say "---- [skip] ${name} 已完成 (${marker})"
    return 0
  fi
  say "==== [${name}] $(date '+%F %T') 开始: ${script}"
  local t0=$SECONDS
  if bash "${script}" 2>&1 | tee -a "${LOG_FILE}"; then
    touch "${marker}"
    say "==== [${name}] $(date '+%F %T') 完成 (耗时 $((SECONDS-t0))s)"
  else
    say "==== [${name}] $(date '+%F %T') 失败 (耗时 $((SECONDS-t0))s) —— 查看 ${LOG_FILE}"
    exit 1
  fi
}

run_module 01_qc_dehost     "${SCRIPT_DIR}/modules/01_qc_dehost.sh"
run_module 02_assembly      "${SCRIPT_DIR}/modules/02_assembly.sh"
run_module 03_gene_catalog  "${SCRIPT_DIR}/modules/03_gene_catalog.sh"
run_module 04_quant         "${SCRIPT_DIR}/modules/04_quant.sh"
[[ "${TAXONOMY_TOOL}" == "none" ]] || run_module 05_taxonomy "${SCRIPT_DIR}/modules/05_taxonomy.sh"
[[ "${FUNCTION_TOOL}" == "none" ]] || run_module 06_function "${SCRIPT_DIR}/modules/06_function.sh"
[[ "${BINNING_TOOL}" == "none" ]] || run_module 07_binning "${SCRIPT_DIR}/modules/07_binning.sh"
[[ "${MAG_ANNOTATE}" == "yes" || "${MAG_QUANT}" == "yes" ]] && run_module 08_mag_annotation "${SCRIPT_DIR}/modules/08_mag_annotation.sh"

# ---- 汇总报告 ------------------------------------------------------------------
echo "==> 生成汇总报告"
SUMMARY="${RESULT_DIR}/summary/README_summary.md"
{
  echo "# 宏基因组分析汇总报告"
  echo
  echo "- 生成时间: $(date '+%F %T')"
  echo "- 项目目录: ${PROJECT_DIR}"
  echo "- 数据目录: ${FASTQ_DIR}"
  echo "- 样品数: $(awk -F '\t' '!/^#/ && $1!="sample_id" && $1!=""' "${WORK_DIR}/samples.tsv" | wc -l | tr -d ' ')"
  echo "- 参数快照: results/summary/params.tsv（本文件顶部参数均已记录）"
  echo
  echo "## 各模块输出"
  echo
  echo "| 模块 | 状态 | 主要输出 |"
  echo "|---|---|---|"
  for m in 01_qc_dehost 02_assembly 03_gene_catalog 04_quant 05_taxonomy 06_function 07_binning; do
    if [[ -f "${WORK_DIR}/markers/${m}.ok" ]]; then st="完成"; else st="-"; fi
    echo "| ${m} | ${st} | 见下方 |"
  done
  echo
  echo "## QC"
  echo "- 每个样品 reads 数: results/qc/read_counts.tsv"
  echo "- kneaddata 统计: results/qc/kneaddata_summary.txt（如有）"
  echo "- MultiQC: results/qc/multiqc_report.html（如有）"
  echo
  echo "## 组装"
  echo "- 统计: results/assembly/assembly.stats.tsv"
  echo "- 合并 contigs: results/assembly/assembly.fa"
  echo "- 组装列表: results/assembly/assemblies.list"
  echo
  echo "## 基因集"
  echo "- 统计: results/gene_catalog/catalog.stats.tsv"
  echo "- 核酸基因集: results/gene_catalog/catalog/gene_catalog.fna"
  echo "- 蛋白序列: results/gene_catalog/catalog/gene_catalog.faa"
  echo
  echo "## 定量"
  if [[ "${QUANT_TOOL}" == "salmon" ]]; then
    echo "- count 矩阵: results/quant/gene.count.tsv"
    echo "- TPM 矩阵: results/quant/gene.TPM.tsv"
  else
    echo "- count 矩阵: results/quant/gene.count.tsv"
    echo "- FPKM 矩阵: results/quant/gene.FPKM.tsv"
  fi
  if [[ "${CONTIG_COVERAGE:-no}" == "yes" ]]; then
    echo "- contig 覆盖深度表: results/quant/contig.depth.tsv"
  fi
  echo
  echo "## 物种注释（${TAXONOMY_TOOL}）"
  echo "- 各层级丰度表: results/taxonomy/Table_taxa_*.tsv"
  echo "- 基因-物种对应: results/taxonomy/gene_taxonomy.tsv"
  echo
  echo "## 功能注释（${FUNCTION_TOOL}）"
  echo "- 注释: results/function/eggnog.annotations.tsv"
  echo "- KO/CAZy/COG 丰度: results/function/KO.tsv, CAZy.tsv, COG.tsv"
  echo "- KEGG 完整度: results/function/KEGG_module_completeness.tsv / KEGG_pathway_completeness.tsv（未配定义文件时为 *_detected.tsv）"
  echo
  echo "## binning（${BINNING_TOOL}）"
  echo "- MAG 列表: results/mags/MAG_list.txt"
  echo "- 质量表: results/mags/MAG_quality.tsv"
  if [[ "${MAG_FILTER:-no}" == "yes" ]]; then
    echo "- 质量筛选: results/mags/filtered_genomes/ (completeness>=${MAG_MIN_COMPLETENESS} contamination<=${MAG_MAX_CONTAMINATION})"
  fi
  if [[ "${MAG_QUANT:-no}" == "yes" ]]; then
    echo "- MAG 丰度: results/mags/abundance/MAG_abundance.tsv (coverM)"
  fi
  if [[ "${MAG_ANNOTATE:-no}" == "yes" ]]; then
    echo "- GTDB-Tk 物种: results/mags/annotations/gtdb/"
    echo "- Prodigal 基因: results/mags/annotations/prodigal/"
    echo "- KofamScan KO: results/mags/annotations/kofam/ + kofam_summary.tsv"
  fi
  echo
  echo "## 软件版本"
  echo "- results/software_versions.tsv"
} > "${SUMMARY}"

# 参数快照
{
  for v in PROJECT_DIR WORK_DIR RESULT_DIR LOG_DIR FASTQ_DIR GROUP_FILE QC_NEEDED HOST_GENOME HOST_FASTA ASSEMBLY_MODE \
           GENE_MIN_CONTIG_LEN BIN_MIN_CONTIG_LEN GENE_CLUSTERER QUANT_TOOL TAXONOMY_TOOL \
           TAXA_FILTER FUNCTION_TOOL BINNING_TOOL MAG_BINNERS RUN_DREP CHECKM2_DB \
           CONTIG_COVERAGE KEGG_MODULE_DEF KEGG_PATHWAY_DEF \
           THREADS CONCURRENT_JOBS MEMORY_GB; do
    printf '%s\t%s\n' "${v}" "${!v:-}"
  done
} > "${RESULT_DIR}/summary/params.tsv"

say ""
say "==== $(date '+%F %T') 全部完成 ===="
say "汇总报告: ${SUMMARY}"
say "流程日志: ${LOG_FILE}"
