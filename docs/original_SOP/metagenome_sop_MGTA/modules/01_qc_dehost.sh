#!/usr/bin/env bash
# ============================================================================
# 01_qc_dehost.sh — 质控 + 去宿主
#
# 输入:
#   ${WORK_DIR}/samples.tsv          (sample_id<TAB>R1<TAB>R2，主控脚本生成)
#   ${FASTQ_DIR}                     原始/clean 双端测序数据
# 输出:
#   ${WORK_DIR}/qc/clean/<sample>_1.fq.gz / <sample>_2.fq.gz   标准化干净数据
#   ${RESULT_DIR}/qc/kneaddata_summary.txt                     质控统计(可选)
#   ${RESULT_DIR}/qc/host_removal_summary.txt                  去宿主统计(可选)
#   ${RESULT_DIR}/qc/fastqc/  ${RESULT_DIR}/qc/multiqc_report.html
#   ${RESULT_DIR}/qc/read_counts.tsv                           每个样本 reads 数
#
# 逻辑:
#   QC_NEEDED=yes  -> kneaddata(Trimmomatic + Bowtie2 去宿主) + FastQC/MultiQC
#   QC_NEEDED=no   -> 只去宿主(bowtie2 --un-conc-gz)；无宿主则原样通过
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
# 加载主控脚本解析后的命令行覆盖值（若存在）
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"
source "${PIPELINE_DIR}/bin/lib.sh"

SAMPLES_TSV="${WORK_DIR}/samples.tsv"
CLEAN_DIR="${WORK_DIR}/qc/clean"
HOST_SAM_DIR="${WORK_DIR}/qc/host_sam"
QC_RESULT_DIR="${RESULT_DIR}/qc"
PAIR_CHECK_READS="${PAIR_CHECK_READS:-10000}"

[[ -s "${SAMPLES_TSV}" ]] || { echo "ERROR: ${SAMPLES_TSV} not found (先运行主控脚本生成样品表)" >&2; exit 1; }
mkdir -p "${CLEAN_DIR}" "${HOST_SAM_DIR}" "${QC_RESULT_DIR}/fastqc"

# ---- 工具检查 --------------------------------------------------------------
for cmd in gzip zcat diff; do
  command -v "${cmd}" >/dev/null 2>&1 || { echo "ERROR: 缺少基础命令: ${cmd}" >&2; exit 1; }
done

HAS_HOST="no"
if [[ -n "${HOST_GENOME:-}" || -n "${HOST_FASTA:-}" ]]; then
  HAS_HOST="yes"
  for f in "${HOST_GENOME}"*.bt2 "${HOST_GENOME}"*.bt2l; do
    [[ -e "${f}" ]] && HAS_HOST_INDEX="yes"
  done
  [[ "${HAS_HOST_INDEX:-no}" == "yes" ]] || { echo "ERROR: 宿主索引不存在: ${HOST_GENOME} (检查 --host-genome 或先跑 --host-fasta 建索引)" >&2; exit 1; }
fi

cat_or_zcat() { if gzip -t "$1" 2>/dev/null; then gzip -dc "$1" 2>/dev/null; else cat "$1"; fi; }
count_reads() { cat_or_zcat "$1" | wc -l | awk '{printf "%.0f", $1/4}'; }

# ---- 主流程 ----------------------------------------------------------------
: > "${QC_RESULT_DIR}/read_counts.tsv"
printf 'sample\traw_R1_reads\traw_R2_reads\tclean_R1_reads\tclean_R2_reads\n' > "${QC_RESULT_DIR}/read_counts.tsv"

if [[ "${QC_NEEDED:-yes}" == "yes" ]]; then
  # kneaddata 环境需要包含 kneaddata/bowtie2/fastqc/multiqc
  source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_QC}" \
      kneaddata bowtie2 fastqc multiqc
  mkdir -p "${WORK_DIR}/qc/counts"; rm -f "${WORK_DIR}"/qc/counts/*.tmp
  pids=(); failed=0
  while IFS=$'\t' read -r sid r1 r2; do
    [[ -z "${sid}" || "${sid}" == \#* || "${sid}" == "sample_id" ]] && continue
    bash "${PIPELINE_DIR}/bin/workers/01_kneaddata.sh" "${sid}" "${r1}" "${r2}" \
        > "${WORK_DIR}/qc/counts/${sid}.tmp" &
    pids+=($!)
    if [[ "${#pids[@]}" -ge "${CONCURRENT_JOBS}" ]]; then
      for pid in "${pids[@]}"; do wait "${pid}" || failed=1; done
      pids=()
    fi
  done < <(awk -F '\t' '!/^#/ && $1!="sample_id" && $1!="" {print $1"\t"$2"\t"$3}' "${SAMPLES_TSV}")
  if [[ "${#pids[@]}" -gt 0 ]]; then
    for pid in "${pids[@]}"; do wait "${pid}" || failed=1; done
  fi
  [[ "${failed}" -eq 0 ]] || { echo "ERROR: kneaddata 并行任务存在失败" >&2; exit 1; }
  cat "${WORK_DIR}"/qc/counts/*.tmp | sort -t$'\t' -k1,1 >> "${QC_RESULT_DIR}/read_counts.tsv"
  rm -f "${WORK_DIR}"/qc/counts/*.tmp
  # 质控统计表
  kneaddata_read_count_table --input "${WORK_DIR}/qc/kneaddata" --output "${QC_RESULT_DIR}/kneaddata_summary.txt" || true
  # FastQC + MultiQC 复核
  fastqc -t "${THREADS}" -o "${QC_RESULT_DIR}/fastqc" "${CLEAN_DIR}"/*_1.fq.gz "${CLEAN_DIR}"/*_2.fq.gz
  multiqc -d "${QC_RESULT_DIR}/fastqc" -o "${QC_RESULT_DIR}" -n multiqc_report.html
elif [[ "${HAS_HOST}" == "yes" ]]; then
  source "${PIPELINE_DIR}/bin/activate_conda_env.sh" "${ENV_QC}" bowtie2
  printf 'sample\traw_R1_reads\traw_R2_reads\tclean_R1_reads\tclean_R2_reads\n' > "${QC_RESULT_DIR}/host_removal_summary.txt"
  mkdir -p "${WORK_DIR}/qc/counts"; rm -f "${WORK_DIR}"/qc/counts/*.tmp
  pids=(); failed=0
  while IFS=$'\t' read -r sid r1 r2; do
    [[ -z "${sid}" || "${sid}" == \#* || "${sid}" == "sample_id" ]] && continue
    bash "${PIPELINE_DIR}/bin/workers/01_host_removal.sh" "${sid}" "${r1}" "${r2}" \
        > "${WORK_DIR}/qc/counts/${sid}.tmp" &
    pids+=($!)
    if [[ "${#pids[@]}" -ge "${CONCURRENT_JOBS}" ]]; then
      for pid in "${pids[@]}"; do wait "${pid}" || failed=1; done
      pids=()
    fi
  done < <(awk -F '\t' '!/^#/ && $1!="sample_id" && $1!="" {print $1"\t"$2"\t"$3}' "${SAMPLES_TSV}")
  if [[ "${#pids[@]}" -gt 0 ]]; then
    for pid in "${pids[@]}"; do wait "${pid}" || failed=1; done
  fi
  [[ "${failed}" -eq 0 ]] || { echo "ERROR: 去宿主并行任务存在失败" >&2; exit 1; }
  cat "${WORK_DIR}"/qc/counts/*.tmp | sort -t$'\t' -k1,1 | \
      tee -a "${QC_RESULT_DIR}/host_removal_summary.txt" >> "${QC_RESULT_DIR}/read_counts.tsv"
  rm -f "${WORK_DIR}"/qc/counts/*.tmp
else
  # 无宿主且无需质控：直接按标准化命名软链（不复制，省空间）
  echo "NOTE: 无宿主且无需质控，clean 目录直接引用原始文件"
  while IFS=$'\t' read -r sample r1 r2; do
    [[ "${sample}" == "sample_id" || -z "${sample}" || "${sample}" == \#* ]] && continue
    # gz 输入用软链（省空间）；非压缩输入转成 gz 到 clean（统一后续处理）
    if gzip -t "${r1}" 2>/dev/null; then
      ln -sfn "$(cd "$(dirname "${r1}")" && pwd)/$(basename "${r1}")" "${CLEAN_DIR}/${sample}_1.fq.gz"
    else
      gzip -c "${r1}" > "${CLEAN_DIR}/${sample}_1.fq.gz"
    fi
    if gzip -t "${r2}" 2>/dev/null; then
      ln -sfn "$(cd "$(dirname "${r2}")" && pwd)/$(basename "${r2}")" "${CLEAN_DIR}/${sample}_2.fq.gz"
    else
      gzip -c "${r2}" > "${CLEAN_DIR}/${sample}_2.fq.gz"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "${sample}" "$(count_reads "${r1}")" "$(count_reads "${r2}")" "$(count_reads "${CLEAN_DIR}/${sample}_1.fq.gz")" "$(count_reads "${CLEAN_DIR}/${sample}_2.fq.gz")" >> "${QC_RESULT_DIR}/read_counts.tsv"
  done < "${SAMPLES_TSV}"
fi

echo "01_qc_dehost.sh 完成：${QC_RESULT_DIR}"
