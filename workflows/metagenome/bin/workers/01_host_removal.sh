#!/usr/bin/env bash
# Worker: 仅去宿主（01_qc_dehost 并行调用，公司已质控场景）
# Usage: 01_host_removal.sh <sample> <R1> <R2>
set -euo pipefail
WORKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${WORKER_DIR}/../.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"

SAMPLE="$1"; R1="$2"; R2="$3"
CLEAN_DIR="${WORK_DIR}/qc/clean"
HOST_SAM_DIR="${WORK_DIR}/qc/host_sam"
QC_RESULT_DIR="${RESULT_DIR}/qc"
OUT1="${CLEAN_DIR}/${SAMPLE}_1.fq.gz"; OUT2="${CLEAN_DIR}/${SAMPLE}_2.fq.gz"
PAIR_CHECK_READS="${PAIR_CHECK_READS:-10000}"

[[ -s "${OUT1}" && -s "${OUT2}" ]] && { echo "[skip] ${SAMPLE} 去宿主结果已存在" >&2; exit 0; }

cat_or_zcat() { if gzip -t "$1" 2>/dev/null; then gzip -dc "$1" 2>/dev/null; else cat "$1"; fi; }
check_pair_names() {
  local f1="$1" f2="$2" nlines=$((PAIR_CHECK_READS * 4))
  diff -q \
    <(cat_or_zcat "${f1}" | head -n "${nlines}" | awk 'NR%4==1{sub(/\/[12]$/,""); print $1}') \
    <(cat_or_zcat "${f2}" | head -n "${nlines}" | awk 'NR%4==1{sub(/\/[12]$/,""); print $1}') >/dev/null 2>&1
}
count_reads() { cat_or_zcat "$1" | wc -l | awk '{printf "%.0f", $1/4}'; }

echo "[run ] ${SAMPLE} 去宿主 (bowtie2)" >&2
mkdir -p "${CLEAN_DIR}" "${HOST_SAM_DIR}" "${QC_RESULT_DIR}"
bowtie2 -x "${HOST_GENOME}" -1 "${R1}" -2 "${R2}" -p "${THREADS}" \
    ${BOWTIE2_OPTS} \
    --un-conc-gz "${CLEAN_DIR}/${SAMPLE}_%.fq.gz" \
    -S "${HOST_SAM_DIR}/${SAMPLE}.sam"
if [[ ! -s "${OUT1}" || ! -s "${OUT2}" ]]; then
  for cand in "${CLEAN_DIR}/${SAMPLE}"*".1.fq.gz"; do [[ -e "${cand}" ]] && mv -f "${cand}" "${OUT1}"; done
  for cand in "${CLEAN_DIR}/${SAMPLE}"*".2.fq.gz"; do [[ -e "${cand}" ]] && mv -f "${cand}" "${OUT2}"; done
fi
[[ -s "${OUT1}" && -s "${OUT2}" ]] || { echo "ERROR: ${SAMPLE} 去宿主输出缺失" >&2; exit 1; }
check_pair_names "${OUT1}" "${OUT2}" || { echo "ERROR: ${SAMPLE} 去宿主后双端名字不一致" >&2; exit 1; }
if command -v samtools >/dev/null 2>&1; then
  samtools flagstat -@ "${THREADS}" "${HOST_SAM_DIR}/${SAMPLE}.sam" > "${QC_RESULT_DIR}/host_removal_${SAMPLE}.flagstat.txt" 2>/dev/null || true
fi
rm -f "${HOST_SAM_DIR}/${SAMPLE}.sam"
printf '%s\t%s\t%s\t%s\t%s\n' "${SAMPLE}" "$(count_reads "${R1}")" "$(count_reads "${R2}")" "$(count_reads "${OUT1}")" "$(count_reads "${OUT2}")"
