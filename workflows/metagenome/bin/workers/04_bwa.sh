#!/usr/bin/env bash
# Worker: bwa mem + samtools 单样本定量（04_quant 并行调用）
# Usage: 04_bwa.sh <sample>
set -euo pipefail
WORKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PIPELINE_DIR="$(cd "${WORKER_DIR}/../.." && pwd)"
source "${PIPELINE_DIR}/config.sh"
[[ -f "${WORK_DIR}/generated.env" ]] && source "${WORK_DIR}/generated.env"
source "${PIPELINE_DIR}/bin/lib.sh"

BWA_BIN="$(resolve_tool BWA)"
SAMTOOLS_BIN="$(resolve_tool SAMTOOLS)"
SAMPLE="$1"
QUANT_WORK="${WORK_DIR}/quant"
CLEAN_DIR="${WORK_DIR}/qc/clean"
mkdir -p "${QUANT_WORK}/bwa/bam" "${QUANT_WORK}/bwa/idxstats"
[[ -s "${QUANT_WORK}/bwa/idxstats/${SAMPLE}.txt" ]] && { echo "[skip] ${SAMPLE}" >&2; exit 0; }
"${BWA_BIN}" mem -t "${THREADS}" "${QUANT_WORK}/bwa/catalog" \
    "${CLEAN_DIR}/${SAMPLE}_1.fq.gz" "${CLEAN_DIR}/${SAMPLE}_2.fq.gz" | \
  "${SAMTOOLS_BIN}" view -@ "${THREADS}" -S -b -F 0x904 | \
  "${SAMTOOLS_BIN}" sort -@ "${THREADS}" -o "${QUANT_WORK}/bwa/bam/${SAMPLE}.bam"
"${SAMTOOLS_BIN}" index -@ "${THREADS}" "${QUANT_WORK}/bwa/bam/${SAMPLE}.bam"
"${SAMTOOLS_BIN}" idxstats "${QUANT_WORK}/bwa/bam/${SAMPLE}.bam" > "${QUANT_WORK}/bwa/idxstats/${SAMPLE}.txt"
