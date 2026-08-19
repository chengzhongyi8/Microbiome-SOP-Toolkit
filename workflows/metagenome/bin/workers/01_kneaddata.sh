#!/usr/bin/env bash
# Worker: kneaddata 质控 + 去宿主（01_qc_dehost 并行调用）
# Usage: 01_kneaddata.sh <sample> <R1> <R2>
set -euo pipefail
WORKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${WORKER_DIR}/../.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"

SAMPLE="$1"; R1="$2"; R2="$3"
CLEAN_DIR="${WORK_DIR}/qc/clean"
OUT1="${CLEAN_DIR}/${SAMPLE}_1.fq.gz"; OUT2="${CLEAN_DIR}/${SAMPLE}_2.fq.gz"
PAIR_CHECK_READS="${PAIR_CHECK_READS:-10000}"

[[ -s "${OUT1}" && -s "${OUT2}" ]] && { echo "[skip] ${SAMPLE} 质控结果已存在" >&2; exit 0; }

cat_or_zcat() { if gzip -t "$1" 2>/dev/null; then gzip -dc "$1" 2>/dev/null; else cat "$1"; fi; }
check_pair_names() {
  local f1="$1" f2="$2" nlines=$((PAIR_CHECK_READS * 4))
  diff -q \
    <(cat_or_zcat "${f1}" | head -n "${nlines}" | awk 'NR%4==1{sub(/\/[12]$/,""); print $1}') \
    <(cat_or_zcat "${f2}" | head -n "${nlines}" | awk 'NR%4==1{sub(/\/[12]$/,""); print $1}') >/dev/null 2>&1
}
count_reads() { cat_or_zcat "$1" | wc -l | awk '{printf "%.0f", $1/4}'; }

trimmomatic_args=()
[[ -n "${TRIMMOMATIC_DIR:-}" ]] && trimmomatic_args+=(--trimmomatic "${TRIMMOMATIC_DIR}")
trimmomatic_options="${TRIMMOMATIC_OPTS:-SLIDINGWINDOW:4:20 MINLEN:50}"
if [[ -n "${ADAPTERS:-}" ]]; then
  trimmomatic_options="ILLUMINACLIP:${ADAPTERS}:2:40:15 ${trimmomatic_options}"
fi
db_args=()
if [[ -n "${HOST_GENOME:-}" ]]; then
  db_args+=(--bowtie2-options "${BOWTIE2_OPTS}" -db "${HOST_GENOME}")
fi

echo "[run ] ${SAMPLE} kneaddata (Trimmomatic + Bowtie2)" >&2
kneaddata -i "${R1}" -i "${R2}" \
    -o "${WORK_DIR}/qc/kneaddata" -v -t "${THREADS}" \
    --remove-intermediate-output --reorder \
    "${trimmomatic_args[@]}" \
    --trimmomatic-options "${trimmomatic_options}" \
    "${db_args[@]}"

KND1="${WORK_DIR}/qc/kneaddata/${SAMPLE}_1_kneaddata_paired_1.fastq"
KND2="${WORK_DIR}/qc/kneaddata/${SAMPLE}_1_kneaddata_paired_2.fastq"
[[ -s "${KND1}" && -s "${KND2}" ]] || { echo "ERROR: ${SAMPLE} kneaddata 配对输出缺失" >&2; exit 1; }
check_pair_names "${KND1}" "${KND2}" || { echo "ERROR: ${SAMPLE} kneaddata 输出双端名字不一致" >&2; exit 1; }
gzip -c "${KND1}" > "${OUT1}"
gzip -c "${KND2}" > "${OUT2}"
check_pair_names "${OUT1}" "${OUT2}" || { echo "ERROR: ${SAMPLE} 压缩后双端名字不一致" >&2; exit 1; }
if [[ "${ALLOW_DELETE_KNEADDATA_TEMP:-yes}" == "yes" ]]; then
  rm -f "${WORK_DIR}/qc/kneaddata/${SAMPLE}"_*_kneaddata_*.fastq
fi
printf '%s\t%s\t%s\t%s\t%s\n' "${SAMPLE}" "$(count_reads "${R1}")" "$(count_reads "${R2}")" "$(count_reads "${OUT1}")" "$(count_reads "${OUT2}")"
